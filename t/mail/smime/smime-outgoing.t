#!/usr/bin/perl
use strict;
use warnings;

use RT::Test tests => 14;

my $openssl = RT::Test->find_executable('openssl');
plan skip_all => 'openssl executable is required.'
    unless $openssl;


use IPC::Run3 'run3';
use RT::Interface::Email;

# catch any outgoing emails
RT::Test->set_mail_catcher;

my $keys = RT::Test::get_abs_relocatable_dir(
    (File::Spec->updir()) x 2,
    qw(data smime keys),
);

my $keyring = RT::Test->new_temp_dir(
    crypt => smime => 'smime_keyring'
);

RT->Config->Set( Crypt =>
    Enable   => 1,
    Incoming => ['SMIME'],
    Outgoing => 'SMIME',
);
RT->Config->Set( GnuPG => Enable => 0 );
RT->Config->Set( SMIME =>
    Enable => 1,
    OutgoingMessagesFormat => 'RFC',
    Passphrase => {
        'sender@example.com' => '123456',
    },
    OpenSSL => $openssl,
    Keyring => $keyring,
);

RT->Config->Set( 'MailPlugins' => 'Auth::MailFrom', 'Auth::Crypt' );

my ($url, $m) = RT::Test->started_ok;
ok $m->login, "logged in";

my $queue = RT::Test->load_or_create_queue(
    Name              => 'General',
    CorrespondAddress => 'sender@example.com',
    CommentAddress    => 'sender@example.com',
);
ok $queue && $queue->id, 'loaded or created queue';

{
    my ($status, $msg) = $queue->SetEncrypt(1);
    ok $status, "turn on encyption by default"
        or diag "error: $msg";
}

{
    my $cf = RT::CustomField->new( $RT::SystemUser );
    my ($ret, $msg) = $cf->Create(
        Name       => 'SMIME Key',
        LookupType => RT::User->new( $RT::SystemUser )->CustomFieldLookupType,
        Type       => 'TextSingle',
    );
    ok($ret, "Custom Field created");

    my $OCF = RT::ObjectCustomField->new( $RT::SystemUser );
    $OCF->Create(
        CustomField => $cf->id,
        ObjectId    => 0,
    );
}

my $user;
{
    $user = RT::User->new($RT::SystemUser);
    ok($user->LoadByEmail('root@localhost'), "Loaded user 'root'");
    ok($user->Load('root'), "Loaded user 'root'");
    is($user->EmailAddress, 'root@localhost');

    open my $fh, '<:raw', File::Spec->catfile($keys, 'recipient.crt')
        or die $!;
    my ($status, $msg) = $user->AddCustomFieldValue(
        Field => 'SMIME Key',
        Value => do { local $/; <$fh> },
    );
    ok $status, "added user's key" or diag "error: $msg";
}

RT::Test->clean_caught_mails;

{
    my $mail = <<END;
From: root\@localhost
To: rt\@example.com
Subject: This is a test of new ticket creation as an unknown user

Blah!
Foob!

END

    my ($status, $id) = RT::Test->send_via_mailgate(
        $mail, queue => $queue->Name,
    );
    is $status, 0, "successfuly executed mailgate";

    my $ticket = RT::Ticket->new($RT::SystemUser);
    $ticket->Load( $id );
    ok ($ticket->id, "found ticket ". $ticket->id);
}

{
    my @mails = RT::Test->fetch_caught_mails;
    is scalar @mails, 1, "autoreply";

    my ($buf, $err);
    local $@;
    ok(eval {
        run3([
            $openssl, qw(smime -decrypt -passin pass:123456),
            '-inkey', File::Spec->catfile($keys, 'recipient.key'),
            '-recip', File::Spec->catfile($keys, 'recipient.crt')
        ], \$mails[0], \$buf, \$err )
        }, 'can decrypt'
    );
    diag $@ if $@;
    diag $err if $err;
    diag "Error code: $?" if $?;
    like($buf, qr'This message has been automatically generated in response');
}



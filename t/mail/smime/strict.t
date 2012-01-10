#!/usr/bin/perl
use strict;
use warnings;

use RT::Test tests => 22;

my $openssl = RT::Test->find_executable('openssl');
plan skip_all => 'openssl executable is required.'
    unless $openssl;

use IPC::Run3 'run3';
use String::ShellQuote 'shell_quote';
use RT::Tickets;

my $keys = RT::Test::get_abs_relocatable_dir(
    (File::Spec->updir()) x 2,
    qw(data smime keys),
);

my $keyring = RT::Test->new_temp_dir(
    crypt => smime => 'smime_keyring'
);

RT->Config->Set( Crypt =>
    Enable   => 1,
    Strict   => 1,
    Incoming => ['SMIME'],
    Outgoing => 'SMIME',
);
RT->Config->Set( GnuPG => Enable => 0 );
RT->Config->Set( SMIME =>
    Enable => 1,
    Strict => 1,
    OutgoingMessagesFormat => 'RFC',
    Passphrase => {
        'sender@example.com' => '123456',
    },
    OpenSSL => $openssl,
    Keyring => $keyring,
);

RT->Config->Set( 'MailPlugins' => 'Auth::MailFrom', 'Auth::Crypt' );

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

{
    my $template = RT::Template->new($RT::SystemUser);
    $template->Create(
        Name => 'NotEncryptedMessage',
        Queue => 0,
        Content => <<EOF,

Subject: Failed to send unencrypted message

This message was not sent since it is unencrypted:
EOF
    );
}

my ($url, $m) = RT::Test->started_ok;
ok $m->login, "logged in";

# configure key for General queue
RT::Test->import_smime_key('sender@example.com');
my $queue = RT::Test->load_or_create_queue(
    Name              => 'General',
    CorrespondAddress => 'sender@example.com',
    CommentAddress    => 'sender@example.com',
);
ok $queue && $queue->id, 'loaded or created queue';

my $user = RT::Test->load_or_create_user(
    Name => 'root@example.com',
    EmailAddress => 'root@example.com',
);
RT::Test->import_smime_key('root@example.com.crt', $user);
RT::Test->add_rights( Principal => $user, Right => 'SuperUser', Object => RT->System );

my $mail = RT::Test->open_mailgate_ok($url);
print $mail <<EOF;
From: root\@localhost
To: rt\@$RT::rtname
Subject: This is a test of new ticket creation as root

Blah!
Foob!
EOF
RT::Test->close_mailgate_ok($mail);

{
    ok(!RT::Test->last_ticket, 'A ticket was not created');
    my ($mail) = RT::Test->fetch_caught_mails;
    like(
        $mail,
        qr/^Subject: Failed to send unencrypted message/m,
        'recorded incoming mail that is not encrypted'
    );
    my ($warning) = $m->get_warnings;
    like($warning, qr/rejected because the message is unencrypted with Strict mode enabled/);
}

{
    # test for encrypted mail
    my $buf = '';
    run3(
        shell_quote(
            qw(openssl smime -encrypt  -des3),
            -from    => 'root@example.com',
            -to      => 'rt@' . $RT::rtname,
            -subject => "Encrypted message for queue",
            File::Spec->catfile( $keys, 'sender@example.com.crt' ),
        ),
        \"Subject: test\n\norzzzzzz",
        \$buf,
        \*STDERR
    );

    my ($status, $tid) = RT::Test->send_via_mailgate( $buf );
    is ($status >> 8, 0, "The mail gateway exited normally");

    my $tick = RT::Ticket->new( $RT::SystemUser );
    $tick->Load( $tid );
    is( $tick->Subject, 'Encrypted message for queue',
        "Created the ticket"
    );

    my $txn = $tick->Transactions->First;
    my ($msg, $attach, $orig) = @{$txn->Attachments->ItemsArrayRef};
    is( $msg->GetHeader('X-RT-Incoming-Encryption'),
        'Success',
        'recorded incoming mail that is encrypted'
    );
    is( $msg->GetHeader('X-RT-Privacy'),
        'SMIME',
        'recorded incoming mail that is encrypted'
    );
    like( $attach->Content, qr'orz');

    is( $orig->GetHeader('Content-Type'), 'application/x-rt-original-message');
}

{
    my $buf = '';

    run3(
        join(
            ' ',
            shell_quote(
                RT->Config->Get('SMIME')->{'OpenSSL'},
                qw( smime -sign -nodetach -passin pass:123456),
                -signer => File::Spec->catfile( $keys, 'root@example.com.crt' ),
                -inkey  => File::Spec->catfile( $keys, 'root@example.com.key' ),
            ),
            '|',
            shell_quote(
                qw(openssl smime -encrypt -des3),
                -from    => 'root@example.com',
                -to      => 'rt@' . RT->Config->Get('rtname'),
                -subject => "Encrypted and signed message for queue",
                File::Spec->catfile( $keys, 'sender@example.com.crt' ),
            )),
            \"Subject: test\n\norzzzzzz",
            \$buf,
            \*STDERR
    );

    my ($status, $tid) = RT::Test->send_via_mailgate( $buf );

    my $tick = RT::Ticket->new( $RT::SystemUser );
    $tick->Load( $tid );
    ok( $tick->Id, "found ticket " . $tick->Id );
    is( $tick->Subject, 'Encrypted and signed message for queue',
        "Created the ticket"
    );

    my $txn = $tick->Transactions->First;
    my ($msg, $attach, $orig) = @{$txn->Attachments->ItemsArrayRef};
    is( $msg->GetHeader('X-RT-Incoming-Encryption'),
        'Success',
        'recorded incoming mail that is encrypted'
    );
    like( $attach->Content, qr'orzzzz');
}


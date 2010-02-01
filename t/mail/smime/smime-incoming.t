#!/usr/bin/perl
use strict;
use warnings;

use RT::Test tests => 47;

my $openssl = RT::Test->find_executable('openssl');
plan skip_all => 'openssl executable is required.'
    unless $openssl;

use File::Temp;
use IPC::Run3 'run3';
use String::ShellQuote 'shell_quote';
use RT::Tickets;
use FindBin;
use Cwd 'abs_path';

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
    Incoming => ['SMIME'],
    Outgoing => 'SMIME',
);
RT->Config->Set( SMIME =>
    Enable => 1,
    OutgoingMessagesFormat => 'RFC',
    Passphrase => {
        'sender@example.com' => '123456',
    },
    OpenSSL => $openssl,
    Keyring => $keyring,
);
RT->Config->Set( GnuPG => Enable => 0 );

RT->Config->Set( 'MailPlugins' => 'Auth::MailFrom', 'Auth::Crypt' );

RT::Test->import_smime_key('sender@example.com');

my $mails = RT::Test::find_relocatable_path( 'data', 'smime', 'mails' );

my ($url, $m) = RT::Test->started_ok;
# configure key for General queue
$m->get( $url."?user=root;pass=password" );
$m->content_like(qr/Logout/, 'we did log in');
$m->get( $url.'/Admin/Queues/');
$m->follow_link_ok( {text => 'General'} );
$m->submit_form( form_number => 3,
		 fields      => { CorrespondAddress => 'sender@example.com' } );

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
    my $tick = RT::Test->last_ticket;
    is( $tick->Subject,
        'This is a test of new ticket creation as root',
        "Created the ticket"
    );
    my $txn = $tick->Transactions->First;
    like(
        $txn->Attachments->First->Headers,
        qr/^X-RT-Incoming-Encryption: Not encrypted/m,
        'recorded incoming mail that is not encrypted'
    );
    like( $txn->Attachments->First->Content, qr'Blah');
}

{
    # test for encrypted mail
    my $buf = '';
    run3(
        shell_quote(
            qw(openssl smime -encrypt  -des3),
            -from    => 'root@localhost',
            -to      => 'rt@' . $RT::rtname,
            -subject => "Encrypted message for queue",
            File::Spec->catfile( $keys, 'sender@example.com.crt' ),
        ),
        \"Subject: test\n\norzzzzzz",
        \$buf,
        \*STDERR
    );

    my ($status, $tid) = RT::Test->send_via_mailgate( $buf );
    ok !$status, "executed gate";

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
    my $message = RT::Test->file_content([$mails, 'simple-txt-enc.eml']);
    my ($status, $tid) = RT::Test->send_via_mailgate( $message );
    ok !$status, "executed gate";

    my $tick = RT::Ticket->new( $RT::SystemUser );
    $tick->Load( $tid );
    ok( $tick->Id, "found ticket " . $tick->Id );
    is( $tick->Subject, 'test', 'Created the ticket' );

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
    ok( $msg->GetHeader('User-Agent'), 'header is there');
    like( $attach->Content, qr'test');
}

{
    my $message = RT::Test->file_content([$mails, 'with-text-attachment.eml']);
    my ($status, $tid) = RT::Test->send_via_mailgate( $message );
    ok !$status, "executed gate";

    my $tick = RT::Ticket->new( $RT::SystemUser );
    $tick->Load( $tid );
    ok( $tick->Id, "found ticket " . $tick->Id );
    is( $tick->Subject, 'test', 'Created the ticket' );
    my $txn = $tick->Transactions->First;
    my @attachments = @{ $txn->Attachments->ItemsArrayRef };
    is( @attachments, 4, '4 attachments: top, two parts and orig' );

    is( $attachments[0]->GetHeader('X-RT-Incoming-Encryption'),
        'Success',
        'recorded incoming mail that is encrypted'
    );
    ok( $attachments[0]->GetHeader('User-Agent'), 'header is there' );
    like( $attachments[1]->Content, qr'test' );
    like( $attachments[2]->Content, qr'text attachment' );
    is( $attachments[2]->Filename, 'attachment.txt' );
}

{
    my $message = RT::Test->file_content([$mails, 'with-bin-attachment.eml']);
    my ($status, $tid) = RT::Test->send_via_mailgate( $message );
    ok !$status, "executed gate";

    my $tick = RT::Ticket->new( $RT::SystemUser );
    $tick->Load( $tid );
    ok( $tick->Id, "found ticket " . $tick->Id );
    is( $tick->Subject, 'test', 'Created the ticket' );
    my $txn = $tick->Transactions->First;
    my @attachments = @{ $txn->Attachments->ItemsArrayRef };
    is( @attachments, 4, '4 attachments: top, two parts and orig' );

    is( $attachments[0]->GetHeader('X-RT-Incoming-Encryption'),
        'Success',
        'recorded incoming mail that is encrypted'
    );
    ok( $attachments[0]->GetHeader('User-Agent'), 'header is there');
    like( $attachments[1]->Content, qr'test');
    is( $attachments[2]->Filename, 'attachment.bin' );
}

{
    my $buf = '';

    run3(
        join(
            ' ',
            shell_quote(
                RT->Config->Get('SMIME')->{'OpenSSL'},
                qw( smime -sign -nodetach -passin pass:123456),
                -signer => File::Spec->catfile( $keys, 'recipient.crt' ),
                -inkey  => File::Spec->catfile( $keys, 'recipient.key' ),
            ),
            '|',
            shell_quote(
                qw(openssl smime -encrypt -des3),
                -from    => 'root@localhost',
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


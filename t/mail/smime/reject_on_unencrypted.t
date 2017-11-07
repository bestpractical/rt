use strict;
use warnings;

use RT::Test::SMIME tests => undef, actual_server => 1, config => 'Set( @MailPlugins, "Authz::RequireEncrypted" );';
my $test = 'RT::Test::SMIME';

use IPC::Run3 'run3';
use String::ShellQuote 'shell_quote';
use RT::Tickets;

my ($url, $m) = RT::Test->started_ok;
ok $m->login, "logged in";

# configure key for General queue
RT::Test::SMIME->import_key('sender@example.com');
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
RT::Test::SMIME->import_key('root@example.com.crt', $user);
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
        qr/^Subject: RT requires that all incoming mail be encrypted/m,
        'rejected mail that is not encrypted'
    );
    my ($warning) = $m->get_warnings;
    like($warning, qr/rejected because the message is unencrypted/);
}

{
    # test for encrypted mail
    my $buf = '';
    run3(
        shell_quote(
            qw(openssl smime -encrypt  -des3),
            -from    => 'root@example.com',
            -to      => 'sender@example.com',
            -subject => "Encrypted message for queue",
            $test->key_path('sender@example.com.crt' ),
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
                -signer => $test->key_path('root@example.com.crt' ),
                -inkey  => $test->key_path('root@example.com.key' ),
            ),
            '|',
            shell_quote(
                qw(openssl smime -encrypt -des3),
                -from    => 'root@example.com',
                -to      => 'sender@example.com',
                -subject => "Encrypted and signed message for queue",
                $test->key_path('sender@example.com.crt' ),
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

done_testing;

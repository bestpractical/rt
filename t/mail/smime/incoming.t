use strict;
use warnings;

use RT::Test::Crypt SMIME => 1, tests => undef, actual_server => 1;
my $test = 'RT::Test::Crypt';

use IPC::Run3 'run3';
use String::ShellQuote 'shell_quote';
use RT::Tickets;
use Test::Warn;
use Test::Deep;

my ($url, $m) = RT::Test->started_ok;
ok $m->login, "logged in";

# configure key for General queue
$test->smime_import_key('sender@example.com');
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
$test->smime_import_key('root@example.com.crt', $user);
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
    my ($msg) = @{ $txn->Attachments->ItemsArrayRef };
    my @status = $msg->GetCryptStatus;
    cmp_deeply( \@status, [], 'Got expected crypt status (Empty array)' );
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
            $test->smime_key_path('sender@example.com.crt'),
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
                -signer => $test->smime_key_path('root@example.com.crt'),
                -inkey  => $test->smime_key_path('root@example.com.key'),
            ),
            '|',
            shell_quote(
                qw(openssl smime -encrypt -des3),
                -from    => 'root@example.com',
                -to      => 'sender@example.com',
                -subject => "Encrypted and signed message for queue",
                $test->smime_key_path('sender@example.com.crt'),
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
    my @status = $msg->GetCryptStatus;
    cmp_deeply(
        \@status,
        [   {   Operation   => 'Decrypt',
                Protocol    => 'SMIME',
                Message     => 'Decryption process succeeded',
                EncryptedTo => [ { EmailAddress => 'sender@example.com' } ],
                Status      => 'DONE'
            },
            {   Status           => 'DONE',
                UserString       => '"Enoch Root" <root@example.com>',
                Trust            => 'FULL',
                Issuer           => '"CA Owner" <ca.owner@example.com>',
                CreatedTimestamp => re('^\d+$'),
                Message =>
                    'The signature is good, signed by "Enoch Root" <root@example.com>, assured by "CA Owner" <ca.owner@example.com>, trust is full',
                ExpireTimestamp => re('^\d+$'),
                Operation       => 'Verify',
                Protocol        => 'SMIME'
            }
        ],
        'Got expected signing/encryption status'
    );
}

{
    my $buf = '';

    run3(
        shell_quote(
            RT->Config->Get('SMIME')->{'OpenSSL'},
            qw( smime -sign -passin pass:123456),
            -signer => $test->smime_key_path('root@example.com.crt'),
            -inkey  => $test->smime_key_path('root@example.com.key'),
        ),
        \"Content-type: text/plain\n\nThis is the body",
        \$buf,
        \*STDERR
    );
    $buf = "Subject: Signed email\n"
         . "From: root\@example.com\n"
         . $buf;

    {
        my ($status, $tid) = RT::Test->send_via_mailgate( $buf );

        my $tick = RT::Ticket->new( $RT::SystemUser );
        $tick->Load( $tid );
        ok( $tick->Id, "found ticket " . $tick->Id );
        is( $tick->Subject, 'Signed email',
            "Created the ticket"
        );

        my $txn = $tick->Transactions->First;
        my ($msg, $attach, $orig) = @{$txn->Attachments->ItemsArrayRef};
        is( $msg->GetHeader('X-RT-Incoming-Signature'),
            '"Enoch Root" <root@example.com>',
            "Message was signed"
        );
        like( $attach->Content, qr/This is the body/ );
        my @status = $msg->GetCryptStatus;
        cmp_deeply(
            \@status,
            [   {   CreatedTimestamp => re('^\d+$'),
                    ExpireTimestamp  => re('^\d+$'),
                    Issuer           => '"CA Owner" <ca.owner@example.com>',
                    Protocol         => 'SMIME',
                    Operation        => 'Verify',
                    Status           => 'DONE',
                    Message =>
                        'The signature is good, signed by "Enoch Root" <root@example.com>, assured by "CA Owner" <ca.owner@example.com>, trust is full',
                    UserString => '"Enoch Root" <root@example.com>',
                    Trust      => 'FULL'
                }
            ],
            'Got expected crypt status for signed message'
        );
    }

    # Make the signature not match
    $buf =~ s/This is the body/This is not the body/;

    warning_like {
        my ($status, $tid) = RT::Test->send_via_mailgate( $buf );

        my $tick = RT::Ticket->new( $RT::SystemUser );
        $tick->Load( $tid );
        ok( $tick->Id, "found ticket " . $tick->Id );
        is( $tick->Subject, 'Signed email',
            "Created the ticket"
        );

        my $txn = $tick->Transactions->First;
        my ($msg, $attach, $orig) = @{$txn->Attachments->ItemsArrayRef};
        isnt( $msg->GetHeader('X-RT-Incoming-Signature'),
            '"Enoch Root" <root@example.com>',
            "Message was not marked signed"
        );
        like( $attach->Content, qr/This is not the body/ );
    } qr/Failure during SMIME verify: The signature did not verify/;

}

done_testing;

use strict;
use warnings;

use RT::Test::SMIME tests => undef;
my $test = 'RT::Test::SMIME';

use IPC::Run3 'run3';
use String::ShellQuote 'shell_quote';
use RT::Tickets;
use Test::Warn;

# configure key for General queue
RT::Test::SMIME->import_key('sender@example.com');
my $queue = RT::Test->load_or_create_queue(
    Name              => 'General',
    CorrespondAddress => 'sender@example.com',
    CommentAddress    => 'sender@example.com',
);
ok $queue && $queue->id, 'loaded or created queue';

# Make sure the new user can create tickets
my $everyone;
{
    $everyone = RT::Group->new( $RT::SystemUser );
    $everyone->LoadSystemInternalGroup('Everyone');
    ok $everyone->id, "loaded 'everyone' group";
}
RT::Test->set_rights(
    Principal => $everyone,
    Right => ['CreateTicket'],
);

# Generate a signed message
my $buf = '';
run3(
    shell_quote(
        RT->Config->Get('SMIME')->{'OpenSSL'},
        qw( smime -sign -passin pass:123456),
        -signer => $test->key_path('altuser@example.com.crt'),
        -inkey  => $test->key_path('altuser@example.com.key'),
    ),
    \"Content-type: text/plain\n\nThis is the body",
    \$buf,
    \*STDERR
);
$buf = "Subject: Signed email\n"
     . "From: altuser\@example.com\n"
     . $buf;

my $send_mail = sub {
    my %args = ( CAPath => undef, @_ );

    RT->Config->Get('SMIME')->{$_} = $args{$_} for keys %args;

    my ($status, $tid) = RT::Test->send_via_mailgate( $buf );

    my $tick = RT::Ticket->new( $RT::SystemUser );
    $tick->Load( $tid );
    ok( $tick->Id, "found ticket " . $tick->Id );
    is( $tick->Subject, 'Signed email',
        "Created the ticket"
    );

    my $txn = $tick->Transactions->First;
    my ($msg, $attach, $orig) = @{$txn->Attachments->ItemsArrayRef};

    ($status) = RT::Crypt->ParseStatus(
        Protocol => 'SMIME',
        Status => $msg->GetHeader('X-RT-SMIME-Status')
    );

    return ($msg, $status);
};

# Test with no CA path; should not be marked as signed
warning_like {
    my ($msg, $status) = $send_mail->( CAPath => undef );
    is( $msg->GetHeader('X-RT-Incoming-Signature'),
        undef,
        "Message was not marked as signed"
    );

    is($status->{Operation}, "Verify", "Found the Verify operation");
    is($status->{Status}, "BAD", "Verify was a failure");
    is($status->{Trust}, "NONE", "Noted the no trust level");
    like($status->{Message}, qr/not trusted/, "Verify was a failure");
} qr/Failure during SMIME verify: The signing CA was not trusted/;

# Test with the correct CA path; marked as signed, trusted
{
    my ($msg, $status) = $send_mail->( CAPath => $test->key_path . "/demoCA/cacert.pem" );
    is( $msg->GetHeader('X-RT-Incoming-Signature'),
        '"altuser" <altuser@example.com>', "Message is signed" );

    is($status->{Operation}, "Verify", "Found the Verify operation");
    is($status->{Status}, "DONE", "Verify was a success");
    is($status->{Trust}, "FULL", "Noted the full trust level");
}

done_testing;

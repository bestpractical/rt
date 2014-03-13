use strict;
use warnings;

use RT::Test::GnuPG
  tests         => undef,
  gnupg_options => {
    passphrase    => 'rt-test',
    'trust-model' => 'always',
  }
;

my $queue;
{
    $queue = RT::Test->load_or_create_queue(
        Name => 'Regression',
        SignAuto => 1,
    );
    ok $queue && $queue->id, 'loaded or created queue';
    ok !$queue->CorrespondAddress, 'address not set';
}

# We don't use Test::Warn here, because it apparently only captures up
# to the first newline -- and the meat of this message is on the fourth
# line.
my @warnings;
local $SIG{__WARN__} = sub {
    push @warnings, "@_";
};

my $ticket = RT::Ticket->new( RT->SystemUser );
my ($status, undef, $msg) = $ticket->Create(
    Queue => $queue->id,
    Subject => 'test',
    Requestor => 'root@localhost',
);
ok( $status, "created ticket" ) or diag "error: $msg";

is( scalar @warnings, 1, "Got a warning" );
like( $warnings[0], qr{signing failed: secret key not available},
    "Found warning of no secret key");

done_testing;

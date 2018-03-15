use strict;
use warnings;

use GnuPG::Interface;

use RT::Test::GnuPG
  tests         => undef,
  gnupg_options => {
    passphrase    => 'rt-test',
    'trust-model' => 'always',
  }
;

my $gnupg = GnuPG::Interface->new();

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

# Classic GnuPG doesn't emit the latter two warnings. Modern GnuPG
# does. Test with:
# 
# $ touch a-file
# $ gpg --status-file gpg-status --default-key "bob@example.com" --sign a-file
# $ cat gpg-status
my @gnupg_versions = split /\./, $gnupg->version;
if ($gnupg_versions[0] >= 2 && $gnupg_versions[1] >= 1) {
    is( scalar @warnings, 3, "Got warnings" );

    like( $warnings[0], qr{signing failed: No secret key},
         "Found warning of no secret key");

    like( $warnings[1], qr{INV_SGNR},
         "Found warning of no usable senders");

    like( $warnings[2], qr{FAILURE},
         "Found warning of failure");
}
else {
    is( scalar @warnings, 1, "Got a warning" );

    like( $warnings[0], qr{signing failed: secret key not available},
         "Found warning of no secret key");
}

done_testing;

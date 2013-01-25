use strict;
use warnings;

use RT::Test::GnuPG
  tests         => 6,
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

use Test::Warn;
warnings_like {
    my $ticket = RT::Ticket->new( RT->SystemUser );
    my ($status, undef, $msg) = $ticket->Create(
        Queue => $queue->id,
        Subject => 'test',
        Requestor => 'root@localhost',
    );
    ok $status, "created ticket" or diag "error: $msg";

    my $log = RT::Test->file_content([RT::Test->temp_directory, 'rt.debug.log']);
    like $log, qr{secret key not available}, 'error in the log';
    unlike $log, qr{Scrip .*? died}m, "scrip didn't die";
} [qr{gpg: keyring .*? created}];


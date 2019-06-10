use strict;
use warnings;

use Test::Deep;
use RT::Test::Shredder tests => undef, config => 'Set($Organization, "foo-bar");';
my $test = "RT::Test::Shredder";

use_ok('RT::Shredder::Plugin::Tickets');

$test->create_savepoint('clean');

diag "Shred a queue whose name contains a hyphen";
{
    my $ticket = RT::Test->create_ticket( Subject => 'Test organization with a hyphen', Queue => 1 );
    $ticket->ApplyTransactionBatch;

    my $plugin = RT::Shredder::Plugin::Tickets->new;
    my ( $status, $msg ) = $plugin->TestArgs( query => 'id = ' . $ticket->id );
    ok( $status, "plugin arguments are ok" ) or diag "error: $msg";

    my $shredder = $test->shredder_new();

    ( $status, my $tickets ) = $plugin->Run;
    ok( $status, "executed plugin successfully" );
    is( $tickets->Count,     1,           'found one ticket' );
    is( $tickets->First->id, $ticket->id, 'found the ticket' );

    $shredder->PutObjects( Objects => [ 'RT::Ticket-' . RT->Config->Get('Organization') . '-' . $ticket->id ] );
    $shredder->WipeoutAll;

    cmp_deeply( $test->dump_current_and_savepoint('clean'), "current DB equal to savepoint" );
}

done_testing();

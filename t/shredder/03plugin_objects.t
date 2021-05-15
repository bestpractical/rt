use strict;
use warnings;

use Test::Deep;
use RT::Test::Shredder tests => undef;
my $test = "RT::Test::Shredder";

use_ok('RT::Shredder::Plugin::Objects');

$test->create_savepoint('clean');

diag "Shred a queue whose name contains a hyphen";
{
    my $queue = RT::Test->load_or_create_queue( Name => 'it-support' );
    ok( $queue->id, 'created queue' );
    my $plugin = RT::Shredder::Plugin::Objects->new;
    my ( $status, $msg ) = $plugin->TestArgs( Queue => 'it-support' );
    ok( $status, "plugin arguments are ok" ) or diag "error: $msg";

    my $shredder = $test->shredder_new();

    ( $status, my @objs ) = $plugin->Run;
    ok( $status, "executed plugin successfully" );
    is( scalar @objs,   1,            'found one queue' );
    is( $objs[0]->Name, 'it-support', 'found the queue' );

    $shredder->PutObjects( Objects => [ 'RT::Queue-' . RT->Config->Get('Organization') . '-it-support' ] );
    $shredder->WipeoutAll;

    cmp_deeply( $test->dump_current_and_savepoint('clean'), "current DB equal to savepoint" );
}

done_testing();

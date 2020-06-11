use strict;
use warnings;

use RT::Test tests => undef;

my $queue = RT::Test->load_or_create_queue( Name => 'General' );
my ( $ret, $msg ) = $queue->SetSLADisabled(0);
ok( $ret, 'Enable queue SLA' );

RT->Config->Set( 'PriorityToSLA', Low => '3 days', Medium => '1 day', High => '4 hours', 80 => '8 hours' );
my $ticket = RT::Test->create_ticket( Queue => $queue->Id );
is( $ticket->SLA, '3 days', 'SLA is set to 3 days' );

$ticket = RT::Test->create_ticket( Queue => $queue->Id, Priority => 50 );
is( $ticket->SLA, '1 day', 'SLA is set to 1 day' );

( $ret, $msg ) = $ticket->SetPriority(100);
ok( $ret, 'Updated priority to 100' );
is( $ticket->PriorityAsString, 'High',    'Priority is High' );
is( $ticket->SLA,              '4 hours', 'SLA is set to 4 hours' );

( $ret, $msg ) = $ticket->SetPriority(80);
ok( $ret, 'Updated priority to 80' );
is( $ticket->SLA, '8 hours', 'SLA is set to 8 hours' );

done_testing;

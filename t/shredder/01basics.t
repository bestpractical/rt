
use strict;
use warnings;

use Test::Deep;
use RT::Test::Shredder tests => 4;
my $test = "RT::Test::Shredder";

$test->create_savepoint();

use RT::Tickets;
my $ticket = RT::Ticket->new( RT->SystemUser );
my ($id) = $ticket->Create( Subject => 'test', Queue => 1 );
ok( $id, "created new ticket" );

$ticket = RT::Ticket->new( RT->SystemUser );
my ($status, $msg) = $ticket->Load( $id );
ok( $id, "load ticket" ) or diag( "error: $msg" );

my $shredder = $test->shredder_new();
$shredder->Wipeout( Object => $ticket );

$test->db_is_valid;

cmp_deeply( $test->dump_current_and_savepoint(), "current DB equal to savepoint");

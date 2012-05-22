use strict;
use warnings;
use RT::Test tests => 5;

use RT::Report::Tickets;

my $ticket = RT::Test->create_ticket( Queue => 'General', Subject => 'test' );

my $tickets = RT::Report::Tickets->new( RT->SystemUser );
$tickets->FromSQL('Updated <= "tomorrow"');
is( $tickets->Count, 1, "search with transaction join and positive results" );

$tickets->FromSQL('Updated < "yesterday"');
is( $tickets->Count, 0, "search with transaction join and 0 results" );


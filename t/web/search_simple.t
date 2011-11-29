use strict;
use warnings;

use RT::Test tests => 16;
my ( $baseurl, $m ) = RT::Test->started_ok;

RT::Test->create_tickets(
    { Queue   => 'General' },
    { Subject => 'ticket foo' },
    { Subject => 'ticket bar' },
);

ok( $m->login, 'logged in' );

$m->get_ok('/Search/Simple.html');
$m->content_lacks( 'Show Results', 'no page menu' );
$m->get_ok('/Search/Simple.html?q=ticket foo');
$m->content_contains( 'Show Results',   "has page menu" );
$m->title_is( 'Found 1 ticket', 'title' );
$m->content_contains( 'ticket foo', 'has ticket foo' );

# TODO more simple search tests

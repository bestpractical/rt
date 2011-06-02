use strict;
use warnings;
use RT::Test tests => 9;

my ($url, $m) = RT::Test->started_ok;

my ($ticket) =
  RT::Test->create_ticket( Queue => 'General', Subject => 'test subject' );

$m->login();

$m->get_ok( '/SelfService/Display.html?id=' . $ticket->id,
    'got selfservice display page' );

my $title = '#' . $ticket->id . ': test subject';
$m->title_is( $title );
$m->content_contains( "<h1>$title</h1>", "contains <h1>$title</h1>" );

# TODO need more SelfService tests

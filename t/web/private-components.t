use strict;

use RT::Test tests => 24;
my ($baseurl, $agent) = RT::Test->started_ok;

ok $agent->login, 'logged in';

$agent->get_ok("/Elements/Refresh?Name=private");
$agent->content_lacks("private");
$agent->content_lacks("Refresh this page every");

$agent->get_ok("/Ticket/Elements/ShowTime?minutes=42");
$agent->content_lacks("42 min");

$agent->get_ok("/Widgets/TitleBox?title=private");
$agent->content_lacks("private");

$agent->get_ok("/m/_elements/header?title=private");
$agent->content_lacks("private");

$agent->get_ok("/autohandler");
$agent->content_lacks("comp called without component");

$agent->get_ok("/NoAuth/js/autohandler");
$agent->content_lacks("no next component");

$agent->get_ok("/l");
$agent->content_lacks("No handle/phrase");

$agent->get_ok("/%61utohandler");
$agent->content_lacks("comp called without component");

$agent->get_ok("/%45lements/Refresh?Name=private");
$agent->content_lacks("private");
$agent->content_lacks("Refresh this page every");

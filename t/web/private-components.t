use strict;
use warnings;

use RT::Test tests => 24;
my ($baseurl, $agent) = RT::Test->started_ok;

ok $agent->login, 'logged in';

$agent->get("/Elements/Refresh?Name=private");
is($agent->status, 403);
$agent->content_lacks("private");
$agent->content_lacks("Refresh this page every");

$agent->get("/Ticket/Elements/ShowTime?minutes=42");
is($agent->status, 403);
$agent->content_lacks("42 min");

$agent->get("/Widgets/TitleBox?title=private");
is($agent->status, 403);
$agent->content_lacks("private");

$agent->get("/m/_elements/header?title=private");
is($agent->status, 403);
$agent->content_lacks("private");

$agent->get("/autohandler");
is($agent->status, 403);
$agent->content_lacks("comp called without component");

$agent->get("/NoAuth/js/autohandler");
is($agent->status, 403);
$agent->content_lacks("no next component");

$agent->get("/l");
is($agent->status, 403);
$agent->content_lacks("No handle/phrase");

$agent->get("/%61utohandler");
is($agent->status, 403);
$agent->content_lacks("comp called without component");

$agent->get("/%45lements/Refresh?Name=private");
is($agent->status, 403);
$agent->content_lacks("private");
$agent->content_lacks("Refresh this page every");

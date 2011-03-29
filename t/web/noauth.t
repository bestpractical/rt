use strict;

use RT::Test tests => 4;
my ($baseurl, $agent) = RT::Test->started_ok;

$agent->get("$baseurl/NoAuth/../Elements/HeaderJavascript");
is($agent->status, 400);

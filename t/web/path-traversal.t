use strict;
use warnings;

use RT::Test tests => 20;

my ($baseurl, $agent) = RT::Test->started_ok;

$agent->get("$baseurl/NoAuth/../Elements/HeaderJavascript");
is($agent->status, 400);
$agent->warning_like(qr/Invalid request.*aborting/,);

$agent->get("$baseurl/NoAuth/../%45lements/HeaderJavascript");
is($agent->status, 400);
$agent->warning_like(qr/Invalid request.*aborting/,);

$agent->get("$baseurl/NoAuth/%2E%2E/Elements/HeaderJavascript");
is($agent->status, 400);
$agent->warning_like(qr/Invalid request.*aborting/,);

$agent->get("$baseurl/NoAuth/../../../etc/RT_Config.pm");
is($agent->status, 400);
$agent->warning_like(qr/Invalid request.*aborting/,);

$agent->get("$baseurl/NoAuth/css/web2/images/../../../../../../etc/RT_Config.pm");
is($agent->status, 400);
$agent->warning_like(qr/Invalid request.*aborting/,);

# do not reject these URLs, even though they contain /. outside the path
$agent->get("$baseurl/index.html?ignored=%2F%2E");
is($agent->status, 200);

$agent->get("$baseurl/index.html?ignored=/.");
is($agent->status, 200);

$agent->get("$baseurl/index.html#%2F%2E");
is($agent->status, 200);

$agent->get("$baseurl/index.html#/.");
is($agent->status, 200);


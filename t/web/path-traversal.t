use strict;
use warnings;

use RT::Test tests => 9;

my ($baseurl, $agent) = RT::Test->started_ok;

$agent->get("$baseurl/NoAuth/../Elements/HeaderJavascript");
is($agent->status, 400);
$agent->warning_like(qr/Invalid request.*aborting/,);

$agent->get("$baseurl/NoAuth/../../../etc/RT_Config.pm");
is($agent->status, 400);
$agent->warning_like(qr/Invalid request.*aborting/,);


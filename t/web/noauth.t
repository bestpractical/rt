use strict;
use warnings;

use RT::Test tests => 6;

my ($baseurl, $agent) = RT::Test->started_ok;

$agent->get("$baseurl/NoAuth/../Elements/HeaderJavascript");
is($agent->status, 400);
# do this last, since it screws with agent state
$agent->warning_like(qr/Invalid request.*aborting/,);

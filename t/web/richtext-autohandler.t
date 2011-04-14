use strict;

use RT::Test tests => 7;
my ($baseurl, $agent) = RT::Test->started_ok;

$agent->get("$baseurl/NoAuth/RichText/FCKeditor/license.txt");
is($agent->status, 403);
$agent->content_lacks("It is not the purpose of this section to induce");

$agent->get_ok("/NoAuth/RichText/license.txt");
$agent->content_contains("It is not the purpose of this section to induce");

$agent->warning_like(qr/Invalid request directly to the rich text editor/,);

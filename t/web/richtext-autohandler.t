use strict;

use RT::Test tests => 9;
my ($baseurl, $agent) = RT::Test->started_ok;

$agent->get("$baseurl/NoAuth/RichText/ckeditor/config.js");
is($agent->status, 403);
$agent->content_lacks("config.disableNativeSpellChecker");

$agent->get_ok("/NoAuth/RichText/config.js");
$agent->content_contains("config.disableNativeSpellChecker");

$agent->warning_like(qr/Invalid request directly to the rich text editor/,);

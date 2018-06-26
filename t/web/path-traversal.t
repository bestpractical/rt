use strict;
use warnings;

use HTTP::Status qw();
use RT::Test tests => undef;

my ($baseurl, $agent) = RT::Test->started_ok;
ok($agent->login);

$agent->get("$baseurl/NoAuth/../Elements/HeaderJavascript");
is($agent->status, HTTP::Status::HTTP_BAD_REQUEST);
$agent->warning_like(qr/Invalid request.*aborting/);

$agent->get("$baseurl/NoAuth/../%45lements/HeaderJavascript");
is($agent->status, HTTP::Status::HTTP_BAD_REQUEST);
$agent->warning_like(qr/Invalid request.*aborting/);

$agent->get("$baseurl/NoAuth/%2E%2E/Elements/HeaderJavascript");
is($agent->status, HTTP::Status::HTTP_BAD_REQUEST);
$agent->warning_like(qr/Invalid request.*aborting/);

$agent->get("$baseurl/NoAuth/../../../etc/RT_Config.pm");
is($agent->status, HTTP::Status::HTTP_BAD_REQUEST);
$agent->warning_like(qr/Invalid request.*aborting/) unless $ENV{RT_TEST_WEB_HANDLER} =~ /^apache/;

$agent->get("$baseurl/static/css/web2/images/../../../../../../etc/RT_Config.pm");
# Apache hardcodes a 400 but the static handler returns a 403 for traversal too high
is($agent->status, $ENV{RT_TEST_WEB_HANDLER} =~ /^apache/ ? HTTP::Status::HTTP_BAD_REQUEST : HTTP::Status::HTTP_FORBIDDEN);

# Do not reject a simple /. in the URL, for downloading uploaded
# dotfiles, for example.
$agent->get("$baseurl/Ticket/Attachment/28/9/.bashrc");
is($agent->status, HTTP::Status::HTTP_NOT_FOUND);
$agent->next_warning_like(qr/could not be loaded/, "couldn't loaded warning");
$agent->content_like(qr/Attachment \S+ could not be loaded/);

# do not reject these URLs, even though they contain /. outside the path
$agent->get("$baseurl/index.html?ignored=%2F%2E");
is($agent->status, HTTP::Status::HTTP_OK);

$agent->get("$baseurl/index.html?ignored=/.");
is($agent->status, HTTP::Status::HTTP_OK);

$agent->get("$baseurl/index.html#%2F%2E");
is($agent->status, HTTP::Status::HTTP_OK);

$agent->get("$baseurl/index.html#/.");
is($agent->status, HTTP::Status::HTTP_OK);

done_testing;

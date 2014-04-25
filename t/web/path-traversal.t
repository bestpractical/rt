use strict;
use warnings;

use RT::Test tests => undef;

my ($baseurl, $agent) = RT::Test->started_ok;
ok($agent->login);

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
SKIP: {
    skip "Apache rejects busting up above / for us", 2 if $ENV{RT_TEST_WEB_HANDLER} =~ /^apache/;
    $agent->warning_like(qr/Invalid request.*aborting/,);
};

$agent->get("$baseurl/NoAuth/css/web2/images/../../../../../../etc/RT_Config.pm");
is($agent->status, 400);
SKIP: {
    skip "Apache rejects busting up above / for us", 2 if $ENV{RT_TEST_WEB_HANDLER} =~ /^apache/;
    $agent->warning_like(qr/Invalid request.*aborting/,);
};

# Do not reject a simple /. in the URL, for downloading uploaded
# dotfiles, for example.
$agent->get("$baseurl/Ticket/Attachment/28/9/.bashrc");
is($agent->status, 200); # Even for a file not found, we return 200
$agent->content_contains("Bad attachment id");

# do not reject these URLs, even though they contain /. outside the path
$agent->get("$baseurl/index.html?ignored=%2F%2E");
is($agent->status, 200);

$agent->get("$baseurl/index.html?ignored=/.");
is($agent->status, 200);

$agent->get("$baseurl/index.html#%2F%2E");
is($agent->status, 200);

$agent->get("$baseurl/index.html#/.");
is($agent->status, 200);

undef $agent;
done_testing;

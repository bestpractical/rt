use strict;
use warnings;

use RT::Test tests => 11;

my ($url, $m);

# Enabled by default
{
    ok(RT->Config->Get('Framebusting'), "Framebusting enabled by default");

    ($url, $m) = RT::Test->started_ok;
    $m->get_ok($url);
    $m->content_contains('if (window.top !== window.self) {', "Found the framekiller javascript");
    is $m->response->header('X-Frame-Options'), 'DENY', "X-Frame-Options is set to DENY";

    RT::Test->stop_server;
}

# Disabled
{
    RT->Config->Set('Framebusting', 0);

    ($url, $m) = RT::Test->started_ok;
    $m->get_ok($url);
    $m->content_lacks('if (window.top !== window.self) {', "Didn't find the framekiller javascript");
    is $m->response->header('X-Frame-Options'), undef, "X-Frame-Options is not present";
}


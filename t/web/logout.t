use strict;
use warnings;

use RT::Test tests => 12;

my ($baseurl, $agent) = RT::Test->started_ok;

my $url = $agent->rt_base_url;
diag $url if $ENV{TEST_VERBOSE};

# test that logout would actually redirects to the correct URL
{
    ok $agent->login, "logged in";
    $agent->follow_link_ok({ text => 'Logout' });
    like $agent->uri, qr'/Logout\.html$', "right url";
    $agent->content_contains('<meta http-equiv="refresh" content="1;URL=/"', "found the expected meta-refresh");
}

# Stop server and set MasonLocalComponentRoot
RT::Test->stop_server;

RT->Config->Set(MasonLocalComponentRoot => RT::Test::get_abs_relocatable_dir('html'));

($baseurl, $agent) = RT::Test->started_ok;

$url = $agent->rt_base_url;
diag $url if $ENV{TEST_VERBOSE};

# test that logout would actually redirects to URL from the callback
{
    ok $agent->login, "logged in";
    $agent->follow_link_ok({ text => 'Logout' });
    like $agent->uri, qr'/Logout\.html$', "right url";
    $agent->content_contains('<meta http-equiv="refresh" content="1;URL=http://bestpractical.com/rt"', "found the expected meta-refresh");
}


1;

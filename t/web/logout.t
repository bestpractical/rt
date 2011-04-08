#!/usr/bin/perl
use strict;
use warnings;

use RT::Test tests => 7;

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

1;

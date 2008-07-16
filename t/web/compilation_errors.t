#!/usr/bin/perl

use strict;
use RT::Test;
use Test::More;
my $tests = 2;
find ( sub { wanted() and $tests += 4 } , 'share/html/');
plan tests => $tests;
use HTTP::Request::Common;
use HTTP::Cookies;
use LWP;
use Encode;

my $cookie_jar = HTTP::Cookies->new;


my ($baseurl, $agent) = RT::Test->started_ok;

# give the agent a place to stash the cookies
$agent->cookie_jar($cookie_jar);

# get the top page
my $url = $agent->rt_base_url;
diag "base URL is '$url'" if $ENV{TEST_VERBOSE};
$agent->get($url);

# {{{ test a login
$agent->login(root => 'password');
like( $agent->{'content'} , qr/Logout/i, "Found a logout link");


use File::Find;
find ( sub { wanted() and test_get($File::Find::name) } , 'share/html/');

sub wanted {
        -f  && /\.html$/ && $_ !~ /Logout.html$/;
}

sub test_get {
        my $file = shift;

        $file =~ s#^share/html/##;
        diag( "testing $url/$file" ) if $ENV{TEST_VERBOSE};
        ok ($agent->get("$url/$file", "GET $url/$file"), "Can Get $url/$file");
        is ($agent->{'status'}, 200, "Loaded $file");
#        ok( $agent->{'content'} =~ /Logout/i, "Found a logout link on $file ");
        ok( $agent->{'content'} !~ /Not logged in/i, "Still logged in for  $file");
        ok( $agent->{'content'} !~ /raw error/i, "Didn't get a Mason compilation error on $file");
}

# }}}

1;

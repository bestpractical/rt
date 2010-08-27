#!/usr/bin/perl

use strict;
use Test::More;
use File::Find;
BEGIN {
    sub wanted {
        -f && /\.html$/ && $_ !~ /Logout.html$/;
    }
    my $tests = 6;
    find( sub { wanted() and $tests += 4 }, 'share/html/' );
    plan tests => $tests;
}


use HTTP::Request::Common;
use HTTP::Cookies;
use LWP;
use Encode;

my $cookie_jar = HTTP::Cookies->new;

use RT::Test;
my ($baseurl, $agent) = RT::Test->started_ok;

# give the agent a place to stash the cookies
$agent->cookie_jar($cookie_jar);

# get the top page
my $url = $agent->rt_base_url;
$agent->get($url);

is ($agent->{'status'}, 200, "Loaded a page");

# follow the link marked "Login"
$agent->login(root => 'password');
is($agent->{'status'}, 200, "Fetched the page ok");
like( $agent->{'content'} , qr/Logout/i, "Found a logout link");


find ( sub { wanted() and test_get($File::Find::name) } , 'share/html/');

TODO: {
    local $TODO = "we spew *lots* of undef warnings";
    $agent->no_warnings_ok;
};

sub test_get {
        my $file = shift;

        $file =~ s#^share/html/##;
        diag( "testing $url/$file" );
        $agent->get_ok("$url/$file");
        is ($agent->{'status'}, 200, "Loaded $file");
#        ok( $agent->{'content'} =~ /Logout/i, "Found a logout link on $file ");
        ok( $agent->{'content'} !~ /Not logged in/i, "Still logged in for  $file");
        ok( $agent->{'content'} !~ /raw error/i, "Didn't get a Mason compilation error on $file") or do {
            if (my ($error) = $agent->{'content'} =~ /<pre>(.*)/) {
                diag "$file: $error";
            }
        };
}

1;

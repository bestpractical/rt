#!/usr/bin/perl

use strict;
use Test::More qw/no_plan/;
use WWW::Mechanize;
use HTTP::Request::Common;
use HTTP::Cookies;
use LWP;
use Encode;

my $cookie_jar = HTTP::Cookies->new;
my $agent = WWW::Mechanize->new();

# give the agent a place to stash the cookies

$agent->cookie_jar($cookie_jar);

use RT;
RT::LoadConfig;

# get the top page
my $url = $RT::WebURL;
$agent->get($url);

is ($agent->{'status'}, 200, "Loaded a page");


# {{{ test a login

# follow the link marked "Login"

ok($agent->{form}->find_input('user'));

ok($agent->{form}->find_input('pass'));
ok ($agent->{'content'} =~ /username:/i);
$agent->field( 'user' => 'root' );
$agent->field( 'pass' => 'password' );
# the field isn't named, so we have to click link 0
$agent->click(0);
is($agent->{'status'}, 200, "Fetched the page ok");
ok( $agent->{'content'} =~ /Logout/i, "Found a logout link");


use File::Find;
find ( \&wanted , 'html/');

sub wanted {
        -f  && /\.html$/ && $_ !~ /Logout.html$/  && test_get($File::Find::name);
}       

sub test_get {
        my $file = shift;


        $file =~ s#^html/##; 
        ok ($agent->get("$url/$file", "GET $url/$file"));
        is ($agent->{'status'}, 200, "Loaded $file");
#        ok( $agent->{'content'} =~ /Logout/i, "Found a logout link on $file ");
        ok( $agent->{'content'} !~ /Not logged in/i, "Still logged in for  $file");
        ok( $agent->{'content'} !~ /System error/i, "Didn't get a Mason compilation error on $file");
        
}

# }}}

1;

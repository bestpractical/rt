use strict;
use warnings;

use RT::Test tests => undef;

sub child_path_is($$$) {
    my ($menu, $child, $expected) = @_;
    my $c = $menu->child($child->[0], path => $child->[1]);
    is $c->path, $expected, "'$child->[1]' normalizes to '$expected'";
    return $c;
}

{
    package FakeRequest;
    sub new { bless {}, shift }
    sub path_info { "" }

    package FakeInterp;
    require CGI;
    sub new { bless {}, shift }
    sub cgi_object { CGI->new }
}

local $HTML::Mason::Commands::r = FakeRequest->new;
local $HTML::Mason::Commands::m = FakeInterp->new;

my $menu = RT::Interface::Web::Menu->new;
ok $menu, "Created top level menu";

child_path_is $menu, [search    => "Search/Simple.html"],   "/Search/Simple.html";
child_path_is $menu, [absolute  => "/Prefs/Other.html"],    "/Prefs/Other.html";
child_path_is $menu, [scheme    => "http://example.com"],   "http://example.com";

my $tools =
    child_path_is $menu,    [tools      => "/Tools/"],              "/Tools/";
    child_path_is $tools,   [myday      => "MyDay.html"],           "/Tools/MyDay.html";
    child_path_is $tools,   [activity   => "/Activity.html"],       "/Activity.html";
    my $ext =
        child_path_is $tools,   [external   => "http://example.com"],   "http://example.com";
        child_path_is $ext,     [wiki       => "wiki/"],                "http://example.com/wiki/";

# Pathological case of multiplying slashes
my $home =
    child_path_is $menu, [home  => "/"], "/";
    child_path_is $home, [slash => "/"], "/";
    child_path_is $home, [empty => ""],  "/";

done_testing;

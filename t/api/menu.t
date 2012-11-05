use strict;
use warnings;

use RT::Test tests => undef;
use RT::Interface::Web::Menu;

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



sub order_ok($$;$) {
    my ($menu, $expected, $name) = @_;
    my @children = $menu->children;

    is scalar @children, scalar @$expected, "correct number of children";
    is_deeply [map { $_->key } @children], $expected, $name;
    
    my $last_child = shift @children; # first child's sort doesn't matter
    for (@children) {
        ok $_->sort_order > $last_child->sort_order, sprintf "%s order higher than %s's", $_->key, $last_child->key;
        $last_child = $_;
    }
}

$menu = RT::Interface::Web::Menu->new;

ok $menu->child("foo", title => "foo"), "added child foo";
order_ok $menu, [qw(foo)], "sorted";

ok $menu->child("foo")->add_after("bar", title => "bar"), "added child bar after foo";
order_ok $menu, [qw(foo bar)], "sorted after";

ok $menu->child("bar")->add_before("baz", title => "baz"), "added child baz before bar";
order_ok $menu, [qw(foo baz bar)], "sorted before (in between)";

ok $menu->child("bat", title => "bat", sort_order => 2.2), "added child bat between baz and bar";
order_ok $menu, [qw(foo baz bat bar)], "sorted between manually";

ok $menu->child("bat")->add_before("pre", title => "pre"), "added child pre before bat";
order_ok $menu, [qw(foo baz pre bat bar)], "sorted between (before)";

ok $menu->child("bat")->add_after("post", title => "post"), "added child post after bat";
order_ok $menu, [qw(foo baz pre bat post bar)], "sorted between (after)";

done_testing;

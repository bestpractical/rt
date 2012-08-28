use strict;
use warnings;

use RT::Test tests => undef;
use RT::Interface::Web::Menu;

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

my $menu = RT::Interface::Web::Menu->new;

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

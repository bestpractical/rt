#!/usr/bin/perl -w

use strict;
use warnings;

use RT::Test; use Test::More;
use Test::Deep;
BEGIN { require "t/shredder/utils.pl"; }

my @PLUGINS = sort qw(Attachments Base Objects SQLDump Summary Tickets Users);
plan tests => 7 + 3 * @PLUGINS;

use_ok('RT::Shredder::Plugin');
{
    my $plugin = RT::Shredder::Plugin->new;
    isa_ok($plugin, 'RT::Shredder::Plugin');
    my %plugins = $plugin->List;
    cmp_deeply( [sort keys %plugins], [@PLUGINS], "correct plugins" );
}
{ # test ->List as class method
    my %plugins = RT::Shredder::Plugin->List;
    cmp_deeply( [sort keys %plugins], [@PLUGINS], "correct plugins" );
}
{ # reblessing on load_by_name
    foreach (@PLUGINS) {
        my $plugin = RT::Shredder::Plugin->new;
        isa_ok($plugin, 'RT::Shredder::Plugin');
        my ($status, $msg) = $plugin->load_by_name( $_ );
        ok($status, "loaded plugin by name") or diag("error: $msg");
        isa_ok($plugin, "RT::Shredder::Plugin::$_" );
    }
}
{ # error checking in load_by_name
    my $plugin = RT::Shredder::Plugin->new;
    isa_ok($plugin, 'RT::Shredder::Plugin');
    my ($status, $msg) = $plugin->load_by_name;
    ok(!$status, "not loaded plugin - empty name");
    ($status, $msg) = $plugin->load_by_name('Foo');
    ok(!$status, "not loaded plugin - not exist");
}


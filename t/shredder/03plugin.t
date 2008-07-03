#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;
use Test::Deep;
use File::Spec;
BEGIN {
    (my $volume, my $directories, my $file) = File::Spec->splitpath($0);
    my $shredder_utils = File::Spec->catfile(
        File::Spec->catdir(File::Spec->curdir(), $directories), "utils.pl");
    require $shredder_utils;
}

my @PLUGINS = sort qw(Attachments Base Objects SQLDump Summary Tickets Users);
plan tests => 7 + 3 * @PLUGINS;

use_ok('RT::Shredder::Plugin');
{
    my $plugin = new RT::Shredder::Plugin;
    isa_ok($plugin, 'RT::Shredder::Plugin');
    my %plugins = $plugin->List;
    cmp_deeply( [sort keys %plugins], [@PLUGINS], "correct plugins" );
}
{ # test ->List as class method
    my %plugins = RT::Shredder::Plugin->List;
    cmp_deeply( [sort keys %plugins], [@PLUGINS], "correct plugins" );
}
{ # reblessing on LoadByName
    foreach (@PLUGINS) {
        my $plugin = new RT::Shredder::Plugin;
        isa_ok($plugin, 'RT::Shredder::Plugin');
        my ($status, $msg) = $plugin->LoadByName( $_ );
        ok($status, "loaded plugin by name") or diag("error: $msg");
        isa_ok($plugin, "RT::Shredder::Plugin::$_" );
    }
}
{ # error checking in LoadByName
    my $plugin = new RT::Shredder::Plugin;
    isa_ok($plugin, 'RT::Shredder::Plugin');
    my ($status, $msg) = $plugin->LoadByName;
    ok(!$status, "not loaded plugin - empty name");
    ($status, $msg) = $plugin->LoadByName('Foo');
    ok(!$status, "not loaded plugin - not exist");
}


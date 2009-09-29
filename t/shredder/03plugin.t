#!/usr/bin/perl -w

use strict;
use warnings;

use Test::Deep;
use File::Spec;
use Test::More tests => 28;
use RT::Test ();
BEGIN {
    my $shredder_utils = RT::Test::get_relocatable_file('utils.pl',
        File::Spec->curdir());
    require $shredder_utils;
}

my @PLUGINS = sort qw(Attachments Base Objects SQLDump Summary Tickets Users);

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


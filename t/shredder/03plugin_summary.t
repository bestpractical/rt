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

plan tests => 4;

use_ok('RT::Shredder::Plugin');
my $plugin_obj = new RT::Shredder::Plugin;
isa_ok($plugin_obj, 'RT::Shredder::Plugin');
my ($status, $msg) = $plugin_obj->LoadByName('Summary');
ok($status, 'loaded summary plugin') or diag "error: $msg";
isa_ok($plugin_obj, 'RT::Shredder::Plugin::Summary');


#!/usr/bin/perl -w

use strict;
use warnings;

use Test::Deep;
use File::Spec;
use Test::More tests => 4;
use RT::Test nodb => 1;
BEGIN {
    my $shredder_utils = RT::Test::get_relocatable_file('utils.pl',
        File::Spec->curdir());
    require $shredder_utils;
}


use_ok('RT::Shredder::Plugin');
my $plugin_obj = RT::Shredder::Plugin->new;
isa_ok($plugin_obj, 'RT::Shredder::Plugin');
my ($status, $msg) = $plugin_obj->LoadByName('Summary');
ok($status, 'loaded summary plugin') or diag "error: $msg";
isa_ok($plugin_obj, 'RT::Shredder::Plugin::Summary');


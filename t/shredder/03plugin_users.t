#!/usr/bin/perl -w

use strict;
use warnings;

use RT::Test; use Test::More;
use Test::Deep;
use File::Spec;
use RT::Test ();
BEGIN {
    my $shredder_utils = RT::Test::get_relocatable_file('utils.pl',
        File::Spec->curdir());
    require $shredder_utils;
}

plan tests => 9;

my @ARGS = sort qw(limit status name email replace_relations no_tickets);

use_ok('RT::Shredder::Plugin::Users');
{
    my $plugin = RT::Shredder::Plugin::Users->new;
    isa_ok($plugin, 'RT::Shredder::Plugin::Users');

    is(lc $plugin->type, 'search', 'correct type');

    my @args = sort $plugin->support_args;
    cmp_deeply(\@args, \@ARGS, "support all args");

    my ($status, $msg) = $plugin->test_args( name => 'r??t*' );
    ok($status, "arg name = 'r??t*'") or diag("error: $msg");

    for (qw(any disabled enabled)) {
        my ($status, $msg) = $plugin->test_args( status => $_ );
        ok($status, "arg status = '$_'") or diag("error: $msg");
    }
    ($status, $msg) = $plugin->test_args( status => '!@#' );
    ok(!$status, "bad 'status' arg value");
}


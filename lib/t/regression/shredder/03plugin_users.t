#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;
use Test::Deep;
BEGIN { require "lib/t/regression/shredder/utils.pl"; }

plan tests => 9;

my @ARGS = qw(limit status name email replace_relations);

use_ok('RT::Shredder::Plugin::Users');
{
    my $plugin = new RT::Shredder::Plugin::Users;
    isa_ok($plugin, 'RT::Shredder::Plugin::Users');
    my @args = $plugin->SupportArgs;
    cmp_deeply(\@args, \@ARGS, "support all args");
    my ($status, $msg) = $plugin->TestArgs( name => 'r??t*' );
    ok($status, "arg name = 'r??t*'") or diag("error: $msg");
    ($status, $msg) = $plugin->TestArgs( name => '!@#' );
    ok(!$status, "bad arg name = '!@#'");
    for (qw(any disabled enabled)) {
        my ($status, $msg) = $plugin->TestArgs( status => $_ );
        ok($status, "arg status = '$_'") or diag("error: $msg");
    }
    ($status, $msg) = $plugin->TestArgs( status => '!@#' );
    ok(!$status, "bad 'status' arg value");
}


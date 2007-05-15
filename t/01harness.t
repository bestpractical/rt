#!/usr/bin/perl

use strict;
use warnings;

use Test::More qw(no_plan);
BEGIN { require 't/utils.pl' }

use RT;
ok(RT::LoadConfig);
ok(RT::Init, "Basic initialization and DB connectivity");

if ($ARGV[0]) {

my $test = shift @ARGV;
require $test;

}


#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';
BEGIN { require 't/utils.pl' }

use_ok( 'RT::FM::System');
my $sys = RT::FM::System->new();
is( $sys->Id, 1);
is ($sys->id, 1);


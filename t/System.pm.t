#!/usr/bin/perl -w

use Test::More 'no_plan';

use_ok( 'RT::FM::System');
my $sys = RT::FM::System->new();
is( $sys->Id, 1);
is ($sys->id, 1);


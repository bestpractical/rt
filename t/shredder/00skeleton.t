#!/usr/bin/perl -w

use strict;
use warnings;

use RT::Test; use Test::More;
use Test::Deep;
BEGIN { require "t/shredder/utils.pl"; }
init_db();

plan tests => 1;

create_savepoint('clean'); # backup of the clean RT DB
my $shredder = shredder_new(); # new shredder object

# ....
# create and wipe RT objects
#

cmp_deeply( dump_current_and_savepoint('clean'), "current DB equal to savepoint");

if( is_all_successful() ) {
	cleanup_tmp();
} else {
	diag( note_on_fail() );
}


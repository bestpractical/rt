#!/usr/bin/perl -w

use strict;
use warnings;

use RT::Test; use Test::More;
use Test::Deep;
use File::Spec;
use RT::Test::Shredder;
RT::Test::Shredder::init_db();

plan tests => 1;

RT::Test::Shredder::create_savepoint('clean'); # backup of the clean RT DB
my $shredder = RT::Test::Shredder::shredder_new(); # new shredder object

# ....
# create and wipe RT objects
#

cmp_deeply( RT::Test::Shredder::dump_current_and_savepoint('clean'), "current DB equal to savepoint");

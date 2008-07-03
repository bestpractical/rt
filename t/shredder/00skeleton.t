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
init_db();

plan tests => 1;

create_savepoint('clean'); # backup of the clean RT DB
my $shredder = shredder_new(); # new shredder object

# ....
# create and wipe RT objects
#

cmp_deeply( dump_current_and_savepoint('clean'), "current DB equal to savepoint");

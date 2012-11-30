
use strict;
use warnings;

use Test::Deep;
use RT::Test::Shredder tests => 1;
my $test = "RT::Test::Shredder";

$test->create_savepoint('clean'); # backup of the clean RT DB
my $shredder = $test->shredder_new(); # new shredder object

# ....
# create and wipe RT objects
#

cmp_deeply( $test->dump_current_and_savepoint('clean'), "current DB equal to savepoint");

use strict;
use warnings;
use RT::Test nodb => 1, tests => 1;
TODO: { 
    todo_skip "No tests written for VERP yet", 1;
    ok(1,"a test to skip");
}

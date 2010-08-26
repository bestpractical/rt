#!/usr/bin/perl -w

use strict;
use RT::Test tests => 1;
TODO: { 
    todo_skip "No tests written for VERP yet", 1;
    ok(1,"a test to skip");
}

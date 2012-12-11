package RT::User;
use strict;
use warnings;

our $LOADED_OVERLAY = 1;

sub _LocalAccessible {
    { Comments => { public => 1 } }
}

1;

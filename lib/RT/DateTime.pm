use strict;
use warnings;

package RT::DateTime;
use base 'Jifty::DateTime';

sub age {
    my $self  = shift;
    my $until = shift || RT::DateTime->now;

    return $until - $self;
}

1;


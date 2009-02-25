use strict;
use warnings;

package RT::DateTime;
use base 'Jifty::DateTime';

use RT::DateTime::Duration;

use constant duration_class => 'RT::DateTime::Duration';

sub age {
    my $self  = shift;
    my $until = shift || RT::DateTime->now;

    # XXX: This doesn't work yet because DateTime doesn't have a duration_class
    # method
    # return $until - $self;

    my $duration = $until - $self;
    bless $duration, $self->duration_class;
}

1;


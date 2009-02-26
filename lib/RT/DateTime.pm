use strict;
use warnings;

package RT::DateTime;
use base 'Jifty::DateTime';

use RT::DateTime::Duration;

use constant duration_class => 'RT::DateTime::Duration';

sub _stringify {
    my $self = shift;

    return "unset" if $self->epoch == 0;
    return $self->SUPER::_stringify(@_);
}

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


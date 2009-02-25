use strict;
use warnings;

package RT::DateTime::Duration;
use base 'DateTime::Duration';

use overload (
    q{""} => '_stringify',
);

sub _stringify {
    my $self = shift;
    my ($days, $hours, $minutes) = $self->in_units('days', 'hours', 'minutes');

    # Obviously not good enough, but a start.
    return "$days days, $hours hours, $minutes minutes";
}

1;


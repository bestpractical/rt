use strict;
use warnings;

package RT::DateTime::Duration;
use base 'DateTime::Duration';

use overload (
    q{""} => '_stringify',
);

sub _stringify {
    my $self = shift;

    my %delta = $self->deltas;

    my ($count, $unit);

    if ($delta{months} >= 12) {
        ($count, $unit) = ($self->in_units('years'), 'years');
    }
    elsif ($delta{months}) {
        ($count, $unit) = ($self->in_units('months'), 'months');
    }
    elsif ($delta{days} >= 7) {
        ($count, $unit) = ($self->in_units('weeks'), 'weeks');
    }
    elsif ($delta{days}) {
        ($count, $unit) = ($self->in_units('days'), 'days');
    }
    elsif ($delta{minutes} >= 60) {
        ($count, $unit) = ($self->in_units('hours'), 'hours');
    }
    elsif ($delta{minutes}) {
        ($count, $unit) = ($self->in_units('minutes'), 'min');
    }
    else {
        ($count, $unit) = ($self->in_units('seconds'), 'sec');
    }

    if ($self->is_negative) {
        return _("%1 %2 ago", $count, $unit);
    }
    else {
        return _("%1 %2", $count, $unit);
    }

}

1;


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

sub _canonicalize_time_zone {
    my $self = shift;
    my $tz = shift;

    if (lc($tz) eq 'user') {
        return $self->current_user->user_object->time_zone;
    }
    elsif (lc($tz) eq 'server') {
        return RT->config->get('TimeZone');
    }

    return $tz;
}

sub new {
    my $self = shift;
    my %args = @_;

    $args{time_zone} = $self->_canonicalize_time_zone($args{time_zone})
        if defined $args{time_zone};

    return $self->SUPER::new(%args);
}

sub set_time_zone {
    my $self = shift;
    my $tz   = shift;

    return $self->SUPER::set_time_zone($self->_canonicalize_time_zone($tz));
}

1;


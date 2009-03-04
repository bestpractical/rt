use strict;
use warnings;

package RT::DateTime;
use base 'Jifty::DateTime';

use RT::DateTime::Duration;

use constant duration_class => 'RT::DateTime::Duration';

sub _stringify {
    my $self = shift;

    return "unset" if $self->epoch == 0;
    return $self->strftime(RT->config->get('DateTimeFormat'));
}

sub age {
    my $self  = shift;
    my $until = shift || RT::DateTime->now;

    return $until - $self;
}

sub _canonicalize_time_zone {
    my $self    = shift;
    my $tz      = shift;
    my $default = shift || 'UTC';

    if (lc($tz) eq 'user') {
        $tz = $self->current_user->user_object->time_zone;
    }

    # if the user time zone is requested and the user has none, use the server's
    # time zone
    if (!$tz || lc($tz) eq 'server' || lc($tz) eq 'system') {
        $tz = RT->config->get('TimeZone');
    }

    return $tz || $default;
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

sub rfc2822 {
    my $self = shift;
    return $self->strftime('%a, %d %b %Y %H:%M:%S %z');
}

sub iso {
    my $self = shift;
    my %args = (
        date => 1,
        time => 1,
        @_,
    );

    if ($args{time} && $args{date}) {
        return join ' ', $self->ymd('-'), $self->hms(':');
    }
    elsif ($args{date}) {
        return $self->ymd('-');
    }
    elsif ($args{time}) {
        return $self->hms(':');
    }
    else {
        return '';
    }
}

1;


use strict;
use warnings;

package RT::DateTime;
use base 'Jifty::DateTime';

use RT::DateTime::Duration;

use constant duration_class => 'RT::DateTime::Duration';

sub _stringify { shift->config_format }

sub is_unset { shift->epoch == 0 }

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

sub new_from_string {
    my $class  = shift;
    my $string = shift;
    my %args = (
        time_zone => undef,
        @_,
    );

    if ($args{time_zone}) {
        $args{time_zone} = $class->_canonicalize_time_zone($args{time_zone});
    }

    my $dt = $class->SUPER::new_from_string($string, %args);

    if (!defined($dt)) {
        return RT::DateTime->from_epoch(epoch => 0);
    }

    return $dt;
}

sub strftime {
    my $self = shift;

    return 'unset' if $self->is_unset;
    return $self->SUPER::strftime(@_);
}

sub _canonicalize_self {
    my $self = shift;
    my %args = (
        time_zone => undef,
        @_,
    );

    my $clone;
    if ($args{time_zone}) {
        $clone = $self->clone;
        $clone->set_time_zone($args{time_zone});
        return $clone;
    }

    return $self;
}

sub rfc2822 {
    my $self = _canonicalize_self(@_);

    return $self->strftime('%a, %d %b %Y %H:%M:%S %z');
}

sub iso {
    my $self = _canonicalize_self(@_);

    return $self->strftime('%Y-%m-%d %H:%M:%S');
}

sub config_format {
    my $self = _canonicalize_self(@_);

    return $self->strftime(RT->config->get('DateTimeFormat'));
}

1;


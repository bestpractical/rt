# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2007 Best Practical Solutions, LLC
#                                          <jesse@bestpractical.com>
#
# (Except where explicitly superseded by other copyright notices)
#
#
# LICENSE:
#
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
#
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/copyleft/gpl.html.
#
#
# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
#
# END BPS TAGGED BLOCK }}}

=head1 name

  RT::Date - a simple object Oriented date.

=head1 SYNOPSIS

  use RT::Date

=head1 description

RT date is a simple date object designed to be speedy and easy for RT to use

The fact that it assumes that a time of 0 means "never" is probably a bug.


=head1 METHODS

=cut

package RT::Date;

use Time::Local;
use POSIX qw(tzset);

use strict;
use warnings;
use base qw/RT::Base/;

use vars qw($MINUTE $HOUR $DAY $WEEK $MONTH $YEAR);

$MINUTE = 60;
$HOUR   = 60 * $MINUTE;
$DAY    = 24 * $HOUR;
$WEEK   = 7 * $DAY;
$MONTH  = 30.4375 * $DAY;
$YEAR   = 365.25 * $DAY;

our @MONTHS = qw(
    Jan
    Feb
    Mar
    Apr
    May
    Jun
    Jul
    Aug
    Sep
    Oct
    Nov
    Dec
);

our @DAYS_OF_WEEK = qw(
    Sun
    Mon
    Tue
    Wed
    Thu
    Fri
    Sat
);

=head2 new

object constructor takes one argument C<RT::CurrentUser> object.

=cut

sub new {
    my $class = shift;
    my $self  = {};
    bless $self => ref($class) || $class;
    $self->_get_current_user(@_);
    $self->unix(0);
    return $self;
}

=head2 set

Takes a param hash with the fields C<Format>, C<value> and C<timezone>.

If $args->{'format'} is 'unix', takes the number of seconds since the epoch.

If $args->{'format'} is iso, tries to parse an iso date.

If $args->{'format'} is 'unknown', require Time::ParseDate and make it figure
things out. This is a heavyweight operation that should never be called from
within RT's core. But it's really useful for something like the textbox date
entry where we let the user do whatever they want.

If $args->{'value'} is 0, assumes you mean never.

=cut

sub set {
    my $self = shift;
    my %args = (
        format   => 'unix',
        value    => time,
        timezone => 'user',
        @_
    );

    return $self->unix(0) unless $args{'value'};

    if ( $args{'format'} =~ /^unix$/i ) {
        return $self->unix( $args{'value'} );
    } elsif ( $args{'format'} =~ /^(sql|datemanip|iso)$/i ) {
        $args{'value'} =~ s!/!-!g;

        if (   ( $args{'value'} =~ /^(\d{4})?(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)$/ )
            || ( $args{'value'} =~ /^(\d{4})?(\d\d)(\d\d)(\d\d):(\d\d):(\d\d)$/ )
            || ( $args{'value'} =~ /^(?:(\d{4})-)?(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)$/ )
            || ( $args{'value'} =~ /^(?:(\d{4})-)?(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)\+00$/ ) )
        {

            my ( $year, $mon, $mday, $hours, $min, $sec ) = ( $1, $2, $3, $4, $5, $6 );

            # use current year if string has no value
            $year ||= ( CORE::localtime time )[5] + 1900;

            #timegm expects month as 0->11
            $mon--;

            #now that we've parsed it, deal with the case where everything was 0
            return $self->unix(0) if $mon < 0 || $mon > 11;

            my $tz = lc $args{'format'} eq 'datemanip' ? 'user' : 'utc';
            $self->unix( $self->time_local( $tz, $sec, $min, $hours, $mday, $mon, $year ) );

            $self->unix(0) unless $self->unix > 0;
        } else {
            Jifty->log->warn( "Couldn't parse date '$args{'value'}' as a $args{'format'} format" );
            return $self->unix(undef);
        }
    } elsif ( $args{'format'} =~ /^unknown$/i ) {
        require Time::ParseDate;

        # the module supports only legacy timezones like PDT or EST...
        # so we parse date as GMT and later apply offset
        my $date = Time::ParseDate::parsedate(
            $args{'value'},
            GMT           => 1,
            UK            => RT->config->get('date_day_before_month'),
            PREFER_PAST   => RT->config->get('AmbiguousDayInPast'),
            PREFER_FUTURE => !RT->config->get('AmbiguousDayInPast')
        );

        # apply timezone offset
        $date -= ( $self->localtime( $args{timezone}, $date ) )[9];

        Jifty->log->debug("RT::Date used Time::ParseDate to make '$args{'value'}' $date\n");

        return $self->set( format => 'unix', value => $date );
    } else {
        Jifty->log->debug("Unknown date format: $args{'format'}\n");
        return $self->unix(undef);
    }

    return $self->unix;
}

=head2 set_to_now

Set the object's time to the current time. Takes no arguments
and returns unix time.

=cut

sub set_to_now {
    return $_[0]->unix(time);
}

=head2 set_to_midnight [timezone => 'utc']

Sets the date to midnight (at the beginning of the day).
Returns the unixtime at midnight.

Arguments:

=over 4

=item timezone

timezone context C<user>, C<server> or C<UTC>. See also L</timezone>.

=back

=cut

sub set_to_midnight {
    my $self = shift;
    my %args = ( timezone => '', @_ );
    my $new  = $self->time_local( $args{'timezone'}, 0, 0, 0, ( $self->localtime( $args{'timezone'} ) )[ 3 .. 9 ] );
    return $self->unix($new);
}

=head2 diff

Takes either an C<RT::Date> object or the date in unixtime format as a string,
if nothing is specified uses the current time.

Returns the differnce between the time in the current object and that time
as a number of seconds. Returns C<undef> if any of two compared values is
incorrect or not set.

=cut

sub diff {
    my $self  = shift;
    my $other = shift;
    $other = time unless defined $other;
    if ( UNIVERSAL::isa( $other, 'RT::Date' ) ) {
        $other = $other->unix;
    }
    return undef unless $other =~ /^\d+$/ && $other > 0;

    my $unix = $self->unix;
    return undef unless $unix > 0;

    return $unix - $other;
}

=head2 diff_as_string

Takes either an C<RT::Date> object or the date in unixtime format as a string,
if nothing is specified uses the current time.

Returns the differnce between C<$self> and that time as a number of seconds as
a localized string fit for human consumption. Returns empty string if any of
two compared values is incorrect or not set.

=cut

sub diff_as_string {
    my $self = shift;
    my $diff = $self->diff(@_);
    return '' unless defined $diff;

    return $self->duration_as_string($diff);
}

=head2 duration_as_string

Takes a number of seconds. Returns a localized string describing
that duration.

=cut

sub duration_as_string {
    my $self     = shift;
    my $duration = int shift;

    my ( $negative, $s, $time_unit );
    $negative = 1 if $duration < 0;
    $duration = abs $duration;

    if ( $duration < $MINUTE ) {
        $s         = $duration;
        $time_unit = _("sec");
    } elsif ( $duration < ( 2 * $HOUR ) ) {
        $s         = int( $duration / $MINUTE + 0.5 );
        $time_unit = _("min");
    } elsif ( $duration < ( 2 * $DAY ) ) {
        $s         = int( $duration / $HOUR + 0.5 );
        $time_unit = _("hours");
    } elsif ( $duration < ( 2 * $WEEK ) ) {
        $s         = int( $duration / $DAY + 0.5 );
        $time_unit = _("days");
    } elsif ( $duration < ( 2 * $MONTH ) ) {
        $s         = int( $duration / $WEEK + 0.5 );
        $time_unit = _("weeks");
    } elsif ( $duration < $YEAR ) {
        $s         = int( $duration / $MONTH + 0.5 );
        $time_unit = _("months");
    } else {
        $s         = int( $duration / $YEAR + 0.5 );
        $time_unit = _("years");
    }

    if ($negative) {
        return _( "%1 %2 ago", $s, $time_unit );
    } else {
        return _( "%1 %2", $s, $time_unit );
    }
}

=head2 age_as_string

Takes nothing. Returns a string that's the differnce between the
time in the object and now.

=cut

sub age_as_string { return $_[0]->diff_as_string }

=head2 as_string

Returns the object's time as a localized string with curent user's prefered
format and timezone.

If the current user didn't choose prefered format then system wide setting is
used or L</default_format> if the latter is not specified. See config option
C<date_time_format>.

=cut

sub as_string {
    my $self = shift;
    my %args = (@_);

    return _("Not set") unless $self->unix > 0;

    my $format = RT->config->get( 'date_time_format', $self->current_user )
        || 'default_format';
    $format = { format => $format } unless ref $format;
    %args = ( %$format, %args );

    return $self->get( timezone => 'user', %args );
}

=head2 get_weekday DAY

Takes an integer day of week and returns a localized string for
that day of week. Valid values are from range 0-6, Note that B<0
is sunday>.

=cut

sub get_weekday {
    my $self = shift;
    my $dow  = shift;

    return _("$DAYS_OF_WEEK[$dow].") if $DAYS_OF_WEEK[$dow];
    return '';
}

=head2 get_month MONTH

Takes an integer month and returns a localized string for that month.
Valid values are from from range 0-11.

=cut

sub get_month {
    my $self = shift;
    my $mon  = shift;

    return _("$MONTHS[$mon].") if $MONTHS[$mon];
    return '';
}

=head2 addseconds SECONDS

Takes a number of seconds and returns the new unix time.

Negative value can be used to substract seconds.

=cut

sub add_seconds {
    my $self = shift;
    my $delta = shift or return $self->unix;

    $self->set( format => 'unix', value => ( $self->unix + $delta ) );

    return ( $self->unix );
}

=head2 add_days [DAYS]

Adds C<24 hours * DAYS> to the current time. Adds one day when
no argument is specified. Negative value can be used to substract
days.

Returns new unix time.

=cut

sub add_days {
    my $self = shift;
    my $days = shift || 1;
    return $self->add_seconds( $days * $DAY );
}

=head2 add_day

Adds 24 hours to the current time. Returns new unix time.

=cut

sub add_day { return $_[0]->add_seconds($DAY) }

=head2 unix [unixtime]

Optionally takes a date in unix seconds since the epoch format.
Returns the number of seconds since the epoch

=cut

sub unix {
    my $self = shift;
    $self->{'time'} = shift if @_;
    return $self->{'time'};
}

=head2 date_time

Alias for L</Get> method. Arguments C<Date> and <Time>
are fixed to true values, other arguments could be used
as described in L</Get>.

=cut

sub date_time {
    my $self = shift;
    return $self->get( @_, date => 1, time => 1 );
}

=head2 date

Takes format argument which allows you choose date formatter.
Pass throught other arguments to the formatter method.

Returns the object's formatted date. Default formatter is iso.

=cut

sub date {
    my $self = shift;
    return $self->get( @_, date => 1, time => 0 );
}

=head2 time


=cut

sub time {
    my $self = shift;
    return $self->get( @_, date => 0, time => 1 );
}

=head2 get

Returnsa a formatted and localized string that represets time of
the current object.


=cut

sub get {
    my $self      = shift;
    my %args      = ( format => 'iso', @_ );
    my $formatter = $args{'format'};
    $formatter = lc($formatter);
    $formatter = 'iso' unless $self->can($formatter);
    return $self->$formatter(%args);
}

=head2 output formatters

Fomatter is a method that returns date and time in different configurable
format.

Each method takes several arguments:

=over 1

=item Date

=item Time

=item timezone - timezone context C<server>, C<user> or C<UTC>

=back

Formatters may also add own arguments to the list, for example
in RFC2822 format day of time in output is optional so it
understand boolean argument C<DayOfTime>.

=head3 default_format

=cut

sub default_format {
    my $self = shift;
    my %args = (
        date     => 1,
        time     => 1,
        timezone => '',
        @_,
    );

    #  0    1    2     3     4    5     6     7      8      9
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $ydaym, $isdst, $offset ) = $self->localtime( $args{'timezone'} );
    $wday = $self->get_weekday($wday);
    $mon  = $self->get_month($mon);
    ( $mday, $hour, $min, $sec ) = map { sprintf "%02d", $_ } ( $mday, $hour, $min, $sec );

    if ( $args{'date'} && !$args{'time'} ) {
        return _( '%1 %2 %3 %4', $wday, $mon, $mday, $year );
    } elsif ( !$args{'date'} && $args{'time'} ) {
        return _( '%1:%2:%3', $hour, $min, $sec );
    } else {
        return _( '%1 %2 %3 %4:%5:%6 %7', $wday, $mon, $mday, $hour, $min, $sec, $year );
    }
}

=head3 iso 

Returns the object's date in iso format C<YYYY-MM-DD mm:hh:ss>.
iso format is locale independant, but adding timezone offset info
is not implemented yet.

Supports arguments: C<timezone>, C<Date>, C<Time> and C<seconds>.
See </Output formatters> for description of arguments.

=cut

sub iso {
    my $self = shift;
    my %args = (
        date     => 1,
        time     => 1,
        timezone => '',
        seconds  => 1,
        @_,
    );

    #  0    1    2     3     4    5     6     7      8      9
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $ydaym, $isdst, $offset ) = $self->localtime( $args{'timezone'} );

    #the month needs incrementing, as gmtime returns 0-11
    $mon++;

    my $res = '';
    $res .= sprintf( "%04d-%02d-%02d", $year, $mon, $mday ) if $args{'date'};
    $res .= sprintf( ' %02d:%02d', $hour, $min ) if $args{'time'};
    $res .= sprintf( ':%02d', $sec, $min )
        if $args{'time'} && $args{'seconds'};
    $res =~ s/^\s+//;

    return $res;
}

=head3 W3CDTF

Returns the object's date and time in W3C date time format
(L<http://www.w3.org/TR/NOTE-datetime>).

Format is locale independand and is close enought to iso, but
note that date part is B<not optional> and output string
has timezone offset mark in C<[+-]hh:mm> format.

Supports arguments: C<timezone>, C<Time> and C<seconds>.
See </Output formatters> for description of arguments.

=cut

sub w3cdtf {
    my $self = shift;
    my %args = (
        time     => 1,
        timezone => '',
        seconds  => 1,
        @_,
        date => 1,
    );

    #  0    1    2     3     4    5     6     7      8      9
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $ydaym, $isdst, $offset ) = $self->localtime( $args{'timezone'} );

    #the month needs incrementing, as gmtime returns 0-11
    $mon++;

    my $res = '';
    $res .= sprintf( "%04d-%02d-%02d", $year, $mon, $mday );
    if ( $args{'time'} ) {
        $res .= sprintf( 'T%02d:%02d', $hour, $min );
        $res .= sprintf( ':%02d', $sec, $min ) if $args{'seconds'};
        if ($offset) {
            $res .= sprintf "%s%02d:%02d", $self->_split_offset($offset);
        } else {
            $res .= 'Z';
        }
    }

    return $res;
}

=head3 RFC2822 (MIME)

Returns the object's date and time in RFC2822 format,
for example C<Sun, 06 Nov 1994 08:49:37 +0000>.
Format is locale independand as required by RFC. Time
part always has timezone offset in digits with sign prefix.

Supports arguments: C<timezone>, C<Date>, C<Time>, C<day_of_week>
and C<seconds>. See </Output formatters> for description of
arguments.

=cut

sub rfc2822 {
    my $self = shift;
    my %args = (
        date        => 1,
        time        => 1,
        timezone    => '',
        day_of_week => 1,
        seconds     => 1,
        @_,
    );

    #  0    1    2     3     4    5     6     7      8     9
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $ydaym, $isdst, $offset ) = $self->localtime( $args{'timezone'} );

    my ( $date, $time ) = ( '', '' );
    $date .= "$DAYS_OF_WEEK[$wday], " if $args{'day_of_week'} && $args{'date'};
    $date .= "$mday $MONTHS[$mon] $year" if $args{'date'};

    if ( $args{'time'} ) {
        $time .= sprintf( "%02d:%02d", $hour, $min );
        $time .= sprintf( ":%02d", $sec ) if $args{'seconds'};
        $time .= sprintf " %s%02d%02d", $self->_split_offset($offset);
    }

    return join ' ', grep $_, ( $date, $time );
}

=head3 RFC2616 (HTTP)

Returns the object's date and time in RFC2616 (HTTP/1.1) format,
for example C<Sun, 06 Nov 1994 08:49:37 GMT>. While the RFC describes
version 1.1 of HTTP, but the same form date can be used in version 1.0.

Format is fixed length, locale independand and always represented in GMT
what makes it quite useless for users, but any date in HTTP transfers
must be presented using this format.

    HTTP-date = rfc1123 | ...
    rfc1123   = wkday "," SP date SP time SP "GMT"
    date      = 2DIGIT SP month SP 4DIGIT
                ; day month year (e.g., 02 Jun 1982)
    time      = 2DIGIT ":" 2DIGIT ":" 2DIGIT
                ; 00:00:00 - 23:59:59
    wkday     = "Mon" | "Tue" | "Wed" | "Thu" | "Fri" | "Sat" | "Sun"
    month     = "Jan" | "Feb" | "Mar" | "Apr" | "May" | "Jun"
              | "Jul" | "Aug" | "Sep" | "Oct" | "Nov" | "Dec"

Supports arguments: C<Date> and C<Time>, but you should use them only for
some personal reasons, RFC2616 doesn't define any optional parts.
See </Output formatters> for description of arguments.

=cut

sub rfc2616 {
    my $self = shift;
    my %args = (
        date => 1,
        time => 1,
        @_,
        timezone    => 'utc',
        seconds     => 1,
        day_of_week => 1,
    );

    my $res = $self->rfc2822(@_);
    $res =~ s/\s*[+-]\d\d\d\d$/ GMT/ if $args{'time'};
    return $res;
}

sub _split_offset {
    my ( $self, $offset ) = @_;
    my $sign = $offset < 0 ? '-' : '+';
    $offset = int( ( abs $offset ) / 60 + 0.001 );
    my $mins  = $offset % 60;
    my $hours = int( $offset / 60 + 0.001 );
    return $sign, $hours, $mins;
}

=head2 timezones handling

=head3 Localtime $context [$time]

Takes one mandatory argument C<$context>, which determines whether
we want "user local", "system" or "UTC" time. Also, takes optional
argument unix C<$time>, default value is the current unix time.

Returns object's date and time in the format provided by perl's
builtin functions C<localtime> and C<gmtime> with two exceptions:

1) "Year" is a four-digit year, rather than "years since 1900"

2) The last element of the array returned is C<offset>, which
represents timezone offset against C<UTC> in seconds.

=cut

sub localtime {
    my $self = shift;
    my $tz   = $self->timezone(shift);

    my $unix = shift || $self->unix;
    $unix = 0 unless $unix >= 0;

    my @local;
    if ( $tz eq 'UTC' ) {
        @local = gmtime($unix);
    } else {
        {
            local $ENV{'TZ'} = $tz;
            ## Using POSIX::tzset fixes a bug where the TZ environment variable
            ## is cached.
            POSIX::tzset();
            @local = CORE::localtime($unix);
        }
        POSIX::tzset();    # return back previouse value
    }
    $local[5] += 1900;     # change year to 4+ digits format
    my $offset = Time::Local::timegm_nocheck(@local) - $unix;
    return @local, $offset;
}

=head3 Timelocal $context @time

Takes argument C<$context>, which determines whether we should
treat C<@time> as "user local", "system" or "UTC" time.

C<@time> is array returned by L<Localtime> functions. Only first
six elements are mandatory - $sec, $min, $hour, $mday, $mon and $year.
You may pass $wday, $yday and $isdst, these are ignored.

If you pass C<$offset> as ninth argument, it's used instead of
C<$context>. It's done such way as code 
C<$self->time_local('utc', $self->localtime('server'))> doesn't
makes much sense and most probably would produce unexpected
result, so the method ignore 'utc' context and uses offset
returned by L<Localtime> method.

=cut

sub time_local {
    my $self = shift;
    my $tz   = shift;
    if ( defined $_[9] ) {
        return timegm( @_[ 0 .. 5 ] ) - $_[9];
    } else {
        $tz = $self->timezone($tz);
        if ( $tz eq 'UTC' ) {
            return Time::Local::timegm( @_[ 0 .. 5 ] );
        } else {
            my $rv;
            {
                local $ENV{'TZ'} = $tz;
                ## Using POSIX::tzset fixes a bug where the TZ environment variable
                ## is cached.
                POSIX::tzset();
                $rv = Time::Local::timelocal( @_[ 0 .. 5 ] );
            };
            POSIX::tzset();    # switch back to previouse value
            return $rv;
        }
    }
}

=head3 timezone $context

Returns the timezone name.

Takes one argument, C<$context> argument which could be C<user>, C<server> or C<utc>.

=over

=item user

Default value is C<user> that mean it returns current user's timezone value.

=item server

If context is C<server> it returns value of the C<timezone> RT config option.

=item  utc

If both server's and user's timezone names are undefined returns 'UTC'.

=back

=cut

sub timezone {
    my $self    = shift;
    my $context = lc(shift);

    $context = 'utc' unless $context =~ /^(?:utc|server|user)$/i;

    my $tz;
    if ( $context eq 'user' ) {
        $tz = $self->current_user->user_object->timezone;
    } elsif ( $context eq 'server' ) {
        $tz = RT->config->get('timezone');
    } else {
        $tz = 'UTC';
    }
    $tz ||= RT->config->get('timezone') || 'UTC';
    $tz = 'UTC' if lc $tz eq 'gmt';
    return $tz;
}

1;

# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2005 Best Practical Solutions, LLC 
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
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
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

=head1 NAME

  RT::Date - a simple Object Oriented date.

=head1 SYNOPSIS

  use RT::Date

=head1 DESCRIPTION

RT Date is a simple Date Object designed to be speedy and easy for RT to use

The fact that it assumes that a time of 0 means "never" is probably a bug.

=begin testing

ok (require RT::Date);

=end testing

=head1 METHODS

=cut


package RT::Date;

use Time::Local;

use strict;
use warnings;
use base qw/RT::Base/;

use vars qw($MINUTE $HOUR $DAY $WEEK $MONTH $YEAR);

$MINUTE = 60;
$HOUR   = 60 * $MINUTE;
$DAY    = 24 * $HOUR;
$WEEK   = 7 * $DAY;
$MONTH  = 4 * $WEEK;
$YEAR   = 365 * $DAY;

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

# {{{ sub new

=head2 new

Object constructor takes one argument C<RT::CurrentUser> object.

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};
    bless ($self, $class);
    $self->CurrentUser(@_);
    $self->Unix(0);
    return $self;
}

# }}}

# {{{ sub Set

=head2 Set

Takes a param hash with the fields 'Format' and 'Value'

if $args->{'Format'} is 'unix', takes the number of seconds since the epoch 

If $args->{'Format'} is ISO, tries to parse an ISO date.

If $args->{'Format'} is 'unknown', require Time::ParseDate and make it figure
things out. This is a heavyweight operation that should never be called from
within RT's core. But it's really useful for something like the textbox date
entry where we let the user do whatever they want.

If $args->{'Value'}  is 0, assumes you mean never.

=begin testing

use_ok(RT::Date);
my $date = RT::Date->new($RT::SystemUser);
$date->Set(Format => 'unix', Value => '0');
ok ($date->ISO eq '1970-01-01 00:00:00', "Set a date to midnight 1/1/1970 GMT");

=end testing

=cut

sub Set {
    my $self = shift;
    my %args = ( Format => 'unix',
                 Value  => time,
                 @_ );

    unless( $args{'Value'} ) {
        $self->Unix(-1);
        return ( $self->Unix() );
    }

    if ( $args{'Format'} =~ /^unix$/i ) {
        $self->Unix( $args{'Value'} );
    }
    elsif ( $args{'Format'} =~ /^(sql|datemanip|iso)$/i ) {
        $args{'Value'} =~ s!/!-!g;

        if (( $args{'Value'} =~ /^(\d{4}?)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)$/ )
            || ( $args{'Value'} =~
                 /^(\d{4}?)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)$/ )
            || ( $args{'Value'} =~
                 /^(\d{4}?)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)\+00$/ )
            || ($args{'Value'} =~ /^(\d{4}?)(\d\d)(\d\d)(\d\d):(\d\d):(\d\d)$/ )
          ) {

            my $year  = $1;
            my $mon   = $2;
            my $mday  = $3;
            my $hours = $4;
            my $min   = $5;
            my $sec   = $6;

            #timegm expects month as 0->11
            $mon--;

            #now that we've parsed it, deal with the case where everything
            #was 0
            return ($self->Unix(-1)) if $mon < 0 || $mon > 11;

            #Dateamnip strings aren't in GMT.
            if ( $args{'Format'} =~ /^datemanip$/i ) {
                $self->Unix(
                      timelocal( $sec, $min, $hours, $mday, $mon, $year ) );
            }

            #ISO and SQL dates are in GMT
            else {
                $self->Unix(
                         timegm( $sec, $min, $hours, $mday, $mon, $year ) );
            }

            $self->Unix(-1) unless $self->Unix;
        }
        else {
            require Carp;
            Carp::cluck;
            $RT::Logger->debug(
                     "Couldn't parse date $args{'Value'} as a $args{'Format'}");

        }
    }
    elsif ( $args{'Format'} =~ /^unknown$/i ) {
        require Time::ParseDate;

        #Convert it to an ISO format string

        my $date = Time::ParseDate::parsedate($args{'Value'},
                        GMT => 0,
                        UK => RT->Config->Get('DateDayBeforeMonth'),
                        PREFER_PAST => RT->Config->Get('AmbiguousDayInPast'),
                        PREFER_FUTURE => !RT->Config->Get('AmbiguousDayInPast') );

        #This date has now been set to a date in the _local_ timezone.
        #since ISO dates are known to be in GMT (for RT's purposes);

        $RT::Logger->debug( "RT::Date used date::parse to make "
                            . $args{'Value'}
                            . " $date\n" );

        return ( $self->Set( Format => 'unix', Value => $date) );
    }
    else {
        die "Unknown Date format: " . $args{'Format'} . "\n";
    }

    return ( $self->Unix() );
}

# }}}

# {{{ sub SetToMidnight 

=head2 SetToMidnight

Sets the date to midnight (at the beginning of the day) GMT
Returns the unixtime at midnight.

=cut

sub SetToMidnight {
    my $self = shift;
    
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) = gmtime($self->Unix);
    $self->Unix(timegm (0,0,0,$mday,$mon,$year,$wday,$yday));
    
    return ($self->Unix);
}


# }}}

# {{{ sub SetToNow
sub SetToNow {
        my $self = shift;
        return($self->Set(Format => 'unix', Value => time))
}
# }}}

# {{{ sub Diff

=head2 Diff

Takes either an RT::Date object or the date in unixtime format as a string

Returns the differnce between $self and that time as a number of seconds

=cut

sub Diff {
    my $self = shift;
    my $other = shift;

    if ( UNIVERSAL::isa( $other, 'RT::Date' ) ) {
        $other=$other->Unix;
    }
    return ($self->Unix - $other);
}
# }}}

# {{{ sub DiffAsString

=head2 DiffAsString

Takes either an RT::Date object or the date in unixtime format as a string

Returns the differnce between $self and that time as a number of seconds as
as string fit for human consumption

=cut

sub DiffAsString {
    my $self = shift;
    my $other = shift;

    if ($other < 1) {
        return ("");
    }
    if ($self->Unix < 1) {
        return("");
    }
    my $diff = $self->Diff($other);

    return ($self->DurationAsString($diff));
}
# }}}

# {{{ sub DurationAsString


=head2 DurationAsString

Takes a number of seconds. returns a string describing that duration

=cut

sub DurationAsString {

    my $self     = shift;
    my $duration = shift;

    my ( $negative, $s );

    $negative = 1 if ( $duration < 0 );

    $duration = abs($duration);

    my $time_unit;
    if ( $duration < $MINUTE ) {
        $s         = $duration;
        $time_unit = $self->loc("sec");
    }
    elsif ( $duration < ( 2 * $HOUR ) ) {
        $s         = int( $duration / $MINUTE );
        $time_unit = $self->loc("min");
    }
    elsif ( $duration < ( 2 * $DAY ) ) {
        $s         = int( $duration / $HOUR );
        $time_unit = $self->loc("hours");
    }
    elsif ( $duration < ( 2 * $WEEK ) ) {
        $s         = int( $duration / $DAY );
        $time_unit = $self->loc("days");
    }
    elsif ( $duration < ( 2 * $MONTH ) ) {
        $s         = int( $duration / $WEEK );
        $time_unit = $self->loc("weeks");
    }
    elsif ( $duration < $YEAR ) {
        $s         = int( $duration / $MONTH );
        $time_unit = $self->loc("months");
    }
    else {
        $s         = int( $duration / $YEAR );
        $time_unit = $self->loc("years");
    }

    if ($negative) {
        return $self->loc( "[_1] [_2] ago", $s, $time_unit );
    }
    else {
        return $self->loc( "[_1] [_2]", $s, $time_unit );
    }
}

# }}}

# {{{ sub AgeAsString

=head2 AgeAsString

Takes nothing

Returns a string that's the differnce between the time in the object and now

=cut

sub AgeAsString {
    my $self = shift;
    return ($self->DiffAsString(time));
}
# }}}

# {{{ sub AsString

=head2 AsString

Returns the object's time as a string with the current timezone.

=cut

sub AsString {
    my $self = shift;
    return $self->loc("Not set") if $self->Unix <= 0;

    my %args = (@_);
    my $format = RT->Config->Get( 'DateTimeFormat', $self->CurrentUser ) || 'DefaultFormat';
    $format = { Format => $format } unless ref $format;
    %args = (%$format, %args);

    return $self->Get( Timezone => 'user', %args );
}

# }}}

# {{{ GetWeekday

=head2 GetWeekday DAY

Takes an integer day of week and returns a localized string for that day of week

=cut

sub GetWeekday {
    my $self = shift;
    my $dow = shift;
    
    return $self->loc("$DAYS_OF_WEEK[$dow].") if $DAYS_OF_WEEK[$dow];
    return '';
}

# }}}

# {{{ GetMonth

=head2 GetMonth DAY

Takes an integer month and returns a localized string for that month 

=cut

sub GetMonth {
    my $self = shift;
    my $mon = shift;

    return $self->loc("$MONTHS[$mon].") if $MONTHS[$mon];
    return '';
}

# }}}

# {{{ sub AddSeconds

=head2 AddSeconds

Takes a number of seconds as a string

Returns the new time

=cut

sub AddSeconds {
    my $self = shift;
    my $delta = shift;
    
    $self->Set(Format => 'unix', Value => ($self->Unix + $delta));
    
    return ($self->Unix);
    

}

# }}}

# {{{ sub AddDays

=head2 AddDays $DAYS

Adds 24 hours * $DAYS to the current time

=cut

sub AddDays {
    my $self = shift;
    my $days = shift;
    $self->AddSeconds($days * $DAY);
    
}

# }}}

# {{{ sub AddDay

=head2 AddDay

Adds 24 hours to the current time

=cut

sub AddDay {
    my $self = shift;
    $self->AddSeconds($DAY);
    
}

# }}}

# {{{ sub Unix

=head2 Unix [unixtime]

Optionally takes a date in unix seconds since the epoch format.
Returns the number of seconds since the epoch

=cut

sub Unix {
    my $self = shift;
    
    $self->{'time'} = (shift || 0) if (@_);
    
    return ($self->{'time'});
}
# }}}

=head2 DateTime

=cut

sub DateTime {
    my $self = shift;
    return $self->Get( @_, Date => 1, Time => 1 );
}

# {{{ sub Date

=head2 Date

Takes Format argument which allows you choose date formatter.
Pass throught other arguments to the formatter method.

Returns the object's formatted date. Default formatter is ISO.

=cut

sub Date {
    my $self = shift;
    return $self->Get( @_, Date => 1, Time => 0 );
}

# }}}}

# {{{ sub Time

=head2 Time

Takes nothing

Returns the object's time in hh:mm:ss format; this is the same as
the ISO format without the date

=cut

sub Time {
    my $self = shift;
    return $self->Get( @_, Date => 0, Time => 1 );
}

# }}}}

sub Get
{
    my $self = shift;
    my %args = (Format => 'ISO',
                @_);
    my $formatter =$args{'Format'};
    $formatter = 'ISO' unless $self->can($formatter);
    return $self->$formatter( %args );
}

=head2 Output formatters

Fomatter is a method that returns date and time in different configurable
format.
Each method takes several arguments:

=over 1

=item Date

=item Time

=item Timezone - Timezone context C<server>, C<user> or C<UTC>

=back

Formatters may also add own arguments to the list, for example
in RFC2822 format day of time in output is optional so it
understand argument C<DayOfTime>.

=head3 DefaultFormat

=cut

sub DefaultFormat
{
    my $self = shift;
    my %args = ( Date => 1,
                 Time => 1,
                 Timezone => '',
                 @_,
               );
    
       #  0    1    2     3     4    5     6     7      8      9
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$ydaym,$isdst,$offset) =
                            $self->Localtime($args{'Timezone'});
    $wday = $self->GetWeekday($wday);
    $mon = $self->GetMonth($mon);
    ($mday, $hour, $min, $sec) = map { sprintf "%02d", $_ } ($mday, $hour, $min, $sec);

    if(!$args{'Date'} && !$args{'Time'}) {
        return '';
    } elsif($args{'Date'} && $args{'Time'}) {
        return $self->loc('[_1] [_2] [_3] [_4]:[_5]:[_6] [_7]',
                          $wday,$mon,$mday,$hour,$min,$sec,$year);
    } elsif($args{'Date'}) {
        return $self->loc('[_1] [_2] [_3] [_4]',
                          $wday,$mon,$mday,$year);
    } else {
        return $self->loc('[_1]:[_2]:[_3]',
                          $hour,$min,$sec);
    }
}

=head3 ISO

Returns the object's date in ISO format
Takes additional argument C<Seconds>.
ISO format has no locale dependant elements so method
ignore argument C<Localize>.

=cut

sub ISO {
    my $self = shift;
    my %args = ( Date => 1,
                 Time => 1,
                 Timezone => 'GMT',
                 Seconds => 1,
                 @_,
               );
       #  0    1    2     3     4    5     6     7      8      9
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$ydaym,$isdst,$offset) = $self->Localtime($args{'Timezone'});

    #the month needs incrementing, as gmtime returns 0-11
    $mon++;
    
    my $res = '';
    $res .= sprintf("%04d-%02d-%02d", $year, $mon, $mday) if $args{'Date'};
    $res .= sprintf(' %02d:%02d', $hour, $min) if $args{'Time'};
    $res .= sprintf(':%02d', $sec, $min) if $args{'Time'} && $args{'Seconds'};
    $res =~ s/^\s+//;
    
    return $res;
}

=head3 W3CDTF

Returns the object's date and time in W3C DTF format

=cut

sub W3CDTF {
    my $self = shift;
    my %args = ( Time => 1,
                 @_,
               );
    my $date = $self->ISO(%args);
    $date .= 'Z' if $args{'Time'};
    $date =~ s/ /T/;
    return $date;
};


=head3 RFC2822

Returns the object's date and time in RFC2822 format

=cut

sub RFC2822 {
    my $self = shift;
    my %args = ( Date => 1,
                 Time => 1,
                 Timezone => '',
                 DayOfWeek => 1,
                 Seconds => 1,
                 @_,
               );

    # XXX: Don't know how to get timezone shift by timezone name
       #  0    1    2     3     4    5     6     7      8     9
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$ydaym,$isdst,$offset) =
                            $self->Localtime($args{'Timezone'});

    my ($date, $time) = ('','');
    $date .= "$DAYS_OF_WEEK[$wday], " if $args{'DayOfWeek'} && $args{'Date'};
    $date .= "$mday $MONTHS[$mon] $year" if $args{'Date'};
    
    $time .= sprintf("%02d:%02d", $hour, $min) if $args{'Time'};
    $time .= sprintf(":%02d", $sec) if $args{'Time'} && $args{'Seconds'};
    if( $args{'Time'} ) {
        my $sign = $offset<0? '-': '+';
        $offset = abs $offset;
        $offset = int($offset/60);
        my $offset_mins = $offset % 60;
        my $offset_hours = int($offset/60);
        $time .= sprintf(" $sign%02d%02d", $offset_hours, $offset_mins);
    }
    
    return join ' ', grep $_, ($date, $time);
}

=head2 Timezones handling

=head3 Localtime $context

Takes one argument C<$context>, which determines whether we want "user local", "system" or "UTC" time.

Returns object's date and time in the format provided by perl's builtin function C<localtime>
with two exceptions:

1) "Year" is a four-digit year, rather than "years since 1900"

2) The last element of the array returned is C<offset>, which represents timezone offset against C<UTC> in seconds.

=cut

sub Localtime
{
    my $self = shift;
    my $tz = $self->Timezone(shift);

    my $unix = $self->Unix;
    $unix = 0 if $unix < 0;
    
    my @local;
    if ($tz eq 'GMT' or $tz eq 'UTC') {
        @local = gmtime($unix);
    } else {
        local $ENV{'TZ'} = $tz;
        @local = localtime($unix);
    }
    $local[5] += 1900; # change year to 4+ digits format
    my $offset = Time::Local::timegm_nocheck(@local) - $unix;
    return @local, $offset;
}


# }}}

# {{{ sub Timezone

=head3 Timezone $context

Returns the timezone name.

Takes one argument, C<$context> argument which could be C<user>, C<server> or C<utc>.

=over 

=item user

Default value is C<user> that mean it returns current user's Timezone value.

=item server

If context is C<server> it returns value of the <$Timezone> RT config option.

=item  utc

If both server's and user's timezone names are undefined returns 'UTC'.

=back


=cut

sub Timezone {
    my $self = shift;
    my $context = lc(shift);




    $context = 'utc' unless $context =~ /^(?:utc|server|user)$/;

    my $tz;

    if( $context eq 'user' ) {
        $tz = $self->CurrentUser->UserObj->Timezone;
    } elsif( $context eq 'server') {
        $tz = RT->Config->Get('Timezone');
    } else {
        $tz = 'UTC';
    }

    return ($tz || RT->Config->Get('Timezone') || 'UTC');
}

# }}}

eval "require RT::Date_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Date_Vendor.pm});
eval "require RT::Date_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Date_Local.pm});

1;

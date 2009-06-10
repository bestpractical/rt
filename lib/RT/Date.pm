# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2009 Best Practical Solutions, LLC 
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
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
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

use RT::Base;

use strict;
use vars qw/@ISA/;
@ISA = qw/RT::Base/;

use vars qw($MINUTE $HOUR $DAY $WEEK $MONTH $YEAR);

$MINUTE = 60;
$HOUR   = 60 * $MINUTE;
$DAY    = 24 * $HOUR;
$WEEK   = 7 * $DAY;
$MONTH  = 4 * $WEEK;
$YEAR   = 365 * $DAY;

# {{{ sub new 

sub new  {
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

=head2 sub Set

takes a param hash with the fields 'Format' and 'Value'

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
    if ( !$args{'Value'}
         || ( ( $args{'Value'} =~ /^\d*$/ ) and ( $args{'Value'} == 0 ) ) ) {
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
            if ( $mon == -1 ) {
                $self->Unix(-1);
            }
            else {

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
        }
        else {
            use Carp;
            Carp::cluck;
            $RT::Logger->debug(
                     "Couldn't parse date $args{'Value'} as a $args{'Format'}");

        }
    }
    elsif ( $args{'Format'} =~ /^unknown$/i ) {
        require Time::ParseDate;

        #Convert it to an ISO format string

	my $date = Time::ParseDate::parsedate($args{'Value'},
			UK => $RT::DateDayBeforeMonth,
			PREFER_PAST => $RT::AmbiguousDayInPast,
			PREFER_FUTURE => !($RT::AmbiguousDayInPast));

        #This date has now been set to a date in the _local_ timezone.
        #since ISO dates are known to be in GMT (for RT's purposes);

        $RT::Logger->debug( "RT::Date used date::parse to make "
                            . $args{'Value'}
                            . " $date\n" );

        return ( $self->Set( Format => 'unix', Value => "$date" ) );
    }
    else {
        die "Unknown Date format: " . $args{'Format'} . "\n";
    }

    return ( $self->Unix() );
}

# }}}

# {{{ sub SetToMidnight 

=head2 SetToMidnight [Timezone => 'utc']

Sets the date to midnight (at the beginning of the day).
Returns the unixtime at midnight.

Arguments:

=over 4

=item Timezone - Timezone context C<server> or C<UTC>

=cut

sub SetToMidnight {
    my $self = shift;
    my %args = ( Timezone => 'UTC', @_ );
    if ( lc $args{'Timezone'} eq 'server' ) {
        $self->Unix( Time::Local::timelocal( 0,0,0,(localtime $self->Unix)[3..7] ) );
    } else {
        $self->Unix( Time::Local::timegm( 0,0,0,(gmtime $self->Unix)[3..7] ) );
    }
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

    if (ref($other) eq 'RT::Date') {
	$other=$other->Unix;
    }
    return ($self->Unix - $other);
}
# }}}

# {{{ sub DiffAsString

=head2 sub DiffAsString

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

=head2 sub AgeAsString

Takes nothing

Returns a string that's the differnce between the time in the object and now

=cut

sub AgeAsString {
    my $self = shift;
    return ($self->DiffAsString(time));
    }
# }}}

# {{{ sub AsString

=head2 sub AsString

Returns the object\'s time as a string with the current timezone.

=cut

sub AsString {
    my $self = shift;
    return ($self->loc("Not set")) if ($self->Unix <= 0);

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($self->Unix);

    return $self->loc("[_1] [_2] [_3] [_4]:[_5]:[_6] [_7]", $self->GetWeekday($wday), $self->GetMonth($mon), map {sprintf "%02d", $_} ($mday, $hour, $min, $sec), ($year+1900));
}
# }}}

# {{{ GetWeekday

=head2 GetWeekday DAY

Takes an integer day of week and returns a localized string for that day of week

=cut

sub GetWeekday {
    my $self = shift;
    my $dow = shift;
    
    return $self->loc('Mon.') if ($dow == 1);
    return $self->loc('Tue.') if ($dow == 2);
    return $self->loc('Wed.') if ($dow == 3);
    return $self->loc('Thu.') if ($dow == 4);
    return $self->loc('Fri.') if ($dow == 5);
    return $self->loc('Sat.') if ($dow == 6);
    return $self->loc('Sun.') if ($dow == 0);
}

# }}}

# {{{ GetMonth

=head2 GetMonth DAY

Takes an integer month and returns a localized string for that month 

=cut

sub GetMonth {
    my $self = shift;
   my $mon = shift;

    # We do this rather than an array so that we don't call localize 12x what we need to
    return $self->loc('Jan.') if ($mon == 0);
    return $self->loc('Feb.') if ($mon == 1);
    return $self->loc('Mar.') if ($mon == 2);
    return $self->loc('Apr.') if ($mon == 3);
    return $self->loc('May.') if ($mon == 4);
    return $self->loc('Jun.') if ($mon == 5);
    return $self->loc('Jul.') if ($mon == 6);
    return $self->loc('Aug.') if ($mon == 7);
    return $self->loc('Sep.') if ($mon == 8);
    return $self->loc('Oct.') if ($mon == 9);
    return $self->loc('Nov.') if ($mon == 10);
    return $self->loc('Dec.') if ($mon == 11);
}

# }}}

# {{{ sub AddSeconds

=head2 sub AddSeconds

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

=head2 sub Unix [unixtime]

Optionally takes a date in unix seconds since the epoch format.
Returns the number of seconds since the epoch

=cut

sub Unix {
    my $self = shift;
    
    $self->{'time'} = shift if (@_);
    
    return ($self->{'time'});
}
# }}}

# {{{ sub ISO

=head2 ISO

Takes nothing

Returns the object's date in ISO format

=cut

sub ISO {
    my $self=shift;
    my    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst, $date) ;
    
    return ('1970-01-01 00:00:00') if ($self->Unix == -1);

    #  0    1    2     3     4    5     6     7     8
    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($self->Unix);
    #make the year YYYY
    $year+=1900;

    #the month needs incrementing, as gmtime returns 0-11
    $mon++;
        
    $date = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year,$mon,$mday, $hour,$min,$sec);
    
    return ($date);
}

# }}}

# {{{ sub Date

=head2 Date

Takes nothing

Returns the object's date in yyyy-mm-dd format; this is the same as
the ISO format without the time

=cut

sub Date {
    my $self = shift;
    my ($date, $time) = split ' ', $self->ISO;
    return $date;
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
    my ($date, $time) = split ' ', $self->ISO;
    return $time;
}

# }}}}

# {{{ sub W3CDTF

=head2 W3CDTF

Takes nothing

Returns the object's date in W3C DTF format

=cut

sub W3CDTF {
    my $self = shift;
    my $date = $self->ISO . 'Z';
    $date =~ s/ /T/;
    return $date;
};

# }}}

# {{{ sub LocalTimezone 

=head2 LocalTimezone

  Returns the current timezone. For now, draws off a system timezone, RT::Timezone. Eventually, this may
pull from a 'Timezone' attribute of the CurrentUser

=cut

sub LocalTimezone {
    my $self = shift;

    return $self->CurrentUser->Timezone
	if $self->CurrentUser and $self->CurrentUser->can('Timezone');

    return ($RT::Timezone);
}

# }}}

eval "require RT::Date_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Date_Vendor.pm});
eval "require RT::Date_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Date_Local.pm});

1;

#$Header$
# (c) 1996-2000 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL
=head1 NAME

  RT::Date - a simple Object Oriented date.

=head1 SYNOPSIS

  use RT::Date

=head1 DESCRIPTION

RT Date is a simple Date Object designed to be speedy and easy for RT to use

The fact that it assumes that a time of 0 means "never" is probably a bug.

=head1 METHODS

=cut


package RT::Date;
use Time::Local;

my $MINUTE = 60;
my $HOUR   = 60 * $MINUTE;
my $DAY    = 24 * $HOUR;
my $WEEK   = 7 * $DAY;
my $MONTH  = 4 * $WEEK;
my $YEAR   = 365 * $DAY;

# {{{ sub new 

sub new  {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  return $self;
}

# }}}

# {{{ sub Set

=head2 sub Set

takes a param hash with the fields 'Format' and 'Value'

if $args->{'Format'} is 'unix', takes the number of seconds since the epoch 

If $args->{'Format'} is ISO, tries to parse an ISO date.

If $args->{'Format'} is 'unknown', require Date::Manip and make it figure things
out. This is a heavyweight operation that should never be called from within 
RT's core. But it's really useful for something like the textbox date entry
where we let the user do whatever they want.

If $args->{'Value'}  is 0, assumes you mean never.


=cut

sub Set {
    my $self = shift;
    my %args = ( Format => 'unix',
		 Value => time,
		 @_);
    if (($args{'Value'} =~ /^\d*$/) and ($args{'Value'} == 0)) {
	$self->Unix(-1);
	return($self->Unix());
    }

    if ($args{'Format'} =~ /^unix$/i) {
	$self->Unix($args{'Value'});
    }
    
    elsif ($args{'Format'} =~ /^(sql|datemanip|iso)$/i) {
	
	if (($args{'Value'} =~ /^(\d{4}?)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)$/) ||
	    ($args{'Value'} =~ /^(\d{4}?)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)$/) ||
	    ($args{'Value'} =~ /^(\d{4}?)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)\+00$/) ||
	    ($args{'Value'} =~ /^(\d{4}?)(\d\d)(\d\d)(\d\d):(\d\d):(\d\d)$/)) {
	    
        my $year = $1;
	    my $mon = $2;
	    my $mday = $3;
	    my $hours = $4;
	    my $min = $5;
	    my $sec = $6;
	    
	    #timegm expects month as 0->11
	    $mon--;
	    
	    #now that we've parsed it, deal with the case where everything
	    #was 0
            if ($mon == -1) {
	            $self->Unix(-1);
	        } else {

		    #Dateamnip strings aren't in GMT.
		    if ($args{'Format'} =~ /^datemanip$/i) {
			$self->Unix(timelocal($sec,$min,$hours,$mday,$mon,$year));
		    }
		    #ISO and SQL dates are in GMT
		    else {
			$self->Unix(timegm($sec,$min,$hours,$mday,$mon,$year));
		    }
		    
		    $self->Unix(-1) unless $self->Unix;
		}
   }  
	else {
	    use Carp;
	    Carp::cluck;
	    $RT::Logger->debug( "Couldn't parse date $args{'Value'} as a $args{'Format'}");
	    
	}
    }
    elsif ($args{'Format'} =~ /^unknown$/i) {
        require Date::Manip;
        #Convert it to an ISO format string 
        
	my $date = Date::Manip::ParseDate($args{'Value'});
        
	#This date has now been set to a date in the _local_ timezone.
	#since ISO dates are known to be in GMT (for RT's purposes);
	
	$RT::Logger->debug("RT::Date used date manip to make ".$args{'Value'} . " $date\n");
        
	
	return ($self->Set( Format => 'datemanip', Value => "$date"));
    }                                                    
    else {
	die "Unknown Date format: ".$args{'Format'}."\n";
    }
    
    return($self->Unix());
}

# }}}

# {{{ sub SetToMidnight 

=head2 SetToMidnight

Sets the date to midnight (at the beginning of the day) GMT
Returns the unixtime at midnight.

=cut

sub SetToMidnight {
    my $self = shift;
    
    use Time::Local;
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


    if ($other == 0) {
	return ("");
    }
    if ($self->Unix == 0) {
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

sub DurationAsString{

    my $self=shift;
    my $duration = shift;
    
    my ($negative, $s);
    
    $negative = 'ago' if ($duration < 0);

    $duration = abs($duration);

    if($duration < $MINUTE) {
	$s=$duration;
	$string="sec";
    } elsif($duration < (2 * $HOUR)) {
	$s = int($duration/$MINUTE);
	$string="min";
    } elsif($duration < (2 * $DAY)) {
	$s = int($duration/$HOUR);
	$string="hours";
    } elsif($duration < (2 * $WEEK)) {
	$s = int($duration/$DAY);
	$string="days";
    } elsif($duration < (2 * $MONTH)) {
	$s = int($duration/$WEEK);
	$string="weeks";
    } elsif($duration < $YEAR) {
	$s = int($duration/$MONTH);
	$string="months";
    } else {
	$s = int($duration/$YEAR);
	$string="years";
    }
    
    return ("$s $string $negative");
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
    return ("Not set") if ($self->Unix <= 0);

    return (scalar(localtime($self->Unix)));
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


# {{{ sub LocalTimezone 
=head2 LocalTimezone

  Returns the current timezone. For now, draws off a system timezone, RT::Timezone. Eventually, this may
pull from a 'Timezone' attribute of the CurrentUser

=cut

sub LocalTimezone {
    my $self = shift;
    
    return ($RT::Timezone);
}

# }}}



1;

#$Header$
# (c) 1996-2000 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL

=head1 RT::Date

RT Date is a simple Date Object designed to be speedy and easy for RT to use

The fact that it assumes that a time of 0 means "never" is probably a bug.
=cut

package RT::Date;
use Time::Local;

my $minute = 60;
my $hour   = 60 * $minute;
my $day    = 24 * $hour;
my $week   = 7 * $day;
my $month  = 4 * $week;
my $year   = 365 * $day;

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

Takes the number of seconds since the epoch as Value if Format is 'unix'
If $args->{'Format'} is ISO, tries to parse an ISO date.

If $args->{'Value'}  is 0, assumes you mean never.


=cut

sub Set {
    my $self = shift;
    my %args = ( Format => 'unix',
		 Value => time,
		 @_);
    if (($args{'Value'} =~ /^\d*$/) and ($args{'Value'} == 0)) {
	$self->{'time'} = 0;
	return($self->Unix());
    }

    if ($args{'Format'} =~ /^unix$/i) {
	$self->{'time'} = $args{'Value'};
    }
    
    elsif ($args{'Format'} =~ /^(sql|datemanip|iso)$/i) {
	
	if (($args{'Value'} =~ /^(\d{4}?)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)$/) ||
	    ($args{'Value'} =~ /^(\d{4}?)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)$/) ||
	    ($args{'Value'} =~ /^(\d{4}?)(\d\d)(\d\d)(\d\d):(\d\d):(\d\d)$/)) {
	    
	    my $year = $1;
	    my $mon = $2;
	    my $mday = $3;
	    my $hours = $4;
	    my $min = $5;
	    my $sec = $6;
	    
	    #timegm expects month as 0->11
	    $mon--;
	    
	    $self->{'time'} = timegm($sec,$min,$hours,$mday,$mon,$year);
	}
	else {
	    $RT::Logger->debug( "Couldn't parse date $args{'Value'} as a $args{'Format'}");
	}
		
    }
    else {
	die "Unknown Date format: ".$args{'Format'}."\n";
    }

    return($self->Unix());
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

    if($duration < $minute) {
	$s=$duration;
	$string="sec";
    } elsif($duration < (2 * $hour)) {
	$s = int($duration/$minute);
	$string="min";
    } elsif($duration < (2 * $day)) {
	$s = int($duration/$hour);
	$string="hours";
    } elsif($duration < (2 * $week)) {
	$s = int($duration/$day);
	$string="days";
    } elsif($duration < (2 * $month)) {
	$s = int($duration/$week);
	$string="weeks";
    } elsif($duration < $year) {
	$s = int($duration/$month);
	$string="months";
    } else {
	$s = int($duration/$year);
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

Takes nothing

Returns the object's time as a string

=cut

*stringify = \&AsString;
*Stringify = \&AsString;


sub AsString {
    my $self = shift;
    return ("Never") if ($self->Unix == -1);
    return ($self->ISO);
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
    
    $self->Set($self->Unix + $delta);
    
    return ($self->Unix);
    

}

# }}}

# {{{ sub Unix

=head2 sub Unix

Takes nothing

Returns the number of seconds since the epoch

=cut

sub Unix {
    my $self = shift;
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
    
    return ('0000-00-00 00:00:00') if ($self->Unix == -1);

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

1;

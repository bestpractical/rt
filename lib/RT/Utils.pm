package RT::Utils;

sub Booleanize {
my ($in_val)=@_;
	if ($in_val) {
	return(1);
	}
	else{
	return(0);
	}
}


#
# quote_content
# will generate the content of a transaction...prefixed.
# TODO: Update this for 1.1
#
sub QuoteContent {
    my $transaction = shift;
    my $current_user = shift;
    my $answer = shift;
    my ($trans, $body, $headers);

    $trans=&rt::transaction_in($transaction,$current_user);

    $body=$rt::req[$serial_num]{'trans'}[$trans]{'content'};

    my $start = "$rt::req[$serial_num]{'trans'}[$trans]{'actor'} wrote ($rt::req[$serial_num]{'trans'}[$trans]{'text_time'}):\n\n";

    if (defined $answer) {
	# Remind the user that he shouldn't quote all the originating message
	$start .= "[REMOVE THIS LINE, AND ANY EXCESSIVE LINES BELOW]\n";
    }
    
    # Do we need any preformatting (wrapping, that is) of the message?

    # What's the longest line like?
    my $max=0;
    
    # Remove trailing headers
    $body =~ s/--- Headers Follow ---\n\n(.*)$//s;

    # Remove quoted signature.
    $body =~ s/\n-- (.*)$//s;
    
    # Locally generated "spam" (why is this in the 1.1 branch?):
    $body =~ s/\n-- param start(.*)$//s;

    foreach (split (/\n/,$body)) {
      $max=length if length>$max;
    }

    if ($max>76) {
        use Text::Wrapper;
	my $wrapper=new Text::Wrapper (
	     columns => 70,
	     body_start => ($max > 150 ? '   ' : ''), 
	     par_start => ''
	     );
	$body=$start . $wrapper->wrap($body);
    }

    $body =~ s/^/> /gm;

    # Lets add the reply
    if (defined $reply) {
      
      # Remind the user that he doesn't blindly send an inappropriate autoanswer
      $body .= ""

    }

    # Let's see if we can figure out the users signature...
    my @entry=getpwnam($current_user);
    my $home=$entry[7];
    for my $trythis ("$rt::rt_dir/etc/templates/signatures/$current_user", "$home/.signature", "$home/pc/sign.txt", "$home/pc/sign") {
	if (-r $trythis) {
	    open(SIGNATURE, "<$trythis"); 
	    my $slash=$/;
	    undef $/;
	    $signature=<SIGNATURE>;
	    close(SIGNATURE);
	    $/=$slash;
	    $body .= "\n\n-- \n$signature";
	    last;
	}
    }

    $max=60 if $max<60;
    $max=70 if $max>78;
    $max+=2;
    return ($body, $max);
}

#
#
#Adapted from ctime.pl
#

sub TimeParse {
    my $time = @_;
    local($[) = 0;
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst);
    @DoW = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat');
    @MoY = ('Jan','Feb','Mar','Apr','May','Jun',
	    'Jul','Aug','Sep','Oct','Nov','Dec');
    # Determine what time zone is in effect.
    # Use GMT if TZ is defined as null, local time if TZ undefined.
    # There's no portable way to find the system default timezone.

    $TZ = defined($ENV{'TZ'}) ? ( $ENV{'TZ'} ? $ENV{'TZ'} : 'GMT' ) : '';
    ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) =
        ($TZ eq 'GMT') ? gmtime($time) : localtime($time);
    
    # Hack to deal with 'PST8PDT' format of TZ
    # Note that this can't deal with all the esoteric forms, but it
    # does recognize the most common: [:]STDoff[DST[off][,rule]]
    
    if($TZ=~/^([^:\d+\-,]{3,})([+-]?\d{1,2}(:\d{1,2}){0,2})([^\d+\-,]{3,})?/){
        $TZ = $isdst ? $4 : $1;
    }
    $TZ .= ' ' unless $TZ eq '';
    if (!$time) {
	$TZ = "NULLTIME";
    }
    $year += 1900;
    return ($DoW[$wday], $MoY[$mon], $mday, $hour, $min, $sec, $TZ, $year);
}
	
#
# Date_diff from req-1.2.7 by Remy Evard (remy@ccs.neu.edu)
# Hacked by jesse vincent to deal with negative time
#	
sub DateDiff {

    local($old, $new) = @_;
    local($diff, $minute, $hour, $day, $week, $month, $year, $s, $string, $negative="");


    $diff = $new - $old;
    if ($diff < 0) {
	$negative = "-";
	$diff = $old - $new;
    }

    $minute = 60;
    $hour   = 60 * $minute;
    $day    = 24 * $hour;
    $week   = 7 * $day;
    $month  = 4 * $week;
    $year   = 365 * $day;
    
    if($diff < $minute) {
	$s=$diff;
	$string="sec";
    } elsif($diff < (2 * $hour)) {
	$s = int($diff/$minute);
	$string="min";
    } elsif($diff < (2 * $day)) {
	$s = int($diff/$hour);
	$string="hr";
    } elsif($diff < (2 * $week)) {
	$s = int($diff/$day);
	$string="day";
    } elsif($diff < (2 * $month)) {
	$s = int($diff/$week);
	$string="wk";
    } elsif($diff < $year) {
	$s = int($diff/$month);
	$string="mth";
    } else {
	$s = int($diff/$year);
	$string="yr";
    }
    return "$negative$s $string";
}


sub TemplateLoad {
    
    local ($in_template, $in_queue) =@_;
    local ($template_content="");
    
    
    if (! (-f "$rt::template_dir/queues/$in_queue/$in_template")) 
    {
       	return ("The specified template is missing or inaccessable.\n ($rt::template_dir/queues/$in_queue/$in_template)\n However, the custom content which was supposed to fill the template was:\n %content% ");
    }
    open(CONTENT, "$rt::template_dir/queues/$in_queue/$in_template"); 
    while (<CONTENT>)
    {
	$template_content .= $_;
    }
    close (CONTENT);
    return ($template_content);
}



sub DateParse {
    my ($date_string) = shift;

    my ($now_wday, $now_mon, $now_mday, $now_hour, $now_min, $now_sec, $now_TZ, $now_year, $time);   
    use Time::Local;
    
    
    ($now_wday, $now_mon, $now_mday, $now_hour, $now_min, $now_sec, $now_TZ, $now_year)=RT::Utils::TimeParse(time);  

    #print "$date_string is the date string\n";
    
    if ($date_string =~ /(\d*)\/(\d*)\/(\d*)/) {
	$month = $1;
	$day = $2;
	$year = $3;
    }

    elsif ($date_string =~ /^(.?)\/(.?)$/) {
	$month = $1;
	$day = $2;
	#FIXME THIS IS NOT THE RIGHT WAY TO DO THIS. IT ONLY WORKS FOR DATES IN
	# THE CURRENT YEAR
	$year = $now_year;
      }
    
    elsif ($date_string =~ /^(...), (\d?) (...) (\d?) (\d?):(\d?):(\d?) (\W*)/) {
      $monthword = $3;
      $month = &GetMonth($monthword);
      
      $day = $2;
      $year = $4;
      $hour = $5;
      $min = $6;
      $sec = $7;
      $tz = $8;
    }
    
    if ($year == -1) {
      $year = $now_year;
    }
    if (($year > 70) and ($year < 100))  {
      $year += 1900;
    }
    elsif ($year < 100) {
      $year += 2000;
    }
    
    #print "$time: $hours:$sec:$min $month\/$day\/$year\n";

    # timelocal) expects the same kind of values that localtime() generates,
    # i.e. $month ranges from 0-11 and $year is the real year - 1900.
    $time = timelocal($sec, $min, $hours, $day, $month - 1, $year - 1900);

    #print "$time: $hours:$sec:$min $month\/$day\/$year\n";
    
    return ($time);

}

sub GetMonth {
  #TODO There must be a module for this
  my ($monthword) = shift;
  if ($monthword =~ /jan/i) {
    return(1);
  }
  elsif ($monthword =~ /feb/i) {
    return(2);
    }   
  elsif ($monthword =~ /mar/i) {
    return(3);
  }    
  elsif ($monthword =~ /apr/i) {
    return(4);
  }    
  elsif ($monthword =~ /may/i) {
    return(5);
  }    
  elsif ($monthword =~ /jun/i) {
    return(6);
  }    
  elsif ($monthword =~ /jul/i) {
    return(7);
  }     
  elsif ($monthword =~ /aug/i) {
    return(8);
  }    
  elsif ($monthword =~ /sep/i) {
    return(9);
  }    
  elsif ($monthword =~ /oct/i) {
    return(10);
  }    
  elsif ($monthword =~ /nov/i) {
    return(11);
  }   
  elsif ($monthword =~ /dec/i) {
    return(12);
  }
  else {
    return (-1);
  }
  
  
}


1;
 

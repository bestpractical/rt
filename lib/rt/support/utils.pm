package rt;


sub untaint {
	my $data = shift;
   if ($data =~ /^([-\@\w.]+)$/) {
               $data = $1;                     # $data now untainted
           } else {
               die "Bad data in $data";        # log this somewhere
           }
	return ($data);
}

#
#can the named user modify the named queue
sub can_manipulate_request{
    my ($in_serial_num, $in_user) =@_;
    &req_in($in_serial_num,$in_user);
    if (&can_manipulate_queue($rt::req[$in_serial_num]{queue_id},$in_user)) {
	return(1);
    }
    else {
	return(0);
    }
}
sub can_create_request{
    my $in_queue = shift;
    my $in_user = shift;
  
    if ($queues{$in_queue}{'acls'}{$in_user}{'manipulate'}) {
	return(1);
}
    if ($queues{$in_queue}{'allow_user_create'}) {
	return(2);
    }

    else {
	return(0);
    }
}

sub can_manipulate_queue {
    my ($in_queue, $in_user) =@_;

    if ($queues{$in_queue}{acls}{$in_user}{manipulate}) {
	return(1);
    }
	elsif ($users{$in_user}{admin_rt}) {
	return (2);
    }

    else {
	return(0);
    }
}

sub can_display_queue {
    my ($in_queue, $in_user) =@_;
    if ($queues{$in_queue}{acls}{$in_user}{display}) {
	return(1);
    }
    elsif ($users{$in_user}{admin_rt}) {
	return (2);
    }

    else {
	return(0);
    }
}

sub can_admin_queue {
    my ($in_queue, $in_user) =@_;
    if ($queues{$in_queue}{acls}{$in_user}{admin}) {
	return(1);
    }
    elsif ($users{$in_user}{admin_rt}) {
	return (2);
    }

    else {
	return(0);
    }
}
sub is_not_a_requestor{
    my($address,$serial_num) =@_;
    if ($req[$serial_num]{'requestors'} =~ /(^|\s|,)$address(,|\s|\b)/i) {
	return(0);
    }
    else {
	return(1);
    }
    
}
sub is_owner{
    my($serial_num,$user) =@_;
    if ($req[$serial_num]{'owner'} eq $user) {
	return(1);
    }
    else {
	return(0);
    }
    
}


#normalize_sn takes care of opersations on reqs which have been merged
sub normalize_sn{
    my ($in_serial_num)=@_;
    my ($effective_sn);
    $effective_sn=&get_effective_sn($in_serial_num);
    $effective_sn=int($effective_sn);
    return($effective_sn);
}

#
# return something's boolean value
#

sub booleanize {
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
#
sub quote_content {
    my $transaction = shift;
    my $current_user = shift;
    my ($trans, $quoted_content, $body, $headers);
    $trans=&rt::transaction_in($transaction,$current_user);
    ((($body,$headers) =  split (/--- Headers Follow ---\n\n/, $rt::req[$serial_num]{'trans'}[$trans]{'content'},2))) or 
	(($headers, $body) = split ('\n\n',$lines)) or
	    $body = $lines;
    $quoted_content = "$rt::req[$serial_num]{'trans'}[$trans]{'actor'} wrote ($rt::req[$serial_num]{'trans'}[$trans]{'text_time'}):\n\n";
    
    $quoted_content .= &rt::prefix_string("> ",$body);
    return ($quoted_content);
}

#
# prefix_string quotes a message
#
sub prefix_string {
    
    my $prefix = shift;
    my $text = shift;
    my ($line, $newtext);
    foreach $line (split (/\n/,$text)) {
	$newtext .= $prefix . $line . "\n";
    }
    
    return ($newtext)
    }



#
#
#Adapted from ctime.pl
#

sub parse_time {
    local($time) = @_;
    local($[) = 0;
    local($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst);
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
sub date_diff {

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
    $year   = 356 * $day;
    
    if($diff < $minute) {
	$s=$diff;
	$string="sec";
    } elsif($diff < $hour) {
	$s = int($diff/$minute);
	$string="min";
    } elsif($diff < $day) {
	$s = int($diff/$hour);
	$string="hr";
    } elsif($diff < $week) {
	$s = int($diff/$day);
	$string="day";
    } elsif($diff < $month) {
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


sub template_read {
    
    local ($in_template, $in_queue) =@_;
    local ($template_content="");
    
    
    if (! (-f "$rt::template_dir/queues/$in_queue/$in_template")) 
    {
       	return ("The specified template is missing or inaccessable.\n ($rt::template_dir/queues/$in_queue/$in_template)\n However, the custom content which was supposed to fill the template was:\n %content%");
    }
    open(CONTENT, "$rt::template_dir/queues/$in_queue/$in_template"); 
    while (<CONTENT>)
    {
	$template_content .= $_;
    }
    close (CONTENT);
    return ($template_content);
}



sub date_parse {
    my ($date_string) = shift;

    my ($now_wday, $now_mon, $now_mday, $now_hour, $now_min, $now_sec, $now_TZ, $now_year, $time);   
    use Time::Local;
    
    
    ($now_wday, $now_mon, $now_mday, $now_hour, $now_min, $now_sec, $now_TZ, $now_year)=&rt::parse_time($rt::time);  

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
	$month = &getmonth($monthword);

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

    $time = timelocal($sec, $min, $hours, $day, $month, $year);

    #print "$time: $hours:$sec:$min $month\/$day\/$year\n";
    
    return ($time);

}

sub getmonth {
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

# make sure we're using full e-mail addresses rather than username w/o
# the domain part
sub norm_requestors
{
my $reqs = shift;
my %nreqs;
my $err = "ERROR: Incorrect requestor(s): '$reqs'";

   $reqs =~ s/\s//g;
#i think we should allow empty requestors
#   return ('',$err) if ! $reqs;
   @l = split(/,/,$reqs);
   for( @l )
   {
	$_ .= "\@$rt::domain" if ! /\@/;
	$nreqs{$_} = 1;
   }
   $res = join(",",sort keys %nreqs);
#   return ('',$err) if ! $res;
   return ($res,'');
}

1;
 

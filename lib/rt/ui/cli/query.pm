# $Header$
package rt::ui::cli::query;


sub activate {
($current_user,$tmp)=getpwuid($<);
($value, $message)=&rt::initialize($current_user);
if ($value == 0) {
    print "$message\n";
    exit(0);
} 
else {
    print "$message\n";
}
$criteria=&build_query();
$count=&rt::get_queue($criteria,$current_user);
if (!$format_string) {
    $format_string = "%n%p%o%g%l%t%r%s";
}
&print_header($format_string);
for ($temp=0;$temp<$count;$temp++)
{
    #do this because we're redefining the format string internally each run.
    my ($format_string) = $format_string;

    while ($format_string) {
	($field, $format_string) = split (/\%/, $format_string,2);  

	if  ($field =~ /^n(\d*)$/){ 
	    $length = $1;
		if ($length < 1) {$length=6;}
	    printf "%-${length}.${length}s ", $rt::req[$temp]{'serial_num'};
	}
	elsif ($field =~ /^p(\d*)$/){ 
	    $length = $1;
		if ($length < 1) {$length=2;}
	    printf "%-${length}.${length}d ", $rt::req[$temp]{'priority'};
	}
	elsif ($field =~ /^r(\d*)$/){ 
	    $length = $1;
		if ($length < 1) {$length=9;}
	    printf "%-${length}.${length}s ", $rt::req[$temp]{'requestors'};
	}
	elsif ($field =~ /^o(\d*)$/){ 
	    $length = $1;
		if ($length < 1) {$length=8;}
	    printf "%-${length}.${length}s ", $rt::req[$temp]{'owner'};
	}

	elsif ($field =~ /^s(\d*)$/){ 
	    $length = $1;
		if ($length < 1) {$length=30;}
	    printf "%-${length}.${length}s ", $rt::req[$temp]{'subject'};
	}
	elsif ($field =~ /^t(\d*)$/){ 
	    $length = $1;
		if ($length < 1) {$length=5;}
	    printf "%-${length}.${length}s ", $rt::req[$temp]{'status'};
	}
	elsif ($field =~ /^q(\d*)$/){ 
	    $length = $1;
		if ($length < 1) {$length=8;}
	    printf "%-${length}.${length}s ", $rt::req[$temp]{'queue_id'};
	}
	elsif ($field =~ /^a(\d*)$/){ 
	    $length = $1;
		if ($length < 1) {$length=7;}
	    printf "%-${length}.${length}s ", $rt::req[$temp]{'area'};
	}
	elsif ($field =~ /^g(\d*)$/){ 
	    $length = $1;
		if ($length < 1) {$length=6;}
	    printf "%-${length}.${length}s ", $rt::req[$temp]{'age'};
	}
	elsif ($field =~ /^l(\d*)$/){ 
	    $length = $1;
		if ($length < 1) {$length=6;}
	    printf "%-${length}.${length}s ", $rt::req[$temp]{'since_told'};
	}
	elsif ($field =~ /^w(.)$/) {
	    if ($1 eq 't') { print "\t";}
	    if ($1 eq 's') { print " ";}
	    if ($1 eq 'n') {print "\n";}
	}
	else {
	    print $field;
	}
    }
    print "\n";
}
}
sub build_query {
    local ($owner_ops, $user_ops, $status_ops, $prio_ops, $order_ops, $reverse);
    if (($ARGV[0] eq '-help')  or ($ARGV[0] eq '--help') or ($ARGV[0] eq '-h')) {
     &usage();
     exit(0);
    }
    if (&rt::is_a_queue($ARGV[0])){
	$queue_ops = "queue_id = \'$ARGV[0]\'";
    }

    for ($i=0;$i<=$#ARGV;$i++) {
	if ($ARGV[$i] eq '-format') {
	    $format_string = $ARGV[++$i];
	
	}

	if ($ARGV[$i] eq '-owner') {
	    if ($owner_ops){
		   $owner_ops .= " OR ";
	       }
	       $owner_ops .= " owner = \'" . $ARGV[++$i] . "\'";
	   }
	   
	   if ($ARGV[$i] eq '-unowned'){
	       if ($owner_ops){
		   $owner_ops .= " OR ";
	       }
	       $owner_ops .= " owner =  \'\'" ;
	   }
	   if ($ARGV[$i] eq '-priority'){
	       if ($prio_ops){
		   $prio_ops .= " AND ";
	       }
	       $prio_ops .= " prio $ARGV[++$i] $ARGV[++$i]";
	   }
	   
	   if ($ARGV[$i] eq '-status'){
	       if ($status_ops){
		   $status_ops .= " OR ";
	       }
	       $status_ops .= " status =  \'$ARGV[++$i]\'" ;
	   }
	   if ($ARGV[$i] eq '-open'){
	       if ($status_ops){
		   $status_ops .= " OR ";
	       }
	       $status_ops .= " status =  \'open\'" ;
	   }
	   if (($ARGV[$i] eq '-resolved') or ($ARGV[$i] eq '-closed')){
	       if ($status_ops){
		   $status_ops .= " OR ";
	       }
	       $status_ops .= " status =  \'resolved\'" ;
	   }
	   if ($ARGV[$i] eq '-dead'){
	       if ($status_ops){
		   $status_ops .= " OR ";
	       }
	       $status_ops .= " status =  \'dead\'" ;
	   }    
	   
	   if ($ARGV[$i] eq '-stalled'){
	       if ($status_ops){
		   $status_ops .= " OR ";
	       }
	       $status_ops .= " status =  \'stalled\'" ;
	   }
	   
	   if ($ARGV[$i] eq '-user') {
	       if ($user_ops){
		   $user_ops .= " OR ";
	       }
	       $user_ops .= " requestors like \'%" . $ARGV[++$i] . "%\' ";
	   }
	   
	   if ($ARGV[$i] eq '-orderby') {
	       if ($order_ops){
		   $order_ops .= ", ";
	       }
	       $order_ops .= $ARGV[++$i]; 
	   }
	   if ($ARGV[$i] eq '-r') {
	       $reverse = ' DESC'; 
	   }

	   if ($ARGV[$i] eq '-t') {       
	       if ($order_ops){
		   $order_ops .= ", ";
	       }
	       $order_ops .= "date_acted"; 
	   }
    }    
    
    if ($queue_ops) {
	if ($query_string) {$query_string .= " AND ";}
	$query_string .= "$queue_ops";
    }
    
    if ($prio_ops) {
	if ($query_string) {$query_string .= " AND ";}
	$query_string .= "$prio_ops";
    }
    
    if ($status_ops) {
	if ($query_string) {$query_string .= " AND ";}
	$query_string .= "$status_ops";
    }
    
    if ($user_ops) {
	if ($query_string) {$query_string .= " AND ";}
	$query_string .= "$user_ops";
    }
    if ($owner_ops) {
	if ($query_string) {$query_string .= " AND ";}
	$query_string .= "$owner_ops";
    }
    if (!$query_string) {
	$query_string = "status = \'open\'";
    }
    if ($order_ops) {
	$query_string .= "ORDER BY $order_ops";
    }
    else {
	$query_string .= "ORDER BY serial_num";
    }
    if ($reverse) {
	$query_string .= " DESC";
    }
    
    return ($query_string);
}
sub usage {
print"
       usage: rtq <queue> <options>
       Where <options> are almost any combination of:
           -r                list requests in reverse order
           -t                list most recently modified requests first
    
           -prio <op> <prio> list requests which have a <prio> satisfying <op>
                             op may be one of = < > <= >= <>
           -owner    <user>  prints all requests owned by <user>
           -unowned          prints only the un-taken requests
           -user <user>      prints all requests made by <user>
           -open             prints only the open requests
           -resolved         prints resolved requests
           -stalled          prints stalled requests
           -dead             prints killed requests
           -orderby <crit>   Sorts requests by <crit>  (one of serial_num, 
                             queue_id, requestors, owner, subject, priority, 
                             status, date_created, date_due
           -format <format> allows you to specify the output of rtq.
                             <format> is a string of the form %xn%xn%xn.  
                             x is any of the commands associated below.  
                             n is an integer which corresponds to the 
                             number of spaces you'd like the output of x 
                             to take up.  <format>'s default value is 
                             \"%n%p%o%g%l%t%r%s\". Valid values of x are:
                             n[6]      serial number
                             p[2]      priority
                             r[9]      requestors
                             o[8]      owner
                             s[30]     subject
                             t[5]      status
                             a[7]      area
                             q[8]      queue
                             g[5]      age
                             l[6]      time since last correspondence
                             wt        tab
                             ws        space
                             wn        newline
";

    #          <num>-<num>      print only requests in the number range\n
    #          <num>            print only request <num>\n";
    #          :<num>           print a total of <num> requests\n";
    
print "                     Without options, rtq prints all open requests.
";
}


sub print_header {
    my($format_string) =@_;
    my ($field, $length,$total_length);
    while ($format_string) {
	($field, $format_string) = split (/%/, $format_string,2);  
	
	if ($field =~ /^n(\d*)$/){ 
	    $length = $1;
		if ($length < 1) {$length=6;}
	    $total_length = $total_length + $length;
	    printf "%-${length}.${length}s ", "Num";
	}
	elsif ($field =~ /^p(\d*)$/){ 
	    $length = $1;
		if ($length < 1) {$length=2;}
	    $total_length = $total_length + $length;
	    printf "%-${length}.${length}s ", "!";
	}
	elsif ($field =~ /^r(\d*)$/){ 
	    $length = $1;
		if ($length < 1) {$length=9;}
	    $total_length = $total_length + $length;
	    printf "%-${length}.${length}s ", "Requestor";
	}
	elsif ($field =~ /^o(\d*)$/){ 
	    $length = $1;
		if ($length < 1) {$length=8;}
	    $total_length = $total_length + $length;
	    printf "%-${length}.${length}s ", "Owner";
	}

	elsif ($field =~ /^s(\d*)$/){ 
	    $length = $1;
		if ($length < 1) {$length=20;}
	    $total_length = $total_length + $length;
	    printf "%-${length}.${length}s ", "Subject";
	}
	elsif ($field =~ /^t(\d*)$/){ 
	    $length = $1;
		if ($length < 1) {$length=5;}
	    $total_length = $total_length + $length;
	    printf "%-${length}.${length}s ", "State";
	}

	elsif ($field =~ /^q(\d*)$/){ 
	    $length = $1;
		if ($length < 1) {$length=8;}
	    $total_length = $total_length + $length;
	    printf "%-${length}.${length}s ", "Queue";
	}
	elsif ($field =~ /^a(\d*)$/){ 
	    $length = $1;
		if ($length < 1) {$length=7;}
	    $total_length = $total_length + $length;
	    printf "%-${length}.${length}s ", "Area";
	}
	elsif ($field =~ /^g(\d*)$/){ 
	    $length = $1;
		if ($length < 1) {$length=6;}
	    $total_length = $total_length + $length;
	    printf "%-${length}.${length}s ", "Age";
	}
	elsif ($field =~ /^l(\d*)$/){ 
	    $length = $1;
		if ($length < 1) {$length=6;}
	    $total_length = $total_length + $length;
	    printf "%-${length}.${length}s ", "Told";
	}
	elsif ($field =~ /^w(.)$/) {
	    if ($1 eq 't') { print "\t";}
	    if ($1 eq 's') { print " ";}
	    if ($1 eq 'n') {print "\n";}
	}
	else {
	    print $field;
	}

    }
    print "\n";
    for ($temp=0;$temp<$total_length;$temp++){
	print "-";
    }
    print "\n";
}


1;

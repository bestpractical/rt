# $Header$
# (c) 1996-1999 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL
#

  {
    package rt::ui::cli::query;
    
    sub activate {
      
      ($current_user,$tmp)=getpwuid($<);
      $CurrentUser = new RT::User($current_user);
      $CurrentUser->load($current_user);
      
      &parse_args;
    }
    
    
    $criteria=&build_query();
    $count=&rt::get_queue($criteria,$CurrentUser->UserId);
    if (!$format_string) {
      $format_string = "%n%p%o%g%l%t%r%s";
    }
    
    &print_header($format_string);
    
    while ($Request = $Query->Next) {
      #do this because we're redefining the format string internally each run.
      my ($format_string) = $format_string;
      
      while ($format_string) {
	($field, $format_string) = split (/\%/, $format_string,2);  
	
	if  ($field =~ /^n(\d*)$/){ 
	  $length = $1;
	  if ($length < 1) {$length=6;}
	  printf "%-${length}.${length}s ", $Request->Id;
	}
	elsif ($field =~ /^d(\d*)$/){
	  my $length = $1;
	  if ($Request->DateDue > 0) {
	    my $date = localtime($Request->DateDue);
	    $date =~ s/\d*:\d*:\d*//;	
	    if ($length < 1) {$length=5;}
            printf "%-${length}.${length}s ", $date;
	  }
	  else {
	    printf  "%-${length}.${length}s ", "none";
	  }
        }
	elsif ($field =~ /^p(\d*)$/){ 
	  $length = $1;
	  if ($length < 1) {$length=2;}
	  printf "%-${length}.${length}d ", $Request->Priority;
	}
	elsif ($field =~ /^r(\d*)$/){ 
	  $length = $1;
	  if ($length < 1) {$length=9;}
	  printf "%-${length}.${length}s ", $Request->Requestors;
	}
	elsif ($field =~ /^o(\d*)$/){ 
	  $length = $1;
	  if ($length < 1) {$length=8;}
	  printf "%-${length}.${length}s ", $Request->Owner;
	}
	
	elsif ($field =~ /^s(\d*)$/){ 
	  $length = $1;
	  if ($length < 1) {$length=30;}
	  printf "%-${length}.${length}s ", $Request->Subject;
	}
	elsif ($field =~ /^t(\d*)$/){ 
	  $length = $1;
	  if ($length < 1) {$length=5;}
	  printf "%-${length}.${length}s ", $Request->Status;
	}
	elsif ($field =~ /^q(\d*)$/){ 
	  $length = $1;
	  if ($length < 1) {$length=8;}
	  printf "%-${length}.${length}s ", $Request->Queue->Id;
	}
	elsif ($field =~ /^a(\d*)$/){ 
	  $length = $1;
	  if ($length < 1) {$length=7;}
	  printf "%-${length}.${length}s ", $Request->Area;
	}
	elsif ($field =~ /^g(\d*)$/){ 
	  $length = $1;
	  if ($length < 1) {$length=6;}
	  printf "%-${length}.${length}s ", $Request->Age;
	}
	elsif ($field =~ /^l(\d*)$/){ 
	  $length = $1;
	  if ($length < 1) {$length=6;}
	  printf "%-${length}.${length}s ", $Request->SinceTold;
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
    
    my $Requests = RT::Tickets->new($CurrentUser);
    
    if (&rt::is_a_queue($ARGV[0])){
      $queue_ops = "queue_id = \'$ARGV[0]\'";
    }
    
    for ($i=0;$i<=$#ARGV;$i++) {
      if ($ARGV[$i] eq '-format') {
	$format_string = $ARGV[++$i];
	
      }
      
      if ($ARGV[$i] eq '-queue') {
	my $queue_id = $ARGV[++$i];
	$Requests->Limit( FIELD => 'queue',
			  VALUE => "$queue_id");
	  

      }

      if ($ARGV[$i] eq '-owner') {
	my $owner = $ARGV[++$i];
	$Requests->Limit( FIELD => 'owner',
			  VALUE => "$owner");
	
      }
      
      if ($ARGV[$i] eq '-unowned'){
	$Requests->Limit( FIELD => 'owner',
			  VALUE => "");

      }
      if ($ARGV[$i] =~ '-prio'){
	my $operator = $ARGV[++$i];
	my $priority = $ARGV[++$i];
	$Requests->Limit( FIELD => 'priority',
			  OPERATOR => "$operator",
			  VALUE => "$priority");

	$prio_ops .= " priority $ARGV[++$i] $ARGV[++$i] ";
      }
      
      if ($ARGV[$i] =~ '-stat'){
	my $status = $ARGV[++$i];
	$Requests->Limit( FIELD => 'status',
			  VALUE => "$status");
      }
      
      if ($ARGV[$i] eq '-area'){
	my $area = $ARGV[++$i];
	$Requests->Limit( FIELD => 'area',
			  VALUE => "$area");
      }
      
      if ($ARGV[$i] eq '-open'){
	$Requests->Limit( FIELD => 'status',
			  VALUE => "open");
      }
      if (($ARGV[$i] eq '-resolved') or ($ARGV[$i] eq '-closed')){
	$Requests->Limit( FIELD => 'status',
			  VALUE => "resolved");

	
      }
      if ($ARGV[$i] eq '-dead'){
	$Requests->Limit( FIELD => 'status',
			  VALUE => "dead");
	
      }    
      
      if ($ARGV[$i] eq '-stalled'){
	$Requests->Limit( FIELD => 'status',
			  VALUE => "stalled");
      }
      
      if ($ARGV[$i] eq '-user') {
	my $requestors = $ARGV[++$i];
	$Requests->Limit( FIELD => 'requestors',
			  VALUE => "%$requestors%",
			  OPERATOR => 'LIKE');
      }
      

      
      #TODO: DEAL WITH ORDERING 
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
    

    #DEAL WITH DEFAULTS

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
    print <<EOFORM;
    
       usage: rtq <queue> <options>
       Where <options> are almost any combination of:
           -r                list requests in reverse order
           -t                list most recently modified requests first
    
           -prio <op> <prio> list requests which have a <prio> satisfying <op>
                             op may be one of = < > <= >= <>
           -owner    <user>  lists all requests owned by <user>
           -unowned          lists unowned requests
           -user <user>      lists all requests made by <user>
           -open             lists only the open requests
           -resolved         lists resolved requests
           -stalled          lists stalled requests
           -dead             lists killed requests
	   -area <area>	     lists requests in the area <area>
           -orderby <crit>   Sorts requests by <crit>  (one of serial_num, 
                             queue_id, requestors, owner, subject, priority, 
                             status, date_created, date_due, area)
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
			     d[10]     due date
                             s[30]     subject
                             t[5]      status
                             a[7]      area
                             q[8]      queue
                             g[5]      age
                             l[6]      time since last correspondence
                             wt        tab
                             ws        space
                             wn        newline


    #          <num>-<num>      print only requests in the number range\n
    #          <num>            print only request <num>\n";
    #          :<num>           print a total of <num> requests\n";
    
                     Without options, rtq lists all open requests.
EOFORM



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
        elsif ($field =~ /^d(\d*)$/){
            $length = $1;
                if ($length < 1) {$length=5;}
            $total_length = $total_length + $length;
            printf "%-${length}.${length}s ", "Due";
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
}
1;

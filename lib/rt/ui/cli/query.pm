# $Header$
# (c) 1996-2000 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL
#

 package rt::ui::cli::query;
 
# {{{ sub activate 
sub activate  {
 &GetCurrentUser;
 &ParseArgs();
 return(0);
}
# }}}

# {{{ sub ParseArgs 

sub ParseArgs  {

  
  my $Tickets=&build_query();
  if (!$Tickets) {
    print "No result found\n";
    return
  }
  
  if (!$format_string) {
    $format_string = "%n%p%o%g%l%t%r%s";
  }
  
  &print_header($format_string);
  print $Tickets->Restrictions();
  while (my $Ticket = $Tickets->Next) {
    &PrintRow($Ticket, $format_string);
  }
}

# }}}


# {{{ sub PrintRow

sub PrintRow {
  my $Ticket = shift;
  my $format_string = shift;
  while ($format_string) {
    ($field, $format_string) = split (/\%/, $format_string,2);  
    
    if  ($field =~ /^n(\d*)$/){ 
      $length = $1;
      if (!$length) {$length=6;}
      printf "%-${length}.${length}s ", $Ticket->Id;
    }
    elsif ($field =~ /^d(\d*)$/){
      my $length = $1;
      if ($Ticket->DateDue > 0) {
	my $date = localtime($Ticket->DateDue);
	$date =~ s/\d*:\d*:\d*//;	
	if (!$length) {$length=5;}
	printf "%-${length}.${length}s ", $date;
      }
      else {
	printf  "%-${length}.${length}s ", "none";
      }
    }
    elsif ($field =~ /^p(\d*)$/){ 
      $length = $1; 
      if (!$length) {$length=2;}
      
      printf "%-${length}.${length}d ", $Ticket->Priority;
    }
    elsif ($field =~ /^r(\d*)$/){ 
      $length = $1;
      if (!$length) {$length=9;}
      printf "%-${length}.${length}s ", $Ticket->RequestorsAsString;}
    elsif ($field =~ /^o(\d*)$/){ 
      $length = $1;
      my $Owner;
      if (!$length) {$length=8;}
      if ($Ticket->Owner) {
	$Owner = $Ticket->Owner->UserId;
      }
      else {
	$Owner = "";
      }
      printf "%-${length}.${length}s ", $Owner;
    }
    
    elsif ($field =~ /^s(\d*)$/){ 
      $length = $1;
      if (!$length) {$length=30;}
      printf "%-${length}.${length}s ", $Ticket->Subject;
    }
    elsif ($field =~ /^t(\d*)$/){ 
      $length = $1;
      if (!$length) {$length=5;}
      printf "%-${length}.${length}s ", $Ticket->Status;
    }
    elsif ($field =~ /^q(\d*)$/){ 
      $length = $1;
      if (!$length) {$length=8;}
      printf "%-${length}.${length}s ", $Ticket->Queue->Id;
    }
    
    elsif ($field =~ /^g(\d*)$/){ 
      $length = $1;
      if (!$length) {$length=6;}
      printf "%-${length}.${length}s ", $Ticket->Age;
    }
    elsif ($field =~ /^l(\d*)$/){ 
      $length = $1;
      if (!$length) {$length=6;}
      printf "%-${length}.${length}s ", $Ticket->SinceTold;
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
# }}}

# {{{ sub build_query 

sub build_query  {
  my ($owner_ops, $user_ops, $status_ops, $prio_ops, $order_ops, $reverse);
  use RT::TicketCollection;
  my $Tickets = RT::TicketCollection->new($CurrentUser);

  # A hack to deal with the default..
  if ($#ARGV==-1) {
      push(@ARGV, '-open');
  }

  for ($i=0;$i<=$#ARGV;$i++) {
    if (($ARGV[0] eq '-help')  or 
	($ARGV[0] eq '--help') or 
	($ARGV[0] eq '-h')) {
      &usage();
      return();
  }

    if ($ARGV[$i] eq '-format') {
      $format_string = $ARGV[++$i];
      
    }
    
    if ($ARGV[$i] eq '-queue') {
      my $queue_id = $ARGV[++$i];
      $Tickets->NewRestriction( FIELD => 'queue',
			VALUE => "$queue_id");
    }
    
    if ($ARGV[$i] eq '-owner') {
      my $owner = $ARGV[++$i];
      $Tickets->NewRestriction( FIELD => 'owner',
			VALUE => "$owner");
      
    }
    
    if ($ARGV[$i] eq '-unowned'){
      $Tickets->NewRestriction( FIELD => 'owner',
			VALUE => "");
      
    }
    if ($ARGV[$i] =~ '-prio'){
      my $operator = $ARGV[++$i];
      my $priority = $ARGV[++$i];
      $Tickets->NewRestriction( FIELD => 'priority',
			OPERATOR => "$operator",
			VALUE => "$priority");
    }
    
    if ($ARGV[$i] =~ '-stat'){
      my $status = $ARGV[++$i];
      print "Got some status\n";
      $Tickets->NewRestriction( FIELD => 'status',
			VALUE => "$status");
    }
    
    if ($ARGV[$i] eq '-open'){
      $Tickets->NewRestriction( FIELD => 'status',
			VALUE => "open");
    }
    if (($ARGV[$i] eq '-resolved') or ($ARGV[$i] eq '-closed')){
      $Tickets->NewRestriction( FIELD => 'status',
			VALUE => "resolved");
      
      
    }
    if ($ARGV[$i] eq '-dead'){
      $Tickets->NewRestriction( FIELD => 'status',
			VALUE => "dead");
    }    
    
    if ($ARGV[$i] eq '-stalled'){
      $Tickets->NewRestriction( FIELD => 'status',
			VALUE => "stalled");
    }
    
    if ($ARGV[$i] eq '-user') {
      my $requestors = $ARGV[++$i];
      $Tickets->NewRestriction( FIELD => 'requestors',
			VALUE => "%$requestors%",
			OPERATOR => 'LIKE');
    }
    
    if ($ARGV[$i] eq '-maxitems') {
      $Tickets->Rows($ARGV[++$i]);
    }
    
     if ($ARGV[$i] eq '-firstitem') {
      $Tickets->FirstRow($ARGV[++$i]);
    }
    
    #TODO: DEAL WITH ORDERING & DEFAULT ORDERING
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
  
  $Tickets->ApplyRestrictions();
  return ($Tickets);
}

# }}}

# {{{ sub usage 

sub usage  {
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
	   -queue <queue>    lists from queue <queue>
           -open             lists only the open requests
           -resolved         lists resolved requests
           -stalled          lists stalled requests
           -dead             lists killed requests
           -orderby <crit>   Sorts requests by <crit>  (one of serial_num, 
                             queue_id, requestors, owner, subject, priority, 
                             status, date_created, date_due)
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
                             q[8]      queue
                             g[5]      age
                             l[6]      time since last correspondence
                             wt        tab
                             ws        space
                             wn        newline


                     Without options, rtq lists all open requests.
EOFORM



  }
# }}}

# {{{ sub print_header 
sub print_header  {
    my($format_string) =@_;
    my ($field, $length);

    my $total_length = 0;
    while ($format_string) {
	($field, $format_string) = split (/%/, $format_string,2);  
	
	if ($field =~ /^n(\d*)$/){ 
	    $length = $1;
	    if (!$length) {$length=6;}
	    $total_length = $total_length + $length;
	    printf "%-${length}.${length}s ", "Num";
	}
        elsif ($field =~ /^d(\d*)$/){
            $length = $1;
                if (!$length) {$length=5;}
            $total_length = $total_length + $length;
            printf "%-${length}.${length}s ", "Due";
        }
	elsif ($field =~ /^p(\d*)$/){ 
	    $length = $1;
		if (!$length) {$length=2;}
	    $total_length = $total_length + $length;
	    printf "%-${length}.${length}s ", "!";
	}
	elsif ($field =~ /^r(\d*)$/){ 
	    $length = $1;
		if (!$length) {$length=9;}
	    $total_length = $total_length + $length;
	    printf "%-${length}.${length}s ", "Requestor";
	}
	elsif ($field =~ /^o(\d*)$/){ 
	    $length = $1;
		if (!$length) {$length=8;}
	    $total_length = $total_length + $length;
	    printf "%-${length}.${length}s ", "Owner";
	}

	elsif ($field =~ /^s(\d*)$/){ 
	    $length = $1;
		if (!$length) {$length=20;}
	    $total_length = $total_length + $length;
	    printf "%-${length}.${length}s ", "Subject";
	}
	elsif ($field =~ /^t(\d*)$/){ 
	    $length = $1;
		if (!$length) {$length=5;}
	    $total_length = $total_length + $length;
	    printf "%-${length}.${length}s ", "State";
	}

	elsif ($field =~ /^q(\d*)$/){ 
	    $length = $1;
		if (!$length) {$length=8;}
	    $total_length = $total_length + $length;
	    printf "%-${length}.${length}s ", "Queue";
	}

	elsif ($field =~ /^g(\d*)$/){ 
	  $length = $1;
	  if (!$length) {$length=6;}
	    $total_length = $total_length + $length;
	    printf "%-${length}.${length}s ", "Age";
	}
	elsif ($field =~ /^l(\d*)$/){ 
	    $length = $1;
		if (!$length) {$length=6;}
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
# }}}

# {{{ sub GetCurrentUser 
sub GetCurrentUser  {
  if (!$CurrentUser) {
    my ($CurrentUid);
    require RT::CurrentUser;
        
    #Instantiate a user object
    
    ($CurrentUid,undef)=getpwuid($<);
    #If the current user is 0, then RT will assume that the User object
    #is that of the currentuser.
    $CurrentUser = new RT::CurrentUser($CurrentUid);
    if (!$CurrentUser) {
      print "You have no RT access\n";
      return(0);
    }
  }
  return($CurrentUser);
}
# }}}


1;

# Copyright 1999 Jesse Vincent <jesse@fsck.com>
# Released under the terms of the GNU Public License
# $Id$ 
#
#
package rt::ui::cli::manipulate;


sub activate {
 &GetCurrentUser;
 &ParseArgs();
 return(0);
}


sub GetCurrentUser {
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
sub ParseArgs {

  for ($i=0;$i<=$#ARGV;$i++) {
    if ($ARGV[$i] eq "-create")   {
      &cli_create_req;
    }
    elsif (($ARGV[$i] eq "-history") || ($ARGV[$i] eq "-show")){
      my $id=int($ARGV[++$i]);
      my ($Ticket);
      
      $Ticket=&LoadTicket($id);
     if ($Ticket) {
	  
	  if ($Ticket->DisplayPermitted) {
	    &ShowSummary($Ticket);
	    &ShowHistory($Ticket);
	  }
	  else {
	    print "You don't have permission to view that ticket.\n";
	  }
	}
      
    }
    
    
    elsif ($ARGV[$i] eq "-publichistory") {
      my $id=int($ARGV[++$i]);
      my $Ticket = &LoadTicket($id);
      
      if ($Ticket->DisplayPermitted) {
	&ShowSummary($id);
	&ShowRequestorHistory($id);
      }
      else {
	print "You don't have permission to view that ticket\n";
      }
    } 
    
    
    elsif ($ARGV[$i] eq "-trans") {
      
      my $tid = int($ARGV[++$i]);
      my $Transaction = RT::Transaction->new($CurrentUser->Id);
      $Transaction->Load($tid);
      &ShowTransaction($Transaction);	
      
      }
    
    elsif ($ARGV[$i] eq "-comment")	{
	my $id = int($ARGV[++$i]);
	my $Ticket=&LoadTicket($id);
	&cli_comment_req($Ticket);
      }
      
      elsif ($ARGV[$i] eq "-respond") {
	my $id = int($ARGV[++$i]);
	my $Ticket=&LoadTicket($id);
	&cli_respond_req($Ticket);
      }      	
      elsif ($ARGV[$i] eq "-take")	{
	my $id = int($ARGV[++$i]);
       	my $Ticket = &LoadTicket($id);
	$Message .= $Ticket->Take();
      }
      
      elsif ($ARGV[$i] eq "-stall")	{
	my $id = int($ARGV[++$i]);
	my $Ticket = &LoadTicket($id);
	$Message .= $Ticket->Stall();
	
      }
      
      elsif ($ARGV[$i] eq "-kill")	{
	$id=int($ARGV[++$i]);
	my $Ticket=&LoadTicket($id);
	
	$Message .= $Ticket->Kill();
	
	
	
      }
      
      elsif ($ARGV[$i] eq "-steal")	{
	$id=int($ARGV[++$i]);
	
	my $Ticket=&LoadTicket($id);
	$Message .= $Ticket->Steal();
	
      }
      
      elsif ($ARGV[$i] eq "-user")	{
	my $id = int($ARGV[++$i]);
	my $new_user = $ARGV[++$i];
	my $Ticket = &LoadTicket($id);
	
	$Message .= $Ticket->SetRequestors($new_user);
      }
      
      elsif ($ARGV[$i] eq "-untake")	{
	my $id=int($ARGV[++$i]);
	my $Ticket = &LoadTicket($id);

	$Message .= $Ticket->Untake();

      }
      
      elsif ($ARGV[$i] eq "-subject")	{
	my $id = int($ARGV[++$i]);
	my $subject = $ARGV[++$i];
	my $Ticket = &LoadTicket($id);
        $Ticket->SetSubject($subject);

      }
      
      elsif ($ARGV[$i] eq "-queue")	{
	my $id=int($ARGV[++$i]);
	my $queue=$ARGV[++$i];
	my $Ticket = &LoadTicket($id);
	$Message .= $Ticket->SetQueue($queue);
	
      }
      elsif ($ARGV[$i] eq "-area")	{
	my $id=int($ARGV[++$i]);
	my $area=$ARGV[++$i];
	my $Ticket = &LoadTicket($id);
	$Message .= $Ticket->SetArea($area);
      }
    
      elsif ($ARGV[$i] eq "-merge")	{
	my $id=int($ARGV[++$i]);
	my $merge_into=int($ARGV[++$i]);
	my $Ticket = &LoadTicket($id);

	$Message .= $Ticket->Merge($merge_into);
      }

      elsif ($ARGV[$i] eq "-due")	{
	my $id=int($ARGV[++$i]);
	my $Ticket = &LoadTicket($id);
	
	my $due_string=$ARGV[++$i];
	my $due_date = &rt::DateParse($due_string);
	
	$Message .= $Ticket->SetDue($id, $due_date, $CurrentUser->Id);

	}
      
      elsif ($ARGV[$i] eq "-prio") {
	my $id=int($ARGV[++$i]);
	my $Ticket = &LoadTicket($id);
	my $priority=int($ARGV[++$i]);
	$Message=$Ticket->SetPriority($priority);

      }
      
      elsif ($ARGV[$i] eq "-finalprio") {
	my $id = int($ARGV[++$i]);
	my $priority = int($ARGV[++$i]);
	my $Ticket = &LoadTicket($id);
	$Message .= $Ticket->SetFinalPriority($priority);

      }
      elsif ($ARGV[$i] eq "-notify") {
	my $id = int($ARGV[++$i]);
	my $Ticket = &LoadTicket($id);
	$Message .= $Ticket->Notify();

      }
      
      elsif ($ARGV[$i] eq "-give")	{
	my $id = int($ARGV[++$i]);
	my $owner = $ARGV[++$i];
	my $Ticket = &LoadTicket($id);
	$Message .= $Ticket->Give($owner);
      }
      
      elsif ($ARGV[$i] eq "-resolve")	{
	my $id = int($ARGV[++$i]);
	my $Ticket = &LoadTicket($id);
	$Message .= $Ticket->Resolve();
      }
      
      elsif ($ARGV[$i] eq "-open")	{
	$id=int($ARGV[++$i]);
	$Ticket=&LoadTicket($id);
	$Message .= $Ticket->Open; 
      }
      
    else {
      &ShowHelp;
    }
    next;
  }
  print "$Message\n";
}
  
  
  
  
  
  sub cli_create_req {	
    my ($queue_id,$owner,$requestors,$status,$priority,$subject,$final_prio,$date_due, $due_string);
    $queue_id=&rt::ui::cli::question_string("Place Request in queue",);
    $area=&rt::ui::cli::question_string("Place Request in area",);
    $owner=&rt::ui::cli::question_string( "Give request to");
    $requestors=&rt::ui::cli::question_string("Requestor(s)",);
    $subject=&rt::ui::cli::question_string("Subject",);
    $priority=&rt::ui::cli::question_int("Starting Priority",$rt::queues{$queue_id}{'default_prio'});
    $final_priority=&rt::ui::cli::question_int("Final Priority",$rt::queues{$queue_id}{'default_final_prio'});
    $due_string=&rt::ui::cli::question_string("Date due (MM/DD/YYYY)",);
    if ($due_string ne '') {
      use Date::Manip;
      $date_due = &ParseDate($due_string);
    }  
    print "Please enter a detailed description of this request, terminated\nby a line containing only a period:\n";
    while (<STDIN>) {
      if(/^\.\n/) {
	last;
      }
      else {
	$content .= $_;
      }
    }	 
    use RT::Ticket;
    my $Ticket = RT::Ticket->new($CurrentUser);
    my ($id, $Transaction, $ErrStr) = $Ticket->Create ( Queue => $queue,
			       Area => $area,
			       Alias => $alias,
			       Requestors => $requestors,
			       Owner => $owner,
			       Subject => $subject,
			       InitialPriority => $priority,
			       FinalPriority => $final_priority,
			       Status => 'open',
			       Due => $date_due);
    $Transaction->Attach('','text/plain','',$content);
    printf("Request %s created",$id);
  }
  
  sub cli_comment_req {	
    my $Ticket = shift ;
    my ($subject,$content,$trans,$message,$cc,$bcc );
    
    $subject=&rt::ui::cli::question_string("Subject",);
    $cc=&rt::ui::cli::question_string("Cc",);
    $bcc=&rt::ui::cli::question_string("Bcc",);   
    print "Please enter your comments this request, terminated\nby a line containing only a period:\n";
    while (<STDIN>) {
      if(/^\.\n/) {
	last;
      }
      else {
	$content .= $_;
      }
    }
    

    $Message = $Ticket->Comment(subject => "$subject",
				content => "$content",
				cc => "$cc",
				bcc => "$bcc",
				sender => $CurrentUser->EmailAddress);
    print $Message;
  }
  
  sub cli_respond_req {
    my $id =  shift;
    my ($subject,$content,$trans,$message,$cc,$bcc );
    
    $subject=&rt::ui::cli::question_string("Subject",);
    $cc=&rt::ui::cli::question_string("Cc",);
    $bcc=&rt::ui::cli::question_string("Bcc",);      
    print "Please enter your response to this request, terminated\nby a line containing only a period:\
n";
    while (<STDIN>) {
      if(/^\.\n/) {
	last;
      }
      else {
	$content .= $_;
      }
    }
    my $Ticket = &LoadTicket($id);
    $Message = $Ticket->NewCorrespondence(subject => "$subject",
					   content => "$content",
					   cc => "$cc",
					   bcc => "$bcc",
					   sender => $CurrentUser->EmailAddress);
    print $Message;
  }                   
  
  sub ShowHistory {
    my $Ticket = shift;
    my $Transaction;
    while ($Transaction = $Ticket->Transactions->Next) {
      &ShowTransaction($Transaction);
    }   
  }
  sub ShowRequestorHistory {
    my $Ticket = shift;
    my $Transaction;
    while ($Transaction = $Ticket->Transactions->Next) {
      if ($Transaction->Type ne 'comment') {
	&ShowTransaction($Transaction);
      }
    }   
  }
  
  sub ShowHelp {
    print <<EOFORM
    
    RT CLI Flags and their arguments
    -----------------------------------------------
    -create		  Interactively create a new request
    -resolve <num>	  Change <num>'s status to resolved
    -open <num>		  Change <num>'s status to open
    -stall <num>	  Change <num>'s status to stalled
    -show <num>		  Display transaction history current status of <num>
    -take <num>		  Become owner of <num> (if unowned)
    -steal <num>	  Become owner of <num> (if owned by another)
    -untake <num>	  Make <num> ownerless (if owned by you) 
    -give <num> <user>	  Make <user> owner of <num>
    -user <num> <user>	  Change the requestor ID of <num> to <user>
    -due <num< <date>     Change <num>'s due date to <date> (MM/DD/YY)
    -comment <num>	  Add comments about <num> from STDIN
    -respond <num>	  Respond to <num>
    -subject <num> <sub>  Change <num>'s subject to <sub>
    -queue <num> <queue>  Change <num>'s queue to <queue>
    -area <num> <area>    Change <num>'s area to <area>
    -prio <num> <int>	  Change <num>'s priority to <int>
    -finalprio <num <int> Change <num>'s final priority to <int>
    -notify <num>	  Note that <num>'s requestor was notified
    -merge <num1> <num2>  Merge <num1> into <num2>
    -trans <ser> <trans>  Display ticket <ser> transaction <trans>
    -kill <num>           Permanently remove <num> from the database
EOFORM
    
  }
  
  sub ShowSummary {
    my $Ticket = shift;

    use Time::Local;
    print <<EOFORM
       Serial Number:@{[$Ticket->Id]}
               Queue:@{[$Ticket->Queue->QueueId]}
                Area:$Ticket->Area
          Requestors:@{[$Ticket->Requestors]}
               Owner:@{[$Ticket->Owner->UserId]}
             Subject:@{[$Ticket->Subject]}
      Final Priority:@{[$Ticket->FinalPriority]}
    Current Priority:@{[$Ticket->Priority]}
              Status:@{[$Ticket->Status]}
             Created:@{[localtime($Ticket->Created)]}) (@{[$Ticket->Age]}) ago)
        Last Contact:@{[localtime($Ticket->Told)]}) (@{[$Ticket->SinceTold]} ago)
	         Due:@{[localtime($Ticket->Due)]})

EOFORM
}
sub ShowTransaction {
  my $transaction = shift;
  
  print <<EOFORM
==========================================================================
Date: @{[$transaction->DateAsString]} (@{[$transaction->TimeWorked]} minutes)
@{[$transaction->Description]}
@{[$transaction->Content]}
EOFORM
}
  
sub LoadTicket {
  my $id = shift;
  my ($Ticket,$Status,$Message,$CurrentUser);
  $CurrentUser=&GetCurrentUser;
  print "Current User is ".$CurrentUser->Id."\n";;
  use RT::Ticket;
  $Ticket = new RT::Ticket ($CurrentUser);
  ($Status, $Message) = $Ticket->Load($id);
  if (!$Status) {
    print ("The request could not be loaded");
    return (0);
 }
  else {
    return ($Ticket);
  
  }
}
1;

# Copyright 1996-2000 Jesse Vincent <jesse@fsck.com>
# Released under the terms of the GNU Public License
# $Id$ 
#
#
package rt::ui::cli::manipulate;
# {{{ sub activate 
sub activate  {
    &GetCurrentUser;
    $RT::Logger->log(level=>'info', message=>$CurrentUser->UserId.' started up the RT cli');
    &ParseArgs();
    $RT::Logger->log(level=>'debug', message=>'RT cli going down');
    return(0);
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

# {{{ sub ParseArgs 
sub ParseArgs  {

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
      
      elsif ($ARGV[$i] eq "-link")	{
	$base=int($ARGV[++$i]);
	$type=$ARGV[++$i];
	$target=int($ARGV[++$i]);
	my $Ticket;
	if ($Ticket=&LoadTicket($base)) {
	  my ($res, $msg, $linkid)=
	    $Ticket->LinkTo(Target=>$target, Type=>$type);
	  $Message .= $msg;
	} elsif ($Ticket=&LoadTicket($target)) {
	  my ($res, $msg, $linkid)=
	    $Ticket->LinkFrom(Base=>$base, Type=>$type);
	  $Message .= $msg;
	}
      }

      elsif ($ARGV[$i] eq "-steal")	{
	$id=int($ARGV[++$i]);
	
	my $Ticket=&LoadTicket($id);
	$Message .= $Ticket->Steal();
	
      }
      
    
    elsif ( ($ARGV[$i] =~ "-cc") || 
	    ($ARGV[$i] =~ "-admincc") || 
	    ($ARGV[$i] =~ "-user") ||
	      ($ARGV[$i] =~ "-requestorr") 
	  ) {
      
      my $type = $ARGV[$i];
      my $id = int($ARGV[++$i]);
      my $arg = $ARGV[++$i];
      my $Ticket = &LoadTicket($id);
    
      if ($type eq '-cc') {
	$watcher_type = "Cc";
      }
      elsif ($type eq '-admincc') {
	$watcher_type = "AdminCc";
      }
      elsif (($type eq '-user') || ($type eq '-requestor')) {
	$watcher_type = "Requestor";
      }
      else {
	#we've just covered all our bases
	die "This else never reached. Ever. or you broke the cli\n";
      }
     
      if ($arg =~ /^(.)(.*)/) {
	$action = $1;
	$email = $2;
      }
      if ($action eq "+") {
	$Message .= $Ticket->AddWatcher(Email => "$email",
					Type => "$watcher_type");
	
      }
      elsif ($action eq "-") {
	$Message .= $Ticket->DeleteWatcher("$email");
      }
      else {
	$Message .= "$type expects an argument of the form +<email address> or -<email address>\n";
      }
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
	$Message .= $Ticket->SetOwner($owner);
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

  # TODO: This is wrong.  Message should always be a scalar.
  
  if (defined $Message) {
    print $Message."\n";
  }
#  if (ref $Message) {$Message->print;}
#  else {print $Message;}
  

}
# }}}

# {{{ sub cli_create_req 
sub cli_create_req  {	
    my ($queue_id,$owner,$Requestors,$status,$priority,$Subject,$final_prio,
	$Cc, $Bcc, $date_due, $due_string, $Owner);

    require RT::Ticket;
    my $Ticket = RT::Ticket->new($CurrentUser);
    
    $queue_id=&rt::ui::cli::question_string("Place Request in queue",);

    require RT::Queue;
    my $Queue = RT::Queue->new($CurrentUser);
    
    while (!$Queue->Load($queue_id)) {
      print "That Queue does not exist\n";
      $queue_id=&rt::ui::cli::question_string("Place Request in queue",) || "general";
    }
    
    if (!$Queue->CreatePermitted) {
      print "You may not create a ticket in that queue";
    }

    
  
    if ($Queue->ModifyPermitted($CurrentUser)) {

      require RT::User;
      $Owner = RT::User->new($CurrentUser);
      
      $owner=&rt::ui::cli::question_string( "Give request to");
      
      while ($owner && (!$Owner->Load($owner) || !$Queue->ModifyPermitted($Owner))) {
	
	print "That user doesn't exist or can't own tickets in that queue\n";
	$owner=&rt::ui::cli::question_string( "Give request to")
      }
      
      
      $priority=&rt::ui::cli::question_int("Starting Priority",$rt::queues{$queue_id}{'default_prio'});
      $final_priority=&rt::ui::cli::question_int("Final Priority",$rt::queues{$queue_id}{'default_final_prio'});
      $due_string=&rt::ui::cli::question_string("Date due (MM/DD/YYYY)",);
      if ($due_string ne '') {
	require Date::Manip;
	$date_due = &Date::Manip::ParseDate($due_string);
      }  
      
    }

    $Requestor = &rt::ui::cli::question_string("Requestor",);
    $Cc = &rt::ui::cli::question_string("Cc",);
    $Bcc =  &rt::ui::cli::question_string("Bcc",);
    $Subject=&rt::ui::cli::question_string("Subject",);
  
 
    print "Please enter a detailed description of this request, terminated\nby a line containing only a period:\n";
    while (<STDIN>) {
      if(/^\.\n/) {
	last;
      }
      else {
	$content .= $_;
      }
    }	 
    require MIME::Entity;
    $Message = MIME::Entity->build ( Subject => $Subject||"",
				     From => $Requestor||"",
				     Cc => $Cc||"",
				     Bcc => $Bcc||"",
				     Data => $content||"");


   # print "Message CC is ". $message->head->get('From');

    my ($id, $Transaction, $ErrStr) = $Ticket->Create ( QueueTag => $queue_id,
#			       Alias => $alias,
			       Owner => $Owner->id,
			       Subject => $Subject,
			       InitialPriority => $priority,
			       FinalPriority => $final_priority,
			       Status => 'open',
			       Due => $date_due,
	      		       MIMEEntity => $Message			
						      );

    printf("Request %s created\n",$id);
  }
# }}}
  
# {{{ sub cli_comment_req 
sub cli_comment_req  {	
    my $Ticket = shift ;
    my ($subject,@content,$trans,$cc,$bcc,$Transaction,
	$Description, $TimeTaken);
    
   
    $subject=&rt::ui::cli::question_string("Subject",);
    
    $cc=&rt::ui::cli::question_string("Cc this comment to:",);
    $bcc=&rt::ui::cli::question_string("Bcc this comment to:",);   
    print "Please enter your comments this request, terminated\nby a line containing only a period:\n";
    while (<STDIN>) {
      if(/^\.\n/) {
	last;
      }
      else {
	push (@content, $_);
	
      }
    }
   
    $TimeTaken = &rt::ui::cli::question_int("How long did you spend on this transaction?");
 
    require MIME::Entity;
    $Message = MIME::Entity->build ( Subject => $subject || "",
				     Cc => $cc || "",
				     Bcc => $Bcc || "",
				     Data => \@content);
    
    ($Transaction, $Description) = $Ticket->Comment( CcMessageTo => $cc,
						     BccMessageTo => $bcc,
						     MIMEObj => $Message,
						     TimeTaken => $TimeTaken
						   );
    
    print $Description, "\n";
  }
# }}}  
  
# {{{ sub cli_respond_req 
sub cli_respond_req  {
    my $Ticket =  shift;
    my ($subject,$content,$trans,$message,$cc,$bcc );
    
    $subject=&rt::ui::cli::question_string("Subject",);
    $cc=&rt::ui::cli::question_string("Cc this response to:",);
    $bcc=&rt::ui::cli::question_string("Bcc this response to:",);      
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
    my ($Trans, $Message) = $Ticket->Correspond
      ( CcMessageTo => $cc,
	BccMessageTo => $bcc,
	MIMEObj => MIME::Entity->build( Subject => $subject || "",
					Cc => $cc || "",
					Bcc => $Bcc || "",
					Data => $content));
    print "$Message\n";
  }                   
# }}}
  
# {{{ sub ShowHistory 
sub ShowHistory  {
    my $Ticket = shift;
    my $Transaction;
    while ($Transaction = $Ticket->Transactions->Next) {
      &ShowTransaction($Transaction);
    }   
  }
# }}}

# {{{ sub ShowRequestorHistory 
sub ShowRequestorHistory  {
    my $Ticket = shift;
    my $Transaction;
    while ($Transaction = $Ticket->Transactions->Next) {
      if ($Transaction->Type ne 'comment') {
	&ShowTransaction($Transaction);
      }
    }   
  }
# }}}
  
# {{{ sub ShowHelp 
sub ShowHelp  {
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

    -user <num> (+|-) <email>	  Add or remove <email> as a watcher for <num>
    -cc <num> (+|-) <email>
    -admincc <num> (+|-) <email>

    -due <num< <date>     Change <num>'s due date to <date> (MM/DD/YY)
    -comment <num>	  Add comments about <num> from STDIN
    -respond <num>	  Respond to <num>
    -subject <num> <sub>  Change <num>'s subject to <sub>
    -queue <num> <queue>  Change <num>'s queue to <queue>
    -prio <num> <int>	  Change <num>'s priority to <int>
    -finalprio <num <int> Change <num>'s final priority to <int>
    -notify <num>	  Note that <num>'s requestor was notified
    -merge <num1> <num2>  Merge <num1> into <num2>
    -trans <ser> <trans>  Display ticket <ser> transaction <trans>
    -kill <num>           Permanently remove <num> from the database

    -link <num> (DependsOn|MemberOf|RefersTo) <num>
EOFORM
    
  }
# }}}
  
# {{{ sub ShowSummary 
sub ShowSummary  {
    my $Ticket = shift;

    require Time::Local;
    print <<EOFORM;
Serial Number: @{[$Ticket->Id]}   Status:@{[$Ticket->Status]} Worked: @{[$Ticket->TimeWorked]} minutes  Queue:@{[$Ticket->Queue->QueueId]}
      Subject: @{[$Ticket->Subject]}
   Requestors: @{[$Ticket->RequestorsAsString]}
           Cc: @{[$Ticket->CcAsString]}
     Admin Cc: @{[$Ticket->AdminCcAsString]}
        Owner: @{[$Ticket->Owner->UserId]}
     Priority: @{[$Ticket->Priority]} / @{[$Ticket->FinalPriority]}
          Due: @{[$Ticket->DueAsString]}
      Created: @{[$Ticket->CreatedAsString]} (@{[$Ticket->AgeAsString]})
 Last Contact: @{[$Ticket->ToldAsString]} (@{[$Ticket->LongSinceToldAsString]} ago)
  Last Update: @{[$Ticket->LastUpdatedAsString]} by @{[$Ticket->LastUpdatedBy]}
	         
EOFORM

   while (my $l=$Ticket->Children->Next) {
       print $l->BaseObj->id," (",$l->BaseObj->Subject,") ",$l->Type," THIS\n";
   }
   while (my $l=$Ticket->Parents->Next) {
       print "THIS ",$l->Type," ",$l->TargetObj->Id," (",$l->TargetObj->Subject,")\n";
   }
}
# }}}

# {{{ sub ShowTransaction 
sub ShowTransaction  {
  my $transaction = shift;
  
print <<EOFORM;
==========================================================================
Date: @{[$transaction->CreatedAsString]} (@{[$transaction->TimeTaken]} minutes)
@{[$transaction->Description]}
EOFORM
    ;
  my $attachments=$transaction->Attachments();
  while (my $message=$attachments->Next) {
    print <<EOFORM;
--------------------------------------------------------------------------
@{[$message->Headers]}
EOFORM
    my ($test1, $test2)=$message->Quote;
    print "TEST: ", $$test1, $test2,"\n\n\n\n";
    if ($message->ContentType =~ m{^(text/plain|message)}) {
	print $message->Content;
    } else {
	print $message->ContentType, " not shown";
    }
  }
  return();
}
# }}}

# {{{ sub LoadTicket 
sub LoadTicket  {
  my $id = shift;
  my ($Ticket,$Status,$Message,$CurrentUser);
  $CurrentUser=&GetCurrentUser;
  #print "Current User is ".$CurrentUser->Id."\n";;
  require RT::Ticket;
  $Ticket = RT::Ticket->new($CurrentUser);
  ($Status, $Message) = $Ticket->Load($id);
  if (!$Status) {
    print ("The ticket could not be loaded\n$Message\n");
    return (0);
 }
  else {
    return ($Ticket);
  
  }
}
# }}}
1;

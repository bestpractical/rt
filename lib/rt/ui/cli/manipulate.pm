# Copyright 1999 Jesse Vincent <jesse@fsck.com>
# Released under the terms of the GNU Public License
# $Id$ 
#
#
package rt::ui::cli::manipulate;


sub activate {
  my ($current_user);
  require RT::User;

    
  #Instantiate a user object
  
  ($CurrentUser,undef)=getpwuid($<);
  $CurrentUser = new RT::User($CurrentUser);
  $CurrentUser->load($CurrentUser);
  
  &ParseArgs;
  return(0);
}


  

sub ParseArgs {
  for ($i=0;$i<=$#ARGV;$i++) {
    if ($ARGV[$i] eq "-create")   {
      &cli_create_req;
    }
    elsif (($ARGV[$i] eq "-history") || ($ARGV[$i] eq "-show")){
      my $id=int($ARGV[++$i]);
      my $Request = &LoadTicket($id);
      
      if ($Request->DisplayPermitted) {
	&ShowSummary($Request);
	&ShowHistory($Request);
      }
      else {
	print "You don't have permission to view that ticket.\n";
      }
    }
    
    
    elsif ($ARGV[$i] eq "-publichistory") {
      my $id=int($ARGV[++$i]);
      my $Request = &LoadTicket($id);
      
      if ($Request->DisplayPermitted) {
	&ShowSummary($id);
	&ShowRequestorHistory($id);
      }
      else {
	print "You don't have permission to view that ticket\n";
      }
    } 
    
    
    elsif ($ARGV[$i] eq "-trans") {
      
      my $tid = int($ARGV[++$i]);
	my $Transaction = RT::Transaction->new($CurrentUser->UserId);
	$Transaction->Load($tid);
      &ShowTransaction($Transaction);	
	
      }
      
      elsif ($ARGV[$i] eq "-comment")	{
	my $id = int($ARGV[++$i]);
	my $Request=&LoadTicket($id);
	&cli_comment_req($Request);
      }
      
      elsif ($ARGV[$i] eq "-respond") {
	my $id = int($ARGV[++$i]);
	my $Request=&LoadTicket($id);
	&cli_respond_req($Request);
      }      	
      elsif ($ARGV[$i] eq "-take")	{
	my $id = int($ARGV[++$i]);
       	my $Request = &LoadTicket($id);
	$Message .= $Request->take($id, $CurrentUser->UserId);
      }
      
      elsif ($ARGV[$i] eq "-stall")	{
	my $id = int($ARGV[++$i]);
	my $Request = &LoadTicket($id);
	$Message .= $Request->stall ($id, $CurrentUser->UserId);
	
      }
      
      elsif ($ARGV[$i] eq "-kill")	{
	$id=int($ARGV[++$i]);
	my $Request=&LoadTicket($id);

	$response=&rt::ui::cli::question_string("Type 'yes' if you REALLY want to KILL request \#$id",);
	if ($response eq 'yes') { 
	  $Message .= $Request->Kill();


	}
	else {
	  $Message .= "Kill aborted.\n";
	  
	}
      }
      
      elsif ($ARGV[$i] eq "-steal")	{
	$id=int($ARGV[++$i]);
	
	my $Request=&LoadTicket($id);
	$Message .= $Request->Steal();
	
      }
      
      elsif ($ARGV[$i] eq "-user")	{
	my $id = int($ARGV[++$i]);
	my $new_user = $ARGV[++$i];
	my $Request = &LoadTicket($id);
	
	$Message .= $Request->Requestors($new_user);
      }
      
      elsif ($ARGV[$i] eq "-untake")	{
	my $id=int($ARGV[++$i]);
	my $Request = &LoadTicket($id);

	$Message .= $Request->untake();

      }
      
      elsif ($ARGV[$i] eq "-subject")	{
	my $id = int($ARGV[++$i]);
	my $subject = $ARGV[++$i];
	my $Request = &LoadTicket($id);
        $Request->Subject ($subject);

      }
      
      elsif ($ARGV[$i] eq "-queue")	{
	my $id=int($ARGV[++$i]);
	my $queue=$ARGV[++$i];
	my $Request = &LoadTicket($id);
	$Message .= $Request->Queue($queue);
	
      }
      elsif ($ARGV[$i] eq "-area")	{
	my $id=int($ARGV[++$i]);
	my $area=$ARGV[++$i];
	my $Request = &LoadTicket($id);
	$Message .= $Request->Area($area);
      }
      
      elsif ($ARGV[$i] eq "-merge")	{
	my $id=int($ARGV[++$i]);
	my $merge_into=int($ARGV[++$i]);
	my $Request = &LoadTicket($id);

	$Message .= $Request->Merge($merge_into);
      }

      elsif ($ARGV[$i] eq "-due")	{
	my $id=int($ARGV[++$i]);
	my $Request = &LoadTicket($id);
	
	my $due_string=$ARGV[++$i];
	my $due_date = &rt::date_parse($due_string);
	
	$Message .= $Request->DateDue($id, $due_date, $CurrentUser->UserId);

	}
      
      elsif ($ARGV[$i] eq "-prio") {
	my $id=int($ARGV[++$i]);
	my $Request = &LoadTicket($id);
	my $priority=int($ARGV[++$i]);
	$Message=$Request->Priority($priority);

      }
      
      elsif ($ARGV[$i] eq "-finalprio") {
	my $id = int($ARGV[++$i]);
	my $priority = int($ARGV[++$i]);
	my $Request = &LoadTicket($id);
	$Message .= $Request->FinalPriority($priority);

      }
      elsif ($ARGV[$i] eq "-notify") {
	my $id = int($ARGV[++$i]);
	my $Request = &LoadTicket($id);
	$Message .= $Request->Notify();

      }
      
      elsif ($ARGV[$i] eq "-give")	{
	my $id = int($ARGV[++$i]);
	my $owner = $ARGV[++$i];
	my $Request = &LoadTicket($id);
	$Message .= $Request->Give($owner);
      }
      
      elsif ($ARGV[$i] eq "-resolve")	{
	my $id = int($ARGV[++$i]);
	my $Request = &LoadTicket($id);
	$Message .= $Request->Resolve();
	
      }
      
      elsif ($ARGV[$i] eq "-open")	{
	$id=int($ARGV[++$i]);
	$Request=&LoadTicket($id);
	$Message .= $Request->Open; 
      }
      
      else {
	&ShowHelp;
      }
      next;
    }
    print "$Message\n";
  }
  
  
  
  
  
  sub cli_create_req {	
    my ($queue_id,$owner,$requestors,$status,$priority,$subject,$final_prio,$date_due);
    $queue_id=&rt::ui::cli::question_string("Place Request in queue",);
    $area=&rt::ui::cli::question_string("Place Request in area",);
    $owner=&rt::ui::cli::question_string( "Give request to");
    $requestors=&rt::ui::cli::question_string("Requestor(s)",);
    $subject=&rt::ui::cli::question_string("Subject",);
    $priority=&rt::ui::cli::question_int("Starting Priority",$rt::queues{$queue_id}{'default_prio'});
    $final_priority=&rt::ui::cli::question_int("Final Priority",$rt::queues{$queue_id}{'default_final_prio'});
    $due_string=&rt::ui::cli::question_string("Date due (MM/DD/YYYY)",);
    if ($due_string ne '') {
      $date_due = &rt::date_parse($due_string);
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
    my $Request = RT::Request->new($CurrentUser->UserId);
    my $id = $Request->Create ( queue => $queue,
				area => $area,
				alias => $alias,
				requestors => $requestors,
				owner => $owner,
				subject => $subject,
				initial_priority => $priority,
				final_priority => $final_priority,
				status => 'open',
				date_due => $date_due);
    printf("Request %s created",$id);
  }
  
  sub cli_comment_req {	
    my ($id)=@_;
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
    
    my $Request = &LoadTicket($id);
    $Message =$Request->Comment(subject => "$subject",
				content => "$content",
				cc => "$cc"
				bcc => "$bcc",
				sender => $CurrentUser->UserId);
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
    my $Request = &LoadTicket($id);
    $Message = $Request->NewCorrespondence(subject => "$subject",
					   content => "$content",
					   cc => "$cc"
					   bcc => "$bcc",
					   sender => $CurrentUser->UserId);
    print $Message;
  }                   
  
  sub ShowHistory {
    my $Request = shift;
    my $Transaction;
    while ($Transaction = $Request->Transactions->Next) {
      &ShowTransaction($Transaction);
    }   
  }
  sub ShowRequestorHistory {
    my $Request = shift;
    my $Transaction;
    while ($Transaction = $Request->Transactions->Next) {
      if ($Transaction->Type ne 'comment') {
	&ShowTransaction($Transaction);
      }
    }   
  }
  
  sub ShowHelp {
    print "
    
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
    -kill <num>           Permanently remove <num> from the database\n";
    
  }
  
  sub ShowSummary {
    my $Request = shift;

    use Time::Local;
    

print << EOFORM;    
       Serial Number:@{[$Request->Id]}
               Queue:@{[$Request->Queue->Id]}
                Area:@{[$Request->Area]}
          Requestors:@{[$Request->Requestors]}
               Owner:@{[$Request->Owner]}
             Subject:@{[$Request->Subject]}
      Final Priority:@{[$Request->FinalPriority]}
    Current Priority:@{[$Request->Priority]}
              Status:@{[$Request->Status]}
             Created:@{[localtime($Request->DateCreated]}) (@{[$Request->Age ago]})
        Last Contact:@{[localtime($Request->DateTold]}) (@{[$Request->SinceTold ago]})
	         Due:@{[localtime($Request->DateDue]})

EOFORM
    
}
  sub ShowTransaction {
    my $transaction = shift;
    
    print <<EOFORM;
==========================================================================
Date: @{[$transaction->DateAsString]} (@{[$transaction->TimeWorked]} minutes)
@{[$transaction->Description]}
@{[$transaction->Content]}
EOFORM    
  }
  
sub LoadTicket {
  my $id = shift;
  my ($Request,$Status,$Message);
  
  use RT::Ticket;
  $Request = RT::Ticket->new($CurrentUser->UserId);
  ($Status, $Message) = $Request->Load($id);
  if (!$Status) {
    return (0, "The request could not be loaded");
  }
  else {
    return ($Request);
  
}

1;

# (c) 1996-2000 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL

package RT::Interface::Email;
use RT::Ticket;
# {{{ sub activate 
sub activate  {
  my $Queue=$ARGV[0];
  my $Action=$ARGV[1];
  my $Area = $ARGV[2];
  
  my ($From, $TicketId, $Subject);
  
  if (!defined ($Queue)) { $Queue = "general";}
  if (!defined ($Action)) { $Action = "correspond";}
  
  my $time = time;

  my $AttachmentDir = "/tmp/rt-tmp-$time";
  mkdir "$AttachmentDir", 0700;

  # Create a new parser object:
  use MIME::Parser;
  use Mail::Address;

  my $parser = new MIME::Parser;
  
  # Set up output directory for files:
  $parser->output_dir("$AttachmentDir");
  
  # Set up the prefix for files with auto-generated names:
  $parser->output_prefix("part");
  
  # If content length is <= 20000 bytes, store each msg as in-core scalar;
  # Else, write to a disk file (the default action):
  $parser->output_to_core(20000);
  
  #Ok. now that we're set up, let's get the stdin.
  #TODO: Deal with this error better
  my $entity = $parser->read(\*STDIN) or die "couldn't parse MIME stream";
 

 
  # Get the head, a MIME::Head:
  $head = $entity->head;

  #Lets check for mail loops of various sorts.
  my $IsALoop = &CheckForLoops($head);
  
  if ($IsALoop) {
    #TODO Send mail to an administrator
    die "RT Recieved a message it should not process";
  }
  


  #Pull apart the subject line
  $Subject = $head->get('Subject') || "";
  chomp $Subject;
  
  if ($Subject =~ s/\[$RT::rtname \#(\d+)\]//i) {
    $TicketId = $1;
    #print STDERR "Got a ticket id: $TicketId\n";
  }

  
  my $CurrentUser = &GetCurrentUser($head);

  #print STDERR "User is $CurrentUser\n"; 
  #If the message doesn't reference a ticket #, create a new ticket
  if (!defined($TicketId)) {
    #    If the message is meant to be a comment, return an error.
    if ($Action =~ /comment/i) {
      #TODO Send a warning message
      die "can't comment on a nonexistent ticket...";
    }
    
    #    open a new ticket 
    my $Ticket = new RT::Ticket($CurrentUser); #TODO we need an anonymous user
    my ($id, $Transaction, $ErrStr) = 
      $Ticket->Create ( QueueTag => $Queue,
			Area => $Area,
			Subject => $Subject,
			MIMEEntity => $entity
		      );
   #print "id/trans/err:  $id $Transaction $ErrStr\n"; 
  }
  else { #If we have a ticketid
    #print STDERR "We know we've got a ticketId\n";
    #   If the message contains commands, execute them
    # TODO / Stub!

    # It might be worth considerating to allow both the old style (%RT
    # command parameter(s)) and an alternative style where the
    # commands are injected into the header.

    #   If the mail message is a comment, add a comment.
    if ($Action =~ /comment/i){
       #print "Action is $Action\n";
      my $Ticket = new RT::Ticket($CurrentUser);
      $Ticket->Load($TicketId);
      #TODO: Check for error conditions.
      $Ticket->Comment(MIMEObj=>$entity);
    }
    
    
    #   If the message is correspondence, add it to the ticket
    elsif ($Action =~ /correspond/) {
      #print STDERR "Action is correspond\n"; 
      my $Ticket = RT::Ticket->new($CurrentUser);
      $Ticket->Load($TicketId);
	#	print STDERR "Ticket loaded\n";
      #TODO: Check for error conditions
      $Ticket->Correspond(MIMEObj => $entity);
   	#print STDERR "ticket correspond done\n"; 
	}
     else { 
	#TODO: Send a warning
	die "Unknown action type: $Action\n";
     }
  }
  
  return(0);
}
# }}}

# {{{ sub CheckForLoops 
sub CheckForLoops  {
  my $head = shift;

  #If this instance of RT sent it our, we don't want to take it in
  my $RTLoop = $head->get("X-RT-Loop-Prevention") || "";
  if ($RTLoop eq "$RT::rtname") {
    return(1);
  }
 
  #if it's from a postmaster or mailer daemon, it's likely a bounce.
  my $From = $head->get("From") || "";
  
  if (($From =~ /^mailer-daemon/i) or
      ($From =~ /^postmaster/i)){
    return (1);
  }

  #If it claims to be bulk mail, discard it
  my $Precedence = $head->get("Precedence") || "" ;

  if ($Precedence =~ /^bulk/i) {
    return (1);
  }
}
# }}}




# {{{ sub GetCurrentUser 
sub GetCurrentUser  {
  my $head = shift;

  #Figure out who's sending this message.
  my $From = $head->get('Reply-To') || $head->get('From') || $head->get('Sender');

  use Mail::Address;
  #TODO: probably, we should do something smart here like generate
  # the ticket as "system"

  my ($FromObj) = Mail::Address->parse($From) or die "Couldn't parse From-address";
  my $Name =  ($FromObj->phrase || $FromObj->comment || $FromObj->address);

  
  #Now we've got a parsed mime object. 
  use RT::CurrentUser;
  my $CurrentUser = new RT::CurrentUser($FromObj->address);
  
  #Lets take the from and load a user object.
  unless ($CurrentUser->Id) {
    #If it fails, create a user
    
    use RT::User;
    my $SystemUser = new RT::CurrentUser(1);
    my $NewUser = RT::User->new($SystemUser);#Create a user as root 
    #TODO: Figure out a better way to do this
    my ($Val, $Message) = $NewUser->Create(UserId => $FromObj->address,
					   EmailAddress => $FromObj->address,
					   RealName => "$Name",
					   Password => "Default", #TODO FIX THIS
					   CanManipulate => 0,
					   IsAdministrator => 0,
					   Comments => "Autocreated by RT::Mailgate on ticket submission"
					  );
    
    if (!$Val) {
      #TODO this should not just up and die. at the worst it should send mail.
      die $Message;
    }
    #TODO: Send the user a "welcome message"
    #Load the new user object
    $CurrentUser->Load($FromObj->address);
  }
  return ($CurrentUser);
}
# }}}

1;

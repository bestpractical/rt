package rt::ui::mail::manipulate;

sub activate {
  my $Action=$ARGV[0];
  my $Queue=$ARGV[1];
  my $Area = $ARGV[2];
  
  my ($From, $TicketId, $Subject);

  
  #BEGIN TEMPORARY CODE FOR CLI USAGE
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
#END TEMPORARY CODE

  
  if (!defined ($Queue)) { $Queue = "general";}
  if (!defined ($Action)) { $Action = "correspond";}
  
  my $time = time;
  my $AttachmentDir = "/tmp/rt/$time";
  mkdir "$AttachmentDir", 0700;

  # Create a new parser object:
  use MIME::Parser;
  my $parser = new MIME::Parser;
  
  # Set up output directory for files:
  $parser->output_dir("$AttachmentDir");
  
  # Set up the prefix for files with auto-generated names:
  $parser->output_prefix("part");
  
  # If content length is <= 20000 bytes, store each msg as in-core scalar;
  # Else, write to a disk file (the default action):
  $parser->output_to_core(20000);
  
  #Ok. now that we're set up, let's get the stdin.
  $entity = $parser->read(\*STDIN) or die "couldn't parse MIME stream";
  
  # Get the head, a MIME::Head:
  $head = $entity->head;

  #Lets check for mail loops of various sorts.
  my $IsALoop = &CheckForLoops($head);
  
  if ($IsALoop) {
    #TODO Send mail to an administrator
    die "RT Recieved a message it should not process";
  }
  
  #Figure out who's sending this message.
  $From = $head->get('Reply-To') || $head->get('From') || $head->get('Sender');
  chomp $From;
  
  #Pull apart the subject line
  $Subject = $head->get('Subject');
  chomp $Subject;

  if ($Subject =~ s/\[$rt::rtname \#(\d+)\]//i) {
    $TicketId = $1;
  }
  
  
  
  use RT::Ticket;
  
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
      $Ticket->Create ( Queue => $Queue,
			Area => $Area,
			Requestors => $From,
			Subject => $Subject,
			Attachment => $entity
		      );
    
  }

    #If the message applies to an existing ticket

    #   If the message contains commands, execute them
    
    #   If the mail message is a comment, add a comment.

    
    #   If the message is correspondence, add it to the ticket







}  

sub CheckForLoops {
  my $head = shift;

  #If this instance of RT sent it our, we don't want to take it in
  my $RTLoop = $head->get("X-RT-Loop-Prevention");
  if ($RTLoop eq "$RT::rtname") {
    return(1);
  }
 
  #if it's from a postmaster or mailer daemon, it's likely a bounce.
  my $From = $head->get("From");
  
  if (($From =~ /^mailer-daemon/i) or
      ($From =~ /^postmaster/i)){
    return (1);
  }

  #If it claims to be bulk mail, discard it
  my $Precedence = $head->get("Precedence");

  if ($Precedence =~ /^bulk/i) {
    return (1);
  }
}

1;

# (c) 1996-2000 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL

package RT::Interface::Email;
use RT::Ticket;
my $FromObj;
# {{{ sub activate 
sub activate  {
  my $Queue  = $ARGV[0];
  my $Action = $ARGV[1];
  my $Area   = $ARGV[2];
  
  my ($From, $TicketId, $Subject);
  
  if (!defined ($Queue)) { $Queue = "general";}
  if (!defined ($Action)) { $Action = "correspond";}
  
  $RT::Logger->log(message=>"RT Mailgate started up ($Queue/$Action)", level=>'info');

  my $time = time;

  #TODO: This should be pid + time + a random # for safety.
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
 
  #Now we've got a parsed mime object. 

 
  # Get the head, a MIME::Head:
  $head = $entity->head;

  # TODO - information about the charset is lost here!
  $head->decode;

  #Pull apart the subject line
  $Subject = $head->get('Subject') || "";
  chomp $Subject;

  #Lets check for mail loops of various sorts.
  my ($IsALoop, $LoopMsg) = &CheckForLoops($head);
  
  if ($IsALoop) {
    $RT::Logger->log(level=>$IsALoop>1 ? 'critical' : 'error',
		     message=>$LoopMsg);
    $head->add('RT-Mailing-Loop-Alarm', $LoopMsg)
  }
  
  if ($Subject =~ s/\[$RT::rtname \#(\d+)\]//i) {
    $TicketId = $1;
    #print STDERR "Got a ticket id: $TicketId\n";
  }

  
  my $CurrentUser = &GetCurrentUser($head);

  #print STDERR "User is $CurrentUser\n"; 
  #If the message doesn't reference a ticket #, create a new ticket
  if (!defined($TicketId) && $Action ne 'action') {
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
			Requestor => $CurrentUser,
			RequestorEmail => $FromObj->address,
			MIMEObj => $entity
		      );
   #print "id/trans/err:  $id $Transaction $ErrStr\n"; 
  }
  else {
    # If we have a ticketid

    if ($Action =~ /comment/i){
       #print "Action is $Action\n";
      my $Ticket = new RT::Ticket($CurrentUser);
      $Ticket->Load($TicketId) || die "Could not load ticket";
      $Ticket->Open; # Reopening it, if necessary
      # TODO: better error handling
      $Ticket->Comment(MIMEObj=>$entity);
    }
    
    
    #   If the message is correspondence, add it to the ticket
    elsif ($Action =~ /correspond/) {
      #print STDERR "Action is correspond\n"; 
      my $Ticket = RT::Ticket->new($CurrentUser);
      $Ticket->Load($TicketId);
	#	print STDERR "Ticket loaded\n";
      $Ticket->Open; # Reopening it, if necessary
      #TODO: Check for error conditions
      $Ticket->Correspond(MIMEObj => $entity);
   	#print STDERR "ticket correspond done\n"; 
	}
     else { 
	#TODO: Send a warning
	die "Unknown action type: $Action\n"
	    unless $Action eq "action";
     }
  }
  
  # If the message contains commands, execute them
  
  # I'm allowing people to put in stuff in the mail headers here,
  # with the header key "RT-Command":
  
  my $commands=$entity->head->get('RT-Command');
  my @commands=(defined $commands ? ( ref $commands ? @$commands : $commands ) : ());
  
  # TODO: pull out "%RT " commands from the message body and put
  # them in commands
  
  # TODO: Handle all commands
  
  # TODO: The sender of the mail must be notificated about all %RT
  # commands that has been executed, as well as all %RT commands
  # that couldn't be processed.  I'll just use "die" for errors as
  # for now.
  
  for (@commands) {
      next if /^$/;
      chomp;
      $RT::Logger->log(message=>"Action requested through email: $_", level=>'info');
      my ($command, $arguments)=/^(?:\s*)((?:\w|-)+)(?: (.*))?$/
	  or die "syntax error ($_)";
      if ($command =~ /^(Un)?[Ll]ink$/) {
	  if ($1) {
	      warn "Unlink not implemented yet: $_";
	      next;
	  }
	  my ($from, $typ, $to)=($arguments =~ m|^(.+?)(?:\s+)(\w+)(?:\s+)(.+?)$|)
	      or die "syntax error in link command ($arguments)";
	  my $dir='F';
	  # dirty? yes. how to fix?
	  $TicketId=RT::Link::_IsLocal(undef, $from);
	  if (!$TicketId) {
	      $dir='T';
	      $TicketId=RT::Link::_IsLocal(undef, $to);
	      warn $TicketId;
	  }
	  if (!$TicketId) {
	      die "Links can only be done at tickets";
	  }
	  my $Ticket = new RT::Ticket($CurrentUser);
	  $Ticket->Load($TicketId) || die "Could not load ticket";
	  # dirty? yes. how to fix?
	  $Ticket->_NewLink(dir=>$dir,Target=>$to,Base=>$from,Type=>$typ);
	  $RT::Logger->log(level=>'info', 
			   message=>$CurrentUser->UserId." did a linking action by mail ($_)");
      } else {
	  die "unknown command $command : $_";
      }
  }
  
  #   If the mail message is a comment, add a comment.

  return(0);
}
# }}}

# {{{ sub CheckForLoops 
sub CheckForLoops  {
  my $head = shift;

  #If this instance of RT sent it our, we don't want to take it in
  my $RTLoop = $head->get("X-RT-Loop-Prevention") || "";
  if ($RTLoop eq "$RT::rtname") {
      return (2, "We received a mail from ourself!");
  }

  # TODO: We might not trap the rare case where RT instance A sends a mail
  # to RT instance B which sends a mail to ...
 
  #if it's from a postmaster or mailer daemon, it's likely a bounce.

  #TODO: better algorithms needed here - there is no standards for
  #bounces, so it's very difficult to separate them from anything
  #else.  At the other hand, the Return-To address is only ment to be
  #used as an error channel, we might want to put up a separate
  #Return-To address which is treated differently.

  #TODO: search through the whole email and find the right Ticket ID.
  my $From = $head->get("From") || "";
  
  if (($From =~ /^mailer-daemon/i) or
      ($From =~ /^postmaster/i)){
    return (1, "This might be a bounce");
  }

  #If it claims to be bulk mail, discard it
  # TODO: We actually want to record it. but we can't send any mail
  # to anything that might possibly have generated the bounce.
  # perhaps it should get emailed to rt-owner

  my $Precedence = $head->get("Precedence") || "" ;

  if ($Precedence =~ /^(bulk|junk)/i) {
    return (1, "This is bulkmail");
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

  ($FromObj) = Mail::Address->parse($From) or die "Couldn't parse From-address";
  my $Name =  ($FromObj->phrase || $FromObj->comment || $FromObj->address);

  #Lets take the from and load a user object.

  use RT::CurrentUser;
  my $CurrentUser = RT::CurrentUser->new($FromObj->address);
  
  # One more try if we couldn't find that user
  $CurrentUser->Id || $CurrentUser->_Init($Name);
  
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
					   Comments => undef
					  );
    
    if (!$Val) {
      #TODO this should not just up and die. at the worst it should send mail.
      die $Message;
    }

    #TODO: Send the user a "welcome message" 

    ## Tobix: No, actually I think it's better to do it as suggested
    ## in [fsck 290].  Feed people with an URL in the Autoreply and/or
    ## the correspondance.  Those that are interessted in following a
    ## case or whatever, can just use the URL to gain insight in how
    ## to use (that) RT (instance).  Those that don't care don't have
    ## to care.

    #Load the new user object
    $CurrentUser->Load($FromObj->address);
  }
  return ($CurrentUser);
}
# }}}

1;

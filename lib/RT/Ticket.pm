# $Header$
# (c) 1996-2000 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL
#

package RT::Ticket;

use RT::Record;
@ISA= qw(RT::Record);

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $self->{'table'} = "tickets";
  $self->_Init(@_);
  return ($self);
}



sub create {
  my $self = shift;
  return($self->Create(@_));
}

sub Create {
  my $self = shift;
 
  my %args = (id => undef,
	      EffectiveId => undef,
	      Queue => undef,
	      Area => undef,
	      Alias => undef,
	      Requestors => undef,
	      Owner => undef,
	      Subject => undef,
	      InitialPriority => undef,
	      FinalPriority => undef,
	      Status => 'open',
	      TimeWorked => 0,
	      DateCreated => time(),
	      DateTold => 0,
	      DateActed => time(),
	      DateDue => 0,
	      Content => undef,
	      @_);
  
  my $id = $self->SUPER::Create(Id => $args{'id'},
				    EffectiveId => $args{'EffectiveId'},
				    Queue => $args{'Queue'},
				    Alias => $args{'Alias'},
				    Requestors => $args{'Requestors'},
				    Owner => $args{'Owner'},
				    Subject => $args{'Subject'},
				    InitialPriority => $args{'InitialPriority'},
				    FinalPriority => $args{'FinalPriority'},
				    Priority => $args{'InitialPriority'},
				    Status => $args{'Status'},
				    TimeWorked => $args{'TimeWorked'},
				    DateCreated => $args{'DateCreated'},
				    DateTold => $args{'DateTold'},
				    DateActed => $args{'DateActed'},
				    DateDue => $args{'DateDue'}
			       );
  
  #TODO: ADD A TRANSACTION
  #TODO: DO SOMETHING WITH $args{'content'}

  #now that we have an Id, set the effective Id, if we didn't come in with one.
  if ($self->EffectiveId == 0 ) {
    print "Setting Eid";
    $self->SetEffectiveId($id);
  }
  return($self->Id, $ErrStr);
  
}

sub SetQueue {
  my $self = shift;
  my ($NewQueue, $NewQueueObj);
  
  if ($NewQueue = shift) {
    #TODO Check to make sure this isn't the current queue.
    #TODO this will clobber the old queue definition. 
      
    use RT::Queue;
    $NewQueueObj = RT::Queue->new($self->CurrentUser);
    
    if (!$NewQueueObj->Load($NewQueue)) {
      return (0, "That queue does not exist");
    }
    elsif (!$NewQueueObj->CreatePermitted) {
      return (0, "You may not create requests in that queue.");
    }
    elsif (!$NewQueueObj->ModifyPermitted($self->Owner)) {
      $self->Untake();
    }
    
    #TODO: IF THE AREA DOESN'T EXIST IN THE NEW QUEUE, YANK IT.    
    else {
      $self->_Set('Queue', $NewQueueObj->Id());
    }
  }
  else {
    return ("No queue specified");
  }
}

sub Queue {
  my $self = shift;
  if (!$self->{'queue'})  {
    require RT::Queue;
    $self->{'queue'} = RT::Queue->new($self->CurrentUser);
    $self->{'queue'}->load($self->_Value('Queue'));
  }
  return ($self->{'queue'});
}





#
# Routines dealing with ownership
#

sub Owner {
  my $self = shift;
  #If it's unowned, return undef
  if (!$self->_Value('Owner')) {
    return(undef);
  }
  #If it's got an owner
  elsif (!$self->{'owner'})  {
    require RT::User;
    $self->{'owner'} = RT::User->new($self->CurrentUser);
    $self->{'owner'}->Load($self->_Value('Owner'));
    
    
  }
  
  #Return the owner object
  return ($self->{'owner'});
}


sub Take {
  my $self=shift;
 my ($package, $filename, $line) = caller;
  print STDERR "RT::Ticket->Take called from $package, line $line with arguments (",@_,")\n";
  print STDERR "Taking ".$self->CurrentUser->Id."\n";
  return($self->SetOwner($self->CurrentUser->Id));
}

sub Untake {
  my $self=shift;
  return($self->SetOwner(""));
}


sub Steal {
  my $self = shift;
  
  if (!$self->ModifyPermitted){
    return ("Permission Denied");
  }
  elsif ($self->Owner->Id eq $self->CurrentUser->Id ) {
    return ("You already own this ticket"); 
  }
  else {
    # TODO: Send a "This ticket was stolen from you" alert
    return($self->_Set('owner',$self->CurrentUser->Id));
  }
  
  
}
sub SetOwner {
  my $self = shift;
  my $NewOwner = shift;
  my ($NewOwnerObj);

  #TODO this routine dies when: we're trying to give something away
  #TODO this routine dies when: we're trying to steal something


  use RT::User;
  $NewOwnerObj = RT::User->new($self->CurrentUser);
  
  if (!$NewOwnerObj->Load($NewOwner)) {
    return (0, "That user does not exist");
  }
  
  #If thie ticket has an owner and it's not the current user
  #TODO:this breaks stealing.
  
  if (($self->Owner) and ($self->CurrentUser->Id ne $self->Owner->Id())) {
    return("You can only reassign tickets that you own or that are unowned");
  }
  #If we've specified a new owner and that user can't modify the ticket
  elsif (($NewOwner) and (!$self->ModifyPermitted($NewOwnerObj->Id))) {
    return ("That user may not own requests in that queue")
  }
  

  #If the ticket has an owner and it's the new owner, we don't need
  #To do anything
  elsif (($self->Owner) and ($NewOwnerObj->Id eq $self->Owner->Id)) {
    return("That user already owns that request");
  }
  
  
  #  elsif ( #TODO $new_owner doesn't have queue perms ) {
  #	return ("That user doesn't have permission to modify this request");
  #	}
  
  else {
    #TODO
    #If we're giving the request to someone other than $self->CurrentUser
    #send them mail
  }
  $self->_Set('Owner',$NewOwnerObj->Id);  
}


#
# Routines dealing with status
#

sub SetStatus { 
  my $self = shift;
  if (@_) {
   my $status = shift;
 }
  else {
    my $status = undef;
  }
  
  if (($status) and ($status != 'open') and ($status != 'stalled') and 
      ($status != 'resolved') and ($status != 'dead') ) {
    return ("That status is not valid.");
  }
  
  if ($status == 'resolved') {

    #&open_parents($in_serial_num, $in_current_user) || $transaction_num=0; 
    #TODO: we need to check for open parents.
  }
  
  $self->_Set('status',@_);
}

sub Kill {
  my $self = shift;
  die "Ticket::Kill Unimplemented";
}

sub Stall {
  my $self = shift;
  return ($Self->SetStatus('stalled'));
  
}

sub Open {
  my $self = shift;
  return ($Self->SetStatus('open'));
}

sub Resolve {
  my $self = shift;
  return ($Self->SetStatus('resolved'));
}


#
# Routines dealing with requestor metadata
#
sub Notify {
  my $self = shift;
  return ($self->DateTold(time()));
}
  
sub SinceTold {
  my $self = shift;
  return ("Ticket->SinceTold unimplemented");
}
sub Age {
  my $self = shift;
  return("Ticket->Age unimplemented\n");
}

#
# Routines dealing with ticket relations
#

sub Merge {
  my $self = shift;
  my $MergeInto = shift;
  
  #Make sure this user can modify this ticket
  #Load $MergeInto as Ticket $Target
  #If the $Target doesn't exist, return an area
  #Make sure this user can modify $Target
  #If I have an owner and the $Target doesn't, set them on the target
  #If this ticket has an area and the $Target doesn't, set them on the target
  #If I have a Due Date and it's before the $Target's due date, set the $Target's due date
  #Merge the requestor lists
  #Set my effective_sn to the $Target's Effective SN.
  #Set all my transactions Effective_SN to the $Target's Effective_Sn
}  

# 
# Routines dealing with correspondence/comments
#

#takes a subject, a cc list, a bcc list
sub Comment {
  my $self = shift;
  
  my %args = ( subject => $self->Subject,
	       sender => $self->CurrentUser->EmailAddress,
	       cc => undef,
	       bcc => undef,
	       time_taken => 0,
	       content => undef,
	       @_ );
  
  if ($args{'subject'} !~ /\[(\s*)comment(\s*)\]/i) {
    $args{'subject'} .= ' [comment]';
  }
  #Record the correspondence (write the transaction)
  $self->_NewTransaction('comment',$args{'subject'},$args{'time_taken'},
			 $args{'content'});
  
  #Send a copy to the queue members, if necessary
  
  #Send a copy to the owner if necesary
  
  if ($args{'cc'} || $args{'bcc'} ) {
    #send a copy of the correspondence to the CC list and BCC list
  }
  
  return ("This correspondence has been recorded");
}

sub Correspond {
  my $self = shift;
    my %args = ( subject => $self->Subject,
		 sender => $self->CurrentUser->EmailAddress,
		 cc => undef,
		 bcc => undef,
		 time_taken => 0,
		 content => undef,
		 @_ );

  
  #Record the correspondence (write the transaction)
  $self->_NewTransaction('correspondence',$args{'subject'},$args{'time_taken'},$args{'content'});
  
  #Send a copy to the queue members, if necessary
  
  #Send a copy to the owner if necesary
  
  if (!$self->IsRequestor($args{'sender'})) {
    #Send a copy of the correspondence to the user
    #Flip the date_told to now
    #If we've sent the correspondence to the user, flip the note the date_told
  }
  
  elsif ($args{'cc'} || $args{'bcc'} ) {
    #send a copy of the correspondence to the CC list and BCC list
  }
  
  return ("This correspondence has been recorded.");
}


#
# Get the right transactions object. 
#

sub Transactions {
  my $self = shift;
  if (!$self->{'transactions'}) {
    $self->{'transactions'} = new RT::Transactions($self->CurrentUser);
    $self->{'transactions'}->Limit( FIELD => 'effective_ticket',
                                    VALUE => $self->id() );
  }
  return($self->{'transactions'});
}




#TODO KEYWORDS IS NOT YET IMPLEMENTEd
sub Keywords {
  my $self = shift;
  #TODO Implement
  return($self->{'article_keys'});
}

sub NewKeyword {
  my $self = shift;
  my $keyid = shift;
  
    my ($keyword);
  
  $keyword = new RT::Article::Keyword;
  return($keyword->create( keyword => "$keyid",
			   article => $self->id));
  
  #reset the keyword listing...
  $self->{'article_keys'} = undef;
  
  return();
  
}


#
#TODO: Links is not yet implemented
#
sub Links {
  my $self= shift;
  
  if (! $self->{'pointer_to_links_object'}) {
#    $self->{'pointer_to_links_object'} = new RT::Article::URLs;
#    $self->{'pointer_to_links_object'}->Limit(FIELD => 'article',
#					      VALUE => $self->id);
  }
  return($self->{'pointer_to_links_object'});
}

sub NewLink {
  my $self = shift;
  my %args = ( url => '',
	       title => '',
	       comment => '',
	       @_ );
 
  my $link = new RT::Article::URL;
  $id = $link->create( url => $args{'url'},
		       title => $args{'title'},
		       comment => $args{'comment'},
		       article => $self->id()
		     );
    print STDERR "made new create\n";
 return ($id);
}

 

#
# UTILITY METHODS
# 
    
sub IsRequestor {
  my $self = shift;
  my $username = shift;
  
  #if the requestors string contains the username

  if ($self->Requestor() =~ /\$username/) {

    return(1);
  }
  else {
    return(undef);
  }
};


#
# PRIVATE UTILITY METHODS
#

sub _NewTransaction {
  my $self = shift;
  my $type = shift;
  my $data = shift;
  my $time_taken = shift;
  my $content = shift;
  
  use RT::Transaction;
  print STDERR "My effective id is ".$self->Id."\n";
  my $trans = new RT::Transaction($self->CurrentUser);
  $trans->Create( Ticket => $self->EffectiveId,
		  TimeTaken => "$time_taken",
		  Type => "$type",
		  Data => "$data",
		  Content => "$content"
		);
  $self->_UpdateTimeTaken($time_taken); 
}

sub _Accessible {

  my $self = shift;  
  my %Cols = (
	      EffectiveId => 'read/write',
	      Queue => 'read/write',
	      Alias => 'read/write',
	      Requestors => 'read/write',
	      Owner => 'read/write',
	      Subject => 'read/write',
	      InitialPriority => 'read',
	      FinalPriority => 'read/write',
	      Priority => 'read/write',
	      Status => 'read/write',
	      TimeWorked => 'read',
	      DateCreated => 'read',
	      DateTold => 'read/write',
	      DateActed => 'read/write',
	      DateDue => 'read/write'
	     );
  return($self->SUPER::_Accessible(@_, %Cols));
}

sub _UpdateTimeTaken {
  my $self = shift;
  warn("_UpdateTimeTaken not implemented yet.");
}

sub _UpdateDateActed {
  my $self = shift;
  $self->SUPER::_Set('DateActed',time);
}





#This overrides RT::Record
sub _Set {
  my $self = shift;
  my (@args);
  #if the user is trying to modify the record
  if ($self->ModifyPermitted) {
    
    my $field = shift;
    my $value = shift;
    my $time_taken = shift if @_;
    
    print STDERR "Setting $field to $value\n";
    #TODO: this doesn't work, iirc.
    
    my $content = @_;
    
    #record what's being done in the transaction
    
    $self->_NewTransaction ($field, $value, $time_taken, $content);
    $self->_UpdateDateActed;
    $self->SUPER::_Set($field, $value);
    #Figure out where to send mail
  }
  
  else {
    return (0, "Permission Denied");
  }
}

#
#ACCESS CONTROL
# 
sub DisplayPermitted {
  my $self = shift;
  my $actor = shift;
  
  if (!$actor) {
    #my $actor = $self->CurrentUser->Id();
  }
  if (1) {
    #  if ($self->Queue->DisplayPermitted($actor)) {
      return(1);
  }
  else {
    #if it's not permitted,
    return(0);
  }
}

sub ModifyPermitted {
  my $self = shift;
  my $actor = shift;
  if (!$actor) {
   # my $actor = $self->CurrentUser->Id();
  }
  if ($self->Queue->ModifyPermitted($actor)) {
    
    return(1);
  }
  else {
    #if it's not permitted,
    return(0);
  }
}

sub AdminPermitted {
  my $self = shift;
  my $actor = shift;
  if (!$actor) {
   # my $actor = $self->CurrentUser->Id();
  }


  if ($self->Queue->AdminPermitted($actor)) {
    
    return(1);
  }
  else {
    #if it's not permitted,
    return(0);
  }
}

1;



# $Header$
# (c) 1996-1999 Jesse Vincent <jesse@fsck.com>
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
  $self->{'user'} = shift;
  $self->_init(@_);
  return ($self);
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

sub Create {
  my $self = shift;
  return($self->create(@_);)
}

sub create {
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
  
  my $ErrStr = $self->SUPER::Create(Id => $args{'id'},
				EffectiveId => $args{'EffectiveId'},
				Queue => $args{'Queue'},
				Area => $args{'Area'},
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
    elsif (!$NewQueueObj->Create_Permitted) {
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
    #if they're not setting the queueid, just return a queue object
  }
}

sub GetQueue {
  my $self = shift;
  if (!$self->{'queue'})  {
    require RT::Queue;
    $self->{'queue'} = RT::Queue->new($self->CurrentUser);
    $self->{'queue'}->load($self->_Value('Queue'));
  }
  return ($self->{'queue'});
}




sub Take {
  my $self=shift;
  $self->SetOwner($self->CurrentUser);
}

sub Untake {
  my $self=shift;
  $self->SetOwner("");
}


sub GetOwner {
  my $self = shift;
  if (!$self->{'owner'})  {
    require RT::User;
    $self->{'owner'} = RT::User->new($self->CurrentUser);
    $self->{'owner'}->load($self->_Value('Owner'));
  }
  return ($self->{'owner'});
}

sub SetOwner {
  my $self = shift;
  my $NewOwner = shift;
  my ($NewOwnerObj);
  use RT::User;
  
  my $NewOwnerObj = RT::User->new($self->CurrentUser);
  
  if (!$NewOwnerObj->Load($NewOwner)) {
    return (0, "That user does not exist");
  }
  
  #new owner can be blank or the name of a new owner.
  if (($NewOwner != '') and (!$self->Modify_Permitted($NewOwner))) {
    return ("That user may not own requests in that queue")
  }
  
  elsif ($NewOwnerObj->Id eq $self->GetOwner->Id) {
    return("That user already owns that request");
  }
  elsif (($self->CurrentUser ne $self->GetOwner()) and ($self->GetOwner != '')) {
    return("You can only reassign tickets that you own or that are unowned");
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



sub Steal {
  my $self = shift;
  
  if (!$self->CanManipulate($self->CurrentUser)){
    return ("Permission Denied");
  }
  elsif ($self->GetOwner == $self->CurrentUser ) {
    return ("You already own this ticket"); 
  }
  
  else {
    # TODO: Send a "This ticket was stolen from you" alert
    return($self->_set_and_return('owner',$self->CurrentUser));
  }
  
  
}

sub Status { 
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
  
  $self->_set_and_return('status',@_);
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



#takes a subject, a cc list, a bcc list

sub Comment {
  my $self = shift;
  
  my %args = ( subject => $self->Subject,
	       sender => $self->CurrentUser,
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

sub NewCorrespondence {
  my $self = shift;
    my %args = ( subject => $self->Subject,
		 sender => $self->CurrentUser,
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



sub _NewTransaction {
  my $self = shift;
  my $type = shift;
  my $data = shift;
  my $time_taken = shift;
  my $content = shift;


  my $trans = new RT::Transaction($self->CurrentUser);
  $trans->Create( Ticket => $self->EffectiveSN,
		  TimeTaken => "$time_taken",
		  Type => "$type",
		  Data => "$data",
		  Content => "$content"
		);
  $self->_UpdateTimeTaken($time_taken); 
}

sub Transactions {
  my $self = shift;
  if (!$self->{'transactions'}) {
    $self->{'transactions'} = new RT::Transactions($self->CurrentUser);
    $self->{'transactions'}->Limit( FIELD => 'effective_ticket',
                                    VALUE => $self->id() );
  }
  return($self->{'transactions'});
}




#KEYWORDS IS NOT YET IMPLEMENTEd
sub Keywords {
  my $self = shift;
  if (!$self->{'article_keys'}) {
    $self->{'article_keys'} = new RT::Article::Keywords;
    $self->{'article_keys'}->Limit( FIELD => 'article',
				    VALUE => $self->id() );
  }
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


#LINKS IS NOT YET IMPLEMENTED
sub Links {
  my $self= shift;
  
  if (! $self->{'pointer_to_links_object'}) {
    $self->{'pointer_to_links_object'} = new RT::Article::URLs;
    $self->{'pointer_to_links_object'}->Limit(FIELD => 'article',
					      VALUE => $self->id);
  }
  
  return($self->{'pointer_to_links_object'});
}

sub NewLink {
  my $self = shift;
  my %args = ( url => '',
	       title => '',
	       comment => '',
	       @_
	     );

 
  print STDERR "in article->newlink\n";
  
  my $link = new RT::Article::URL;
  print STDERR "made new link\n";
  
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


sub _UpdateTimeTaken {
  my $self = shift;
  warn("_UpdateTimeTaken not implemented yet.");
  
}

sub _UpdateDateActed {
  my $self = shift;
  $self->SUPER::_set_and_return('date_acted',time);
}
sub _set_and_return {
  my $self = shift;
  my (@args);
  #if the user is trying to display only 
  if (@_ == undef) {
    
    if ($self->Display_Permitted) {
      #if the user doesn't have display permission, return an error
      $self->SUPER::_set_and_return($field);
    }
    else {
      return(0, "Permission Denied");
    }
  }
  #if the user is trying to modify the record
  


  if ($self->Modify_Permitted) {
 
    my $field = shift;
    my $value = shift;
    my $time_taken = shift if @_;
    
    #TODO: this doesn't work, iirc.
    
    my $content = @_;
    
    
    #record what's being done in the transaction
    
    $self->_NewTransaction ($field, $value, $time_taken, $content);
    
    $self->_UpdateDateActed;
  
    $self->SUPER::_set_and_return($field, @_);
    
    #Figure out where to send mail
    
    
    
  }
  
  else {
    return (0, "Permission Denied");
  }
}


#
# Actions that don't have a corresponding display component
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
  
  #Give the $Target my requestors
  #    $old_requestors=$req[$in_serial_num]{'requestors'};
#    $new_requestors=$req[$in_merge_into]{'requestors'};
#    @requestors_list=split(/,/ , $old_requestors . ", $new_requestors");
#    foreach $user (@requestors_list) {
#	$user =~ s/\s//g;
#	$user .= "\@$rt::domain" if ! ($user =~ /\@/);
#	$requestors{$user} = 1;
#    }
#    $new_requestors = join(",",sort keys %requestors);
    
  #Set my effective_sn to the $Target's Effective SN.

  #Set all my transactions Effective_SN to the $Target's Effective_Sn
  
  

}  

#
#ACCESS CONTROL
# 
sub DisplayPermitted {
  my $self = shift;

  my $actor = shift;
  if (!$actor) {
    my $actor = $self->CurrentUser;
  }
  if ($self->Queue->DisplayPermitted($actor)) {
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
    my $actor = $self->CurrentUser;
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
    my $actor = $self->CurrentUser;
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



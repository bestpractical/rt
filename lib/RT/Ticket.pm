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
  $self->{'table'} = "Tickets";
  $self->_Init(@_);
  return ($self);
}

sub Create {
  my $self = shift;
  
  my %args = (id => undef,
	      EffectiveId => undef,
	      Queue => undef,
	      QueueTag => undef,
	      Requestor => undef,
	      Alias => undef,
	      Type => undef,
	      Owner => undef,
	      Subject => undef,
	      InitialPriority => undef,
	      FinalPriority => undef,
	      Status => 'open',
	      TimeWorked => 0,
	      Created => time(),
	      Told => 0,
	      Due => 0,
	      MIMEEntity => undef,
	     
	      @_);

  #TODO Load queue defaults

  if (!$args{'Queue'} && $args{'QueueTag'}) {
      $q=RT::Queue->new($self->{user});
      $q->LoadByCol("QueueId", $args{'QueueTag'});
      $args{'Queue'}=$q->id;
  }
  
  my $id = $self->SUPER::Create(Id => $args{'id'},
				EffectiveId => $args{'EffectiveId'},
				Queue => $args{'Queue'},
				Alias => $args{'Alias'},
				Owner => $args{'Owner'},
				Subject => $args{'Subject'},
				InitialPriority => $args{'InitialPriority'},
				FinalPriority => $args{'FinalPriority'},
				Priority => $args{'InitialPriority'},
				Status => $args{'Status'},
				TimeWorked => $args{'TimeWorked'},
				Created => undef,
				Told => $args{'Told'},
				Due => $args{'Due'}
			       );
  #Load 'er up.
  $self->Load($id);
  #Now that we know the self
  $self->SUPER::_Set("EffectiveId",$id);
  
  if (defined $args{'MIMEEntity'}) {
    my $head = $args{'MIMEEntity'}->head;
    
    require Mail::Address;
    require RT::Watcher;

    #Add the requestor to the list of watchers
    my $FromLine = $head->get('Reply-To') || $head->get('From') || $head->get('Sender');
    my @From = Mail::Address->parse($FromLine);
    
    foreach $From (@From) {
#      print "From is $From\n";
      my $Watcher = RT::Watcher->new($self->CurrentUser);
      
      $self->AddWatcher ( Email => $From->address,
			  Type => "Requestor");
    }
    
    my @Cc = Mail::Address->parse($head->get('Cc'));
    foreach $Cc (@Cc) {
      $self->AddWatcher ( Email => $Cc->address,
			  Type => "Cc");
    }

    # Should we store this at all?  There might be a point keeping
    # blind cc's secret.
    my @Bcc = Mail::Address->parse($head->get('Bcc'));
    foreach $Bcc (@Bcc) {
      $self->AddWatcher ( Email => $Bcc->address,
			  Type => "Bcc");
    }
    
  }
  #Add a transaction for the create
  my $Trans = $self->_NewTransaction(Type => "Create",
				     TimeTaken => 0, 
				     MIMEEntity=>$args{'MIMEEntity'});
  
  
  return($self->Id, $Trans, $ErrStr);
  
}


#
# Routines dealing with interested parties.
#


sub AddWatcher {
  my $self = shift;
  my %args = ( Value => $self->Id(),
	       Email => undef,
	       Type => undef,
	       Scope => 'Ticket',
	       @_ );
  
  require RT::Watcher;
  my $Watcher = new RT::Watcher ($self->CurrentUser);
  $Watcher->Create(%args);
  
}
	
sub DeleteWatcher {
  my $self = shift;
  my $email = shift;
  
  my ($Watcher);
  
  while ($Watcher = $self->Watchers->Next) {
    if ($Watcher->Email =~ /$email/) {
      $self->_NewTransaction ( Type => 'DelWatcher',
			       OldValue => $Watcher->Email,
			       Data => $Watcher->Type,
			     );
      $Watcher->Delete();
    }
  }
}


sub Watchers {
  my $self = shift;
  if (! defined ($self->{'Watchers'}) 
      || $self->{'Watchers'}->{is_modified}) {
    require RT::Watchers;
    $self->{'Watchers'} =RT::Watchers->new($self->CurrentUser);
    $self->{'Watchers'}->LimitToTicket($self->id);
  }
  return($self->{'Watchers'});
  
}

sub Requestors {
  my $self = shift;
  if (! defined ($self->{'Requestors'})) {
    require RT::Watchers;
    $self->{'Requestors'} = RT::Watchers->new($self->CurrentUser);
    $self->{'Requestors'}->LimitToTicket($self->id);
    $self->{'Requestors'}->LimitToRequestors();
  }
  return($self->{'Requestors'});
  
}
sub RequestorsAsString {
  my $self = shift;
  if (!defined $self->{'RequestorsAsString'}) {
    $self->{'RequestorsAsString'} = "";
    while (my $requestor = $self->Requestors->Next) {
      $self->{'RequestorsAsString'} .= $requestor->Email.", ";    
 

    }

    $self->{'RequestorsAsString'} =~ s/, $//;
    
#    print STDERR "R as S is ". $self->{'RequestorsAsString'} ."\n";
  }
  

  return ( $self->{'RequestorsAsString'});
  
}

sub Cc {
  my $self = shift;
  if (! defined ($self->{'Cc'})) {
    require RT::Watchers;
    $self->{'Cc'} = new RT::Watchers ($self->CurrentUser);
    $self->{'Cc'}->LimitToTicket($self->id);
    $self->{'Cc'}->LimitToCc();
  }
  return($self->{'Cc'});
  
}

sub CcAsString {
  my $self = shift;
  if (!defined $self->{'CcAsString'}) {
    $self->{'CcAsString'} = "";
    while ($requestor = $self->Cc->Next) {
      $self->{'CcAsString'} .= $requestor->Email .", ";
      
    }
  }
  $self->{'CcAsString'} =~ s/, $//;
  return ( $self->{'CcAsString'});
    
    
  
}
sub Bcc {
  my $self = shift;
  if (! defined ($self->{'Bcc'})) {
    require RT::Watchers;
    $self->{'Bcc'} = new RT::Watchers ($self->CurrentUser);
    $self->{'Bcc'}->LimitToTicket($self->id);
    $self->{'Bcc'}->LimitToBcc();
  }
  return($self->{'Bcc'});
  
}
sub BccAsString {
  my $self = shift;
  if (!defined $self->{'BccAsString'}) {
    $self->{'BccAsString'} = "";
    while (my $requestor = $self->Bcc->Next) {
      $self->{'BccAsString'} .= $requestor->Email .", ";
    }
    $self->{'BccAsString'} =~ s/, $//;
  }
  return ( $self->{'BccAsString'});
  
    
  
}
  

#
#

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
      return($self->_Set('Queue', $NewQueueObj->Id()));
    }
  }
  else {
    return (0,"No queue specified");
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
	
  #If the owner object ain't loaded yet
  if (! defined $self->{'owner'})  {
    require RT::User;
    $self->{'owner'} = new RT::User ($self->CurrentUser);
    if ($self->_Value('Owner') != undef ) {
	print STDERR "Owner is '". $self->_Value('Owner')."'\n";
     $self->{'owner'}->Load($self->_Value('Owner'));

    }
  }
  
  #TODO It feels unwise, but we're returning an empty owner
  # object rather than undef.
  
  #Return the owner object
  return ($self->{'owner'});
}


sub Take {
  my $self = shift;
  return($self->SetOwner($self->CurrentUser->Id));
}

sub Untake {
  my $self = shift;
  return($self->SetOwner(""));
}


sub Steal {
  my $self = shift;
  
  if (!$self->ModifyPermitted){
    return (0,"Permission Denied");
  }
  elsif ($self->Owner->Id eq $self->CurrentUser->Id ) {
    return (0,"You already own this ticket"); 
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


  require RT::User;
  $NewOwnerObj = RT::User->new($self->CurrentUser);
  
  if (!$NewOwnerObj->Load($NewOwner)) {
    print STDERR "That user does not exist\n";
    return (0, "That user does not exist");
  }
  
  
  #If thie ticket has an owner and it's not the current user
  #TODO:this breaks stealing.
  

  if (($self->Owner->Id != 0 ) and ($self->CurrentUser->Id ne $self->Owner->Id())) {
    print STDERR  "You can only reassign tickets that you own or that are unowned\n";
    return(0, "You can only reassign tickets that you own or that are unowned");
  }
  #If we've specified a new owner and that user can't modify the ticket
  elsif (($NewOwner) and (!$self->ModifyPermitted($NewOwnerObj->Id))) {
    return (0, "That user may not own requests in that queue")
  }
  
  
  #If the ticket has an owner and it's the new owner, we don't need
  #To do anything
  elsif (($self->Owner) and ($NewOwnerObj->Id eq $self->Owner->Id)) {
    return(0, "That user already owns that request");
  }
  
  
  #  elsif ( #TODO $new_owner doesn't have queue perms ) {
  #	return ("That user doesn't have permission to modify this request");
  #	}
  
  else {
    #TODO
    #If we're giving the request to someone other than $self->CurrentUser
    #send them mail
  }

  return($self->_Set('Owner',$NewOwnerObj->Id));  
}


#
# Routines dealing with status
#

sub SetStatus { 
  my $self = shift;
   my $status = shift;
  
  if (($status ne 'open') and ($status ne 'stalled') and 
      ($status ne 'resolved') and ($status ne 'dead') ) {
    return (0,"That status is not valid.");
  }
  
  if ($status == 'resolved') {

    #&open_parents($in_serial_num, $in_current_user) || $transaction_num=0; 
    #TODO: we need to check for open parents.
  }
  
  return($self->_Set('status',@_));
}

sub Kill {
  my $self = shift;
  die "Ticket::Kill Unimplemented";
}

sub Stall {
  my $self = shift;
  return ($self->SetStatus('stalled'));
  
}

sub Open {
  my $self = shift;
  return ($self->SetStatus('open'));
}

sub Resolve {
  my $self = shift;
  return ($self->SetStatus('resolved'));
}



#
# Date printing routines
#


sub DueAsString {
  my $self = shift;
  if ($self->Due) {
    return (scalar(localtime($self->Due)));
  }
  else {
    return("Never");
  }
}

sub CreatedAsString {
  my $self = shift;
  return (scalar(localtime($self->Created)));
}

sub ToldAsString {
  my $self = shift;
  if ($self->Due) {
    return (scalar(localtime($self->Told)));
  }
  else {
    return("Never");
  }
}


sub LastUpdatedAsString {
  my $self = shift;
  if ($self->Due) {
    return (scalar(localtime($self->LastUpdated)));
  }
  else {
    return("Never");
  }
}

#
# Routines dealing with requestor metadata
#


sub Notify {
  my $self = shift;
  return ($self->_Set("Told",time()));
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
  
  #Make sure this ticket object thinks its merged

  return ($TransactionObj, "Merge Successful");
}  



# 
# Routines dealing with correspondence/comments
#

#takes a subject, a cc list, a bcc list
sub Comment {
  my $self = shift;
  
  # MIMEObj here ... and MIMEEntity somewhere else ... it would have been better
  # to be consistant.  But hey - it works!  We'll just leave it here as for now.
  # -- TobiX
  my %args = ( MIMEObj => undef,
	       TimeTaken => 0,
	       @_ );
    

  #For ease of processing
  my $MIME = $args{'MIMEObj'};

  #Record the correspondence (write the transaction)
  my $Trans = $self->_NewTransaction( Type => 'Comment',
				      Data => $MIME->head->get('subject'),
				      # Wouldn't it be better to just add %args here?
				      # -- TobiX
				      TimeTaken => $args{'TimeTaken'},
				      MIMEEntity => $MIME
				    );

  if ($args{'cc'} || $args{'bcc'} ) {
      #send a copy of the correspondence to the CC list and BCC list
      warn "Stub!";
  }
  
  return ($Trans, "The comment has been recorded");
}

sub Correspond {
  my $self = shift;
    my %args = ( MIMEObj => undef,
		 TimeTaken => 0,
		 @_ );
  
  #For ease of processing
  my $MIME = $args{'MIMEObj'};
  
  if (! defined ($MIME)) {
    return(0,"No correspondence attached");
  }

  #Record the correspondence (write the transaction)
  my $Trans = $self->_NewTransaction(Type => 'Correspond',
			 Data => $MIME->head->get('subject'),
			 TimeTaken => $args{'TimeTaken'},
			 MIMEEntity=> $MIME     
			);

  # Probably this ones will be a part of the MIMEEntity above, and not
  # parts of %args.  In the Scrips, a new MIMEEntity is created, so
  # the (B)CCs won't be sent.  Maybe the SendEmail should be adjusted
  # to import those header fields?  At the other hand, with incoming
  # mail we can assume that Bccs and Ccs from the header is already
  # sent, so it's rather a bug in the cli that the ccs and bccs are in
  # the MIMEEntity instead of %args..

  if ($args{Bcc} || $args{Cc}) {
      warn "stub"
  }
  
  return ($Trans, "correspondence (probably) sent");
}


#
# Get the right transactions object. 
#

sub Transactions {
  my $self = shift;
  if (!$self->{'transactions'}) {
    use RT::Transactions;
    $self->{'transactions'} = RT::Transactions->new($self->CurrentUser);
    $self->{'transactions'}->Limit( FIELD => 'EffectiveTicket',
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
  my %args = (TimeTaken => 0,
	     Type => undef,
	     OldValue => undef,
	     NewValue => undef,
	     Data => undef,
	     Field => undef,
	     MIMEEntity => undef,
	     @_);
  
  
  require RT::Transaction;
  my $trans = new RT::Transaction($self->CurrentUser);
  $trans->Create( Ticket => $self->EffectiveId,
		  TimeTaken => $args{'TimeTaken'},
		  Type => $args{'Type'},
		  Data => $args{'Data'},
		  Field => $args{'Field'},
		  NewValue => $args{'NewValue'},
		  OldValue => $args{'OldValue'},
		  MIMEEntity => $args{'MIMEEntity'}
		);
  
  $self->_UpdateDateActed;
  
  if (defined $args{'TimeTaken'} ) {
    $self->_UpdateTimeTaken($TimeTaken); 
  }
  return($trans);
}

sub _Accessible {

  my $self = shift;  
  my %Cols = (
	      EffectiveId => 'read',
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
	      Created => 'read',
	      Told => 'read',
	      LastUpdated => 'read',
	      LastUpdatedBy => 'read',
	      Due => 'read/write'

	     );
  return($self->SUPER::_Accessible(@_, %Cols));
}

#This routine will increment the timeworked counter. it should
#only be called from _NewTransaction 
sub _UpdateTimeTaken {
  my $self = shift;
  my $Minutes = shift;
  my ($Total);
  
  $Total = $self->_Value("TimeWorked");
  $Total = ($Total || 0) + ($Minutes || 0);
  $self->SUPER::_Set("TimeWorked", $Total);
  return ($Total);
}

sub _UpdateDateActed {
  my $self = shift;
  $self->SUPER::_Set('LastUpdated',undef);
}





#This overrides RT::Record
sub _Set {
  my $self = shift;
  if (!$self->ModifyPermitted) {
        return (0, "Permission Denied");
  }
  else {
    #if the user is trying to modify the record
    
    my $Field = shift;
    my $Value = shift;
    my $TimeTaken = shift if @_;
    
    if (!defined $TimeTaken) {
      $TimeTaken = 0;
    }
    #record what's being done in the transaction
    $self->_NewTransaction (Type => "Set",
			    Field => "$Field",
			    NewValue => "$Value",
			    OldValue =>  $self->_Value("$Field"),
			    TimeTaken => $TimeTaken
			   );
    
    $self->SUPER::_Set($Field, $Value);
    #Figure out where to send mail
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



# $Header$
# (c) 1996-2000 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL
#

=head1 NAME

  RT::Ticket - RT's ticket object

=head1 SYNOPSIS

  use RT::Ticket;
  my $ticket = new RT::Ticket($CurrentUser);
  $ticket->Load($ticket_id);

=head1 DESCRIPTION

This module lets you manipulate RT's most key object. The Ticket.


=head1 METHODS

=cut


package RT::Ticket;
use RT::User;
use RT::Record;
use RT::Link;
use RT::Links;
use RT::Date;
use RT::Watcher;

@ISA= qw(RT::Record);


# {{{ sub _Init

sub _Init {
    my $self = shift;
    $self->{'table'} = "Tickets";
    return ($self->SUPER::_Init(@_));
}

# }}}

# {{{ sub Load

=head2 Load

Takes a single argument. This can be a ticket id, ticket alias or 
local ticket uri.  If the ticket can't be loaded, returns undef.
Otherwise, returns the ticket id.

=cut

sub Load {
   my $self = shift;
   my $id = shift;
   
   #If it's a local URI, load the ticket object and return its URI
   if ($id =~ /^$RT::TicketBaseURI/)  {
       return($self->LoadByURI($id));
   }
   #If it's a remote URI, we're going to punt for now
   elsif ($id =~ '://' ) {
       return (undef);
   }
   
   #If the base is an integer, load it as a ticket 
   elsif ( $id =~ /^\d+$/ ) {
       return($self->LoadById($id));
   }
   
   #It's not a URI. It's not a numerical ticket ID. It must be an alias
   else {
       return( $self->LoadByAlias($id));
   }
   
   
}
  
# }}}

# {{{ sub LoadByAlias

=head2 LoadByAlias

Takes a single argument. Loads the ticket whose alias matches what was passed in.

=cut

sub LoadByAlias {
    my $self = shift;
    my $alias = shift;
   return($self->LoadByCol('Alias', $alias));
}

# }}}

# {{{ sub LoadByURI

=head2 LoadByURI

Given a local ticket URI, loads the specified ticket.

=cut

sub LoadByURI {
    my $self = shift;
    my $uri = shift;
    
    if ($uri =~ /^$RT::TicketBaseURI(\d+)$/) {
        my $id = $1;
        return ($self->Load($id));
    }
    else {
        return(undef);
    }
}

# }}}

# {{{ sub Create

=head2 Create (ARGS)

Arguments: ARGS is a hash of named parameters.  Valid parameters are:

  id 
  Queue  - Either a Queue object or a QueueId
  
  Requestor -- An RT::User object (the ticket\'s requestor)
  RequestorEmail -- the requestors email address. (if the Requestor object isn't available
  
  Requestor -  A list of RT::User objects, email addresses or UserIds
  Cc  - A list of RT::User objects, email addresses or UserIds
  AdminCc  - A list of RT::User objects, email addresses or UserIds
  
  Alias  -- The ticket\'s textual alias
  Type -- The ticket\'s type. ignore this for now
  Owner -- This ticket\'s owner. either an RT::User object or this user\'s id
  Subject -- A string describing the subject of the ticket
  InitialPriority -- an integer from 0 to 99
  FinalPriority -- an integer from 0 to 99
  Status -- a textual tag. one of \'new\', \'open\' \'stalled\' \'resolved\' for now
  TimeWorked -- an integer
  Due -- an ISO date describing the ticket\'s due date and time in GMT
  MIMEObj -- a MIME::Entity object with the content of the initial ticket request.

Returns: TICKETID, Transaction Object, Error Message

=cut


sub Create {
    my $self = shift;
    my ( $ErrStr, $Queue, $Owner);
    
    my %args = (id => undef,
		Queue => undef,
		Requestor => undef,
		RequestorEmail => undef,
		Alias => undef,
		Type => 'ticket',
		Owner => $RT::Nobody->UserObj,
		Subject => '[no subject]',
		InitialPriority => "0",
		FinalPriority => "0",
		Status => 'new',
		TimeWorked => "0",
		Due => "0",
		MIMEObj => undef,
		@_);
    
    #TODO Load queue defaults +++ v2.0
    
    if ( (defined($args{'Queue'})) && (!ref($args{'Queue'})) ) {
	$Queue=RT::Queue->new($self->CurrentUser);
	$Queue->Load($args{'Queue'});
	#TODO error check this and return 0 if it's not loading properly +++
    }
    elsif (ref($args{'Queue'}) eq 'RT::Queue') {
	$Queue = $args{'Queue'};
    }
    else {
	$RT::Logger->err($args{'Queue'} . " not a recognised queue object.");
    }
    #Can't create a ticket without a queue.
    unless (defined ($Queue)) {
	$RT::Logger->err( "No queue given for ticket create request '".$args{'Subject'}."'");
	return (0, 0,'Queue not set');
    }
    
    #Check the ACLS
    unless ($self->CurrentUser->HasQueueRight(Right => 'CreateTicket',
					      IsRequestor => 'true',
					      QueueObj => $Queue )) {
	return (0,0,"No permission to create tickets in that queue");
    }
    
    
    # {{{ Deal with setting the owner
    if (ref($args{'Owner'}) eq 'RT::User') {
	$Owner = $args{'Owner'};
    }
    #If we've been handed an integer (aka an Id for the users table 
    elsif ($args{'Owner'} =~ /^\d+$/) {
	$Owner = new RT::User($self->CurrentUser);
	$Owner->Load($args{'Owner'});
	
    }
    #If we can't handle it, call it nobody
    else {
	if (ref($args{'Owner'})) {
	    $RT::Logger->warning("Ticket $ticket  ->Create called with an Owner of ".
				 "type ".ref($args{'Owner'}) .". Defaulting to nobody.\n");
	}
	else { 
	    $RT::Logger->warning("Ticket $ticket ->Create called with an ".
				 "unrecognised datatype for Owner: ".$args{'Owner'} .
				 ". Defaulting to Nobody.\n");
	}
    }
    
    #If we have a proposed owner and they don't have the right 
    #to own a ticket, scream about it and make them not the owner
    if ((defined ($Owner)) and
	($Owner->Id != $RT::Nobody->Id) and 
	(!$Owner->HasQueueRight( QueueObj => $Queue,  Right => 'OwnTicket'))) {
	
	$RT::Logger->warning("$self user ".$Owner->UserId . "(".$Owner->id .") was proposed ".
			     "as a ticket owner but has no rights to own ".
			     "tickets in this queue\n");
	
	$Owner = undef;
    }
    
    #If we haven't been handed a valid owner, make it nobody.
    unless (defined ($Owner)) {
	$Owner = new RT::User($self->CurrentUser);
	$Owner->Load($RT::Nobody->UserObj->Id);
    }	

    # }}}


    #TODO we should see what sort of due date we're getting, rather +
    # than assuming it's in ISO format.
    my $due = new RT::Date($self->CurrentUser);
    $due->Set (Format => 'ISO',
	       Value => $args{'Due'});
    
    my $id = $self->SUPER::Create(
				  Queue => $Queue->Id,
				  Alias => $args{'Alias'},
				  Owner => $Owner->Id,
				  Subject => $args{'Subject'},
				  InitialPriority => $args{'InitialPriority'},
				  FinalPriority => $args{'FinalPriority'},
				  Priority => $args{'InitialPriority'},
				  Status => $args{'Status'},
				  TimeWorked => $args{'TimeWorked'},
				  Type => $args{'Type'},	
				  Due => $due->ISO
				 );
    
     
    $RT::Logger->debug("Now adding watchers. ");

    my $watcher;
    foreach $watcher (@{$args{'Cc'}}) {
	$self->_AddWatcher( Type => 'Cc', Person => $watcher, Silent => 1);
    }	
    foreach $watcher (@{$args{'AdminCc'}}) {
	$self->_AddWatcher( Type => 'AdminCc', Person => $watcher, Silent => 1);
    }	
    foreach $watcher (@{$args{'Requestor'}}) {
	$self->_AddWatcher( Type => 'Requestor', Person => $watcher, Silent => 1);
   }
    

    #Add a transaction for the create
    my ($Trans, $Msg, $TransObj) = $self->_NewTransaction(Type => "Create",
							  TimeTaken => 0, 
							  MIMEObj=>$args{'MIMEObj'});
    
    # Logging
    if ($self->Id && $Trans) {
	$ErrStr='Ticket #'.$self->Id . " created in queue ". $Queue->QueueId;
	
	$RT::Logger->info($ErrStr);
    } 
    else {
	$RT::Logger->warning("Ticket couldn't be created: $ErrStr");
    }
    
    # Hmh ... shouldn't $ErrStr be the second return argument?
    # Eventually, are all the callers updated?
    return($self->Id, $TransObj->Id, $ErrStr);
}

# }}}

# {{{ Routines dealing with watchers.

# {{{ Routines dealing with adding new watchers

# {{{ sub AddWatcher

=head2 AddWatcher

AddWatcher takes a parameter hash. The keys are as follows:

Email
Type
Owner

If the watcher you\'re trying to set has an RT account, set the Owner paremeter to their User Id. Otherwise, set the Email parameter to their Email address.

=cut

sub AddWatcher {
    my $self = shift;
    
    unless ($self->CurrentUserHasRight('ModifyTicket')) {
	return (0, "Permission Denied");
	
    }
    
    return ($self->_AddWatcher(@_));
}


#This contains the meat of AddWatcher. but can be called from a routine like
# Create, which doesn't need the additional acl check
sub _AddWatcher {
    my $self = shift;
    my %args = (
		Type => undef,
		Silent => undef,
		Email => undef,
		Owner => 0,
		Person => undef,
		@_ );
    
    $RT::Logger->debug("Now adding a watcher: ");
    
    
    #clear the watchers cache
    $self->{'watchers_cache'} = undef;
    
    
    if (defined $args{'Person'}) {
	#if it's an RT::User object, pull out the id and shove it in Owner
	if (ref ($args{'Person'}) =~ /RT::User/) {
	    $args{'Owner'} = $args{'Person'}->id;
	}	
	#if it's an int, shove it in Owner
	elsif ($args{'Person'} =~ /^\d+$/) {
	    $args{'Owner'} = $args{'Person'};
	}
	#if it's an email address, shove it in Email
       else {
	   $args{'Email'} = $args{'Person'};
       }	
    }	
    
    if ($args{'Owner'} == 0) {
	my $User = new RT::User($RT::SystemUser);
	$User->LoadByEmail($args{'Email'});
	if ($User->id > 0) {
	    $args{'Owner'} = $User->id;
	    $args{'Email'} = undef;
       }	
    }
    
    
    #If we have an email address, try to resolve it to an owner
    
    require RT::Watcher;
    my $Watcher = new RT::Watcher ($self->CurrentUser);
    my ($retval, $msg) = ($Watcher->Create( Value => $self->Id,
					    Scope => 'Ticket',
					    Email => $args{'Email'},
					    Type => $args{'Type'},
					    Owner => $args{'Owner'},
					  ));
    
    unless ($args{'Silent'}) {
	$self->_NewTransaction( Type => 'AddWatcher',
				NewValue => $Watcher->Email,
				Data => $Watcher->Type);
    }
    
    return ($retval, $msg);
}

# }}}

# {{{ sub AddRequestor

=head2 AddRequestor

AddRequestor takes what AddWatcher does, except it presets
the "Type" parameter to \'Requestor\'

=cut

sub AddRequestor {
   my $self = shift;
   return ($self->AddWatcher ( Type => 'Requestor', @_));
}

# }}}

# {{{ sub AddCc

=head2 AddCc

AddCc takes what AddWatcher does, except it presets
the "Type" parameter to \'Cc\'

=cut

sub AddCc {
   my $self = shift;
   return ($self->AddWatcher ( Type => 'Cc', @_));
}
# }}}
	
# {{{ sub AddAdminCc

=head2 AddAdminCc

AddAdminCc takes what AddWatcher does, except it presets
the "Type" parameter to \'AdminCc\'

=cut

sub AddAdminCc {
   my $self = shift;
   return ($self->AddWatcher ( Type => 'AdminCc', @_));
}

# }}}

# }}}

# {{{ sub DeleteWatcher

=head2 DeleteWatcher

DeleteWatcher takes a single argument which is either an email address 
or a watcher id.  It removes that watcher
from this Ticket\'s list of watchers.


=cut


sub DeleteWatcher {
    my $self = shift;
    my $id = shift;
    
    my ($Watcher);
   
    #Check ACLs 
    unless ($self->CurrentUserHasRight('ModifyTicket')) {
        return (0, "Permission Denied");
    }
    
    #Clear out the watchers hash.
    $self->{'watchers'} = undef;

    #If it's a numeric watcherid
   if ($id =~ /^(\d*)$/) { 
    $Watcher = new RT::Watcher($self->CurrentUser);
    $Watcher->Load($id);
    if (($Watcher->Scope  ne 'Ticket') or
       ($Watcher->Value != $self->id) ) {
        return (0, "Not a watcher for this ticket");
       }
      #If we've validated that it is a watcher for this ticket 
      else {
          $self->_NewTransaction ( Type => 'DelWatcher',        
                 OldValue => $Watcher->Email,
                 Data => $Watcher->Type,
                   );
        $Watcher->Delete();
     }
   }
    #Otherwise, we'll assume it's an email address
   else {
   #Iterate throug all the watchers looking for this email address
    #it may be faster to speed this up with a custom query
    while ($Watcher = $self->Watchers->Next) {
      if ($Watcher->Email =~ /^$id$/) {
	$self->_NewTransaction ( Type => 'DelWatcher',
				 OldValue => $Watcher->Email,
				 Data => $Watcher->Type,
			       );
	$Watcher->Delete();
      }
    }
    }
}

# }}}

# {{{ sub Watchers

=head2

Watchers returns a Watchers object preloaded with this ticket\'s watchers.

# It should return only the ticket watchers. the actual FooAsString
# methods capture the queue watchers too. I don't feel thrilled about this,
# but we don't want the Cc Requestors and AdminCc objects to get filled up
# with all the queue watchers too. we've got seperate objects for that.
  # should we rename these as s/(.*)AsString/$1Addresses/ or somesuch?

=cut

sub Watchers {
  my $self = shift;
  
  unless ($self->CurrentUserHasRight('ShowTicket')) {
    return (0, "Permission Denied");
  }

  if (! defined ($self->{'Watchers'}) 
      || $self->{'Watchers'}->{is_modified}) {
    require RT::Watchers;
    $self->{'Watchers'} =RT::Watchers->new($self->CurrentUser);
    $self->{'Watchers'}->LimitToTicket($self->id);

  }
  return($self->{'Watchers'});
  
}

# }}}

# {{{ a set of  [foo]AsString subs that will return the various sorts of watchers for a ticket/queue as a comma delineated string

=head2 RequestorsAsString


B<Takes> I<nothing>
 B<Returns> String: All Ticket/Queue Requestors.

=cut

sub RequestorsAsString {
    my $self=shift;

    unless ($self->CurrentUserHasRight('ShowTicket')) {
	return (0, "Permission Denied");
    }
    return _CleanAddressesAsString($self->Requestors->EmailsAsString() );
}

=head2 WatchersAsString

B<Takes> I<nothing>
B<Returns> String: All Ticket/Queue Watchers.

=cut

sub WatchersAsString {
    my $self=shift;

    unless ($self->CurrentUserHasRight('ShowTicket')) {
	return (0, "Permission Denied");
    }
    
    return _CleanAddressesAsString ($self->Watchers->EmailsAsString() . ", " .
		  $self->QueueObj->Watchers->EmailsAsString());
}

=head2 AdminCcAsString

=item B<Takes>

=item I<nothing>

=item B<Returns>

=item String: All Ticket/Queue AdminCcs.

=cut


sub AdminCcAsString {
    my $self=shift;

    unless ($self->CurrentUserHasRight('ShowTicket')) {
	return (0, "Permission Denied");
    }

    return _CleanAddressesAsString ($self->AdminCc->EmailsAsString() . ", " .
				    $self->QueueObj->AdminCc->EmailsAsString());
}

=head2 CcAsString

=item B<Takes>

=item I<nothing>

=item B<Returns>

=item String: All Ticket/Queue Ccs.

=cut

sub CcAsString {
    my $self=shift;

    unless ($self->CurrentUserHasRight('ShowTicket')) {
	return (0, "Permission Denied");
    }
    
    return _CleanAddressesAsString ($self->Cc->EmailsAsString() . ", ".
				    $self->QueueObj->Cc->EmailsAsString());
}

# {{{ sub  _CleanAddressesAsString
=head2 _CleanAddressesAsString

=item B<Takes>

=item String: A comma delineated address list

=item B<Returns>

=item String: A comma delineated address list

=cut

sub _CleanAddressesAsString {
    my $i=shift;
    $i =~ s/^, //;
    $i =~ s/, $//;
    $i =~ s/, ,/,/g;
    return $i;
}

# }}}
# }}}

# {{{ Routines that return RT::Watchers objects of Requestors, Ccs and AdminCcs

# {{{ sub Requestors

=head2 Requestors

Takes nothing.
Returns this ticket's Requestors as an RT::Watchers object

=cut

sub Requestors {
    my $self = shift;
    
  unless ($self->CurrentUserHasRight('ShowTicket')) {
    return (0, "Permission Denied");
  }
    
  require RT::Watchers;
    
    if (! defined ($self->{'Requestors'})) {
	
	$self->{'Requestors'} = RT::Watchers->new($self->CurrentUser);
	$self->{'Requestors'}->LimitToTicket($self->id);
	$self->{'Requestors'}->LimitToRequestors();
    }
    return($self->{'Requestors'});
    
}

# }}}

# {{{ sub Cc

=head2 Cc

Takes nothing.
Returns a watchers object which contains this ticket's Cc watchers

=cut

sub Cc {
    my $self = shift;
    
    unless ($self->CurrentUserHasRight('ShowTicket')) {
	return (0, "Permission Denied");
    } 
    
    if (! defined ($self->{'Cc'})) {
	require RT::Watchers;
	$self->{'Cc'} = new RT::Watchers ($self->CurrentUser);
	$self->{'Cc'}->LimitToTicket($self->id);
	$self->{'Cc'}->LimitToCc();
    }
    return($self->{'Cc'});
    
}

# }}}

# {{{ sub AdminCc

=head2 AdminCc

Takes nothing.
Returns this ticket's administrative Ccs as an RT::Watchers object

=cut

sub AdminCc {
    my $self = shift;
    
    unless ($self->CurrentUserHasRight('ShowTicket')) {
	return (0, "Permission Denied");
    }
    
    if (! defined ($self->{'AdminCc'})) {
	require RT::Watchers;
	$self->{'AdminCc'} = new RT::Watchers ($self->CurrentUser);
	$self->{'AdminCc'}->LimitToTicket($self->id);
	$self->{'AdminCc'}->LimitToAdminCc();
    }
    return($self->{'AdminCc'});
    
}

# }}}

# }}}

# {{{ IsWatcher,IsRequestor,IsCc, IsAdminCc

# {{{ sub IsWatcher
# a generic routine to be called by IsRequestor, IsCc and IsAdminCc

=head2 IsWatcher

Takes a param hash with the attributes Type and User. User is either a user object or string containing an email address. Returns true if that user or string
is a ticket watcher. Returns undef otherwise

=cut

sub IsWatcher {
    my $self = shift;
    
    my %args = ( Type => 'Requestor',
		 User => undef,
		 @_
	       );
    
 
    my %cols = ('Type' => $args{'Type'},
		'Scope' => 'Ticket',
		'Value' => $self->Id
	       );

    if (ref($args{'Id'})){ #If it's a ref, assume it's an RT::User object;
	#Dangerous but ok for now
	$cols{'Owner'} = $args{'Id'}->Id;
    }
    elsif ($args{'Id'} =~ /^\d+$/) { # if it's an integer, it's an RT::User obj
	$cols{'Owner'} = $args{'Id'};
    }
    else {
	$cols{'Email'} = $args{'Id'};
    }	

    if ($args{'Email'}) {
	$cols{'Email'} = $args{'Email'};
    }
    


    my ($description);
    $description = join(":",%cols);
    
    #If we've cached a positive match...
    if (defined $self->{'watchers_cache'}->{"$description"}) {
	if ($self->{'watchers_cache'}->{"$description"} == 1) {
	    return(1);
	}
	#If we've cached a negative match...
	else {
	    return(undef);
	}
    }

    my $watcher = new RT::Watcher($self->CurrentUser);
    $watcher->LoadByCols(%cols);
    
    
    if ($watcher->id) {
	$self->{'watchers_cache'}->{"$description"} = 1;
	return(1);
    }	
    else {
	$self->{'watchers_cache'}->{"$description"} = 0;
	return(undef);
    }
    
}
# }}}

# {{{ sub IsRequestor

=head2 IsRequestor
  
  Takes an email address, RT::User object or integer (RT user id)
  Returns true if the string is a requestor of the current ticket.


=cut

sub IsRequestor {
    my $self = shift;
    my $whom = shift;
    

    return ($self->IsWatcher(Type => 'Requestor', Id => $whom));
	    
};

# }}}

# {{{ sub IsCc

=head2 IsCc

Takes a string. Returns true if the string is a Cc watcher of the current ticket.

=cut

sub IsCc {
  my $self = shift;
  my $cc = shift;
  
  return ($self->IsWatcher( Type => 'Cc', Id => $cc ));
  
}

# }}}

# {{{ sub IsAdminCc

=head2 IsAdminCc

Takes a string. Returns true if the string is an AdminCc watcher of the current ticket.

=cut

sub IsAdminCc {
  my $self = shift;
  my $bcc = shift;
  
  return ($self->IsWatcher( Type => 'AdminCc', Id => $bcc ));
  
}

# }}}

# {{{ sub IsOwner

=head2 IsOwner

  Takes an RT::User object. Returns true if that user is this ticket's owner.
returns undef otherwise

=cut

sub IsOwner {
    my $self = shift;
    my $person = shift;
  
    $RT::Logger->debug("Person is ".$person);

    #Tickets won't yet have owners when they're being created.
    unless ($self->OwnerObj->id) {
        return(undef);
    }

    if ($person->id == $self->OwnerObj->id) {
	return(1);
    }
    else {
	return(undef);
    }
}


# }}}

# }}}

# {{{ Routines dealing with queues 

# {{{ sub ValidateQueue

sub ValidateQueue {
  my $self = shift;
  my $Value = shift;
  
  #TODO I don't think this should be here. We shouldn't allow anything to have an undef queue,
  if (!$Value) {
    $RT::Logger->warning( " RT:::Queue::ValidateQueue called with a null value. this isn't ok.");
    return (1);
  }
  
  require RT::Queue;
  my $QueueObj = RT::Queue->new($self->CurrentUser);
  my $id = $QueueObj->Load($Value);
  
  if ($id) {
    return (1);
  }
  else {
    return (undef);
  }
}

# }}}

# {{{ sub SetQueue  

sub SetQueue {
  my $self = shift;
  my ($NewQueue, $NewQueueObj);

  unless ($self->CurrentUserHasRight('ModifyTicket')) {
    return (0, "Permission Denied");
  }
  
  if ($NewQueue = shift) {
    #TODO Check to make sure this isn't the current queue.
    #TODO this will clobber the old queue definition. 
      
    use RT::Queue;
    $NewQueueObj = RT::Queue->new($self->CurrentUser);
    
    if (!$NewQueueObj->Load($NewQueue)) {
      return (0, "That queue does not exist");
    }
    elsif (!$self->CurrentUser->HasQueueRight(Right =>'CreateTicket',
					       QueueObj => $NewQueueObj )) {
      return (0, "You may not create requests in that queue.");
    }
    elsif (!$NewOwnerObj->HasQueueRight(Right=> 'CreateTicket',  
                                         QueueObj => $NewQueueObj)) {
      $self->Untake();
    }
    
    else {
      return($self->_Set(Field => 'Queue', Value => $NewQueueObj->Id()));
    }
  }
  else {
    return (0,"No queue specified");
  }
}

# }}}

# {{{ sub QueueObj

=head2 QueueObj

Takes nothing. returns this ticket's queue object

=cut

sub QueueObj {
    my $self = shift;

    
    if (!defined $self->{'queue'})  {
	require RT::Queue;
	if (!($self->{'queue'} = RT::Queue->new($self->CurrentUser))) {
	    $RT::Logger->Crit("RT::Queue->new(". $self->CurrentUser. 
			      ") returned false");
	    return(undef);
	}	
	#We call SUPER::_Value so that we can avoid the ACL decision and some deep recursion
	my ($result) = $self->{'queue'}->Load($self->SUPER::_Value('Queue'));
	
    }
    return ($self->{'queue'});
}


# }}}

# }}}

# {{{ Date printing routines

# {{{ sub DueObj
sub DueObj {
    my $self = shift;
    
    my $time = new RT::Date($self->CurrentUser);

    # -1 is RT::Date slang for never
    if ($self->Due) {
	$time->Set(Format => 'sql', Value => $self->Due );
    }
    else {
	$time->Set(Format => 'unix', Value => -1);
    }
    
    return $time;
}
# }}}

# {{{ sub DueAsString 

sub DueAsString {
  my $self = shift;
  return $self->DueObj->AsString();
}

# }}}

# {{{ sub GraceTimeAsString 

# This really means "time until due"
sub GraceTimeAsString {
    my $self=shift;

    if ($self->Due) {
	my $now=new RT::Date($self->CurrentUser);
	$now->SetToNow();	
	return($now->DiffAsString($self->DueObj));
    } else {
	return "";
    }
}

# }}}


# {{{ sub ResolvedObj

=head2 ResolvedObj

  Returns an RT::Date object of this ticket's 'resolved' time.

=cut

sub ResolvedObj {
  my $self = shift;

  my $time = new RT::Date($self->CurrentUser);
  $time->Set(Format => 'sql', Value => $self->Resolved);
  return $time;
}
# }}}

# {{{ sub SetStarted

=head2 SetStarted

Takes a date in ISO format or undef
Returns a transaction id and a message
The client calls "Start" to note that the project was started on the date in $date.
A null date means "now"

=cut
  
sub SetStarted {
    my $self = shift;
    my $time = shift || 0;
    

    unless ($self->CurrentUserHasRight('ModifyTicket')) {
	return (0, "Permission Denied");
    }

    #We create a date object to catch date weirdness
    my $time_obj = new RT::Date($self->CurrentUser());
    if ($time != 0)  {
	$time_obj->Set(Format => 'ISO', Value => $time);
    }
    else {
	$time_obj->SetToNow();
    }
    
    #Now that we're starting, open this ticket
    $self->Open;

    return ($self->_Set(Field => 'Started', Value =>$time_obj->ISO));
    
}
# }}}

# {{{ sub StartedObj

=head2 StartedObj

  Returns an RT::Date object which contains this ticket's 
'Started' time.

=cut


sub StartedObj {
    my $self = shift;
    
    my $time = new RT::Date($self->CurrentUser);
    $time->Set(Format => 'sql', Value => $self->Started);
    return $time;
}
# }}}

# {{{ sub StartsObj

=head2 StartsObj

  Returns an RT::Date object which contains this ticket's 
'Starts' time.

=cut

sub StartsObj {
  my $self = shift;
  
  my $time = new RT::Date($self->CurrentUser);
  $time->Set(Format => 'sql', Value => $self->Starts);
  return $time;
}
# }}}

# {{{ sub ToldObj

=head2 ToldObj

  Returns an RT::Date object which contains this ticket's 
'Told' time.

=cut


sub ToldObj {
  my $self = shift;
  
  my $time = new RT::Date($self->CurrentUser);
  $time->Set(Format => 'sql', Value => $self->Told);
  return $time;
}

# }}}

# {{{ sub LongSinceToldAsString

# TODO This should be called SinceToldAsString


sub LongSinceToldAsString {
  my $self = shift;

  if ($self->Told) {
      my $now = new RT::Date($self->CurrentUser);
      $now->SetToNow();
      return $now->DiffAsString($self->ToldObj);
  } else {
      return "Never";
  }
}
# }}}

# {{{ sub ToldAsString

=head2 ToldAsString

A convenience method that returns ToldObj->AsString

=cut


sub ToldAsString {
    my $self = shift;
    if ($self->Told) {
	return $self->ToldObj->AsString();
    }
    else {
	return("Never");
    }
}
# }}}

# {{{ sub LastUpdatedByObj

=head2 LastUpdatedByObj

  Returns an RT::User object of the last user to touch this object
  TODO: why isn't this in RT::Record

=cut

sub LastUpdatedByObj {
  my $self=shift;
  unless (exists $self->{LastUpdatedByObj}) {
    $self->{LastUpdatedByObj}=RT::User->new($self->CurrentUser);
    $self->{LastUpdatedByObj}->Load($self->LastUpdatedBy);
  }
  return $self->{LastUpdatedByObj};
}
# }}}

# {{{ sub TimeWorkedAsString

=head2 TimeWorkedAsString

Returns the amount of time worked on this ticket as a Text String

=cut

sub TimeWorkedAsString {
    my $self=shift;
    return "0" unless $self->TimeWorked;
    
    #This is not really a date object, but if we diff a number of seconds 
    #vs the epoch, we'll get a nice description of time worked.
    
    my $worked = new RT::Date($self->CurrentUser);
    #return the  #of minutes worked turned into seconds and written as
    # a simple text string

    return($worked->DurationAsString($self->TimeWorked*60));
}

# }}}


# }}}

# {{{ Routines dealing with correspondence/comments

# {{{ sub Comment

=head2 Comment

Comment on this ticket.
Takes a hashref with the follwoing attributes:

    BccMessageTo, CcMesageTo, MimeObj, TimeTaken

=cut

sub Comment {
  my $self = shift;
  
  my %args = (BccMessageTo => undef,
	      CcMessageTo => undef,
	      MIMEObj => undef,
	      TimeTaken => 0,
	      @_ );

  unless (($self->CurrentUserHasRight('CommentOnTicket')) or
	  ($self->CurrentUserHasRight('ModifyTicket'))) {
      return (0, "Permission Denied");
  }
  
  
  #Record the correspondence (write the transaction)
  my ($Trans, $Msg, $TransObj) = $self->_NewTransaction( Type => 'Comment',
				      Data => $args{MIMEObj}->head->get('subject'),
				      TimeTaken => $args{'TimeTaken'},
				      MIMEObj => $args{'MIMEObj'}
				    );
  
  if ($args{'CcMessageTo'} || 
      $args{'BccMessageTo'} ) {
      #TODO send a copy of the correspondence to the CC list and BCC list
    $RT::Logger->warning( "RT::Ticket::Comment needs to send mail to explicit CCs and BCCs");
  }
  
  return ($Trans, "The comment has been recorded");
}

# }}}

# {{{ sub Correspond

=head2 Correspond

Correspond on this ticket.
Takes a hashref with the follwoing attributes:

    BccMessageTo, CcMesageTo, MimeObj, TimeTaken

=cut

sub Correspond {
  my $self = shift;
  my %args = ( CcMessageTo => undef,
	       BccMessageTo => undef,
	       MIMEObj => undef,
	       TimeTaken => 0,
	       @_ );

  unless (($self->CurrentUserHasRight('ReplyToTicket')) or
	  ($self->CurrentUserHasRight('ModifyTicket'))) {
      return (0, "Permission Denied");
  }
  
  unless ($args{'MIMEObj'}) {
      return(0,"No correspondence attached");
  }

  #Record the correspondence (write the transaction)
  my ($Trans,$msg, $TransObj) = $self->_NewTransaction
    (Type => 'Correspond',
     Data => $args{'MIMEObj'}->head->get('subject'),
     TimeTaken => $args{'TimeTaken'},
     MIMEObj=> $args{'MIMEObj'}     
    );
  
  if ($args{BccMessageTo} || 
      $args{CcMessageTo}) {

      $RT::Logger->warning("RT::Ticket->Correspond doesn't yet send CCs and Bccs"); 
  }
  
  unless ($Trans) {
      $RT::Logger->err("$self couldn't init a transaction ($msg)\n");
      return ($Trans, "correspondence (probably) NOT sent", $args{'MIMEObj'});
  }
 
  #Set the last told date to now if this isn't mail from the requestor.
  #Note that this will wrongly ack mail from any non-requestor as a "told"

  unless ($TransObj->IsInbound) {
      $self->_SetTold;
  }
  
  return ($Trans, "correspondence sent");
}

# }}}

# }}}

# {{{ Routines dealing with Links and Relations between tickets

# {{{ sub Members

=head2 Members

  This returns an RT::Tickets object which references all the tickets 
that have  this ticket as their target AND are of type 'MemberOf'

=cut

sub Members {
   my $self = shift;

   unless ($self->CurrentUserHasRight('ShowTicket')) {
       return (0, "Permission Denied");
   }
   
   if (!defined ($self->{'members'})){
       use RT::Tickets;
       $self->{'members'} = new RT::Tickets($self->CurrentUser);
       #Tickets that are Members of this ticket
       $self->{'members'}->LimitMemberOf($self->id);
       #Don't show dead tickets
       $self->{'members'}->LimitStatus( OPERATOR => '!=',
					VALUE => 'dead');
   }
   return ($self->{'members'});
}

# }}}

# {{{ sub MemberOf

=head2 MemberOf

  This returns an RT::Tickets object which references all the tickets that have 
this ticket as their base AND are of type 'MemberOf' AND are not marked 
'dead'

=cut

sub MemberOf {
   my $self = shift;
   
   unless ($self->CurrentUserHasRight('ShowTicket')) {
      return (0, "Permission Denied");
  }
   
   if (!defined ($self->{'memberof'})){
       use RT::Tickets;
       $self->{'memberof'} = new RT::Tickets($self->CurrentUser);
       #Tickets that  this ticket is a member of
       $self->{'memberof'}->LimitHasMember($self->id);
       #Don't show dead tickets
       $self->{'memberof'}->LimitStatus( OPERATOR => '!=',
					 VALUE => 'dead');
   }
   return ($self->{'memberof'});
   
}

# }}}

# {{{ Dependants

=head2 Dependants

  This returns an RT::Links object which references all the tickets that depend on this one

=cut
sub Dependants {
    my $self = shift;
    return $self->_Links('Target','DependsOn');
}

# }}}

# {{{ DependsOn

=head2 DependsOn

  This returns an RT::Links object which references all the tickets that this ticket depends on

=cut
sub DependsOn {
   my $self = shift;
    return $self->_Links('Base','DependsOn');
}

# }}}

# {{{ RefersTo

=head2 RefersTo

  This returns an RT::Links object which shows all references for which this ticket is a base

=cut

sub RefersTo {
    my $self = shift;
    return $self->_Links('Base', 'RefersTo');
}

# }}}

# {{{ ReferedToBy

=head2 ReferedToBy

  This returns an RT::Links object which shows all references for which this ticket is a target

=cut

sub ReferedToBy {
    my $self = shift;
    return $self->_Links('Target', 'RefersTo');
}

# }}}

# {{{ sub Children
# Gets all (local) links where we're the TARGET
sub Children {
    return $_[0]->_Links('Target');
}
# }}}

# {{{ sub Parents
# Gets all (local) links where we're the BASE
sub Parents {
    return $_[0]->_Links('Base');
}
# }}}

# {{{ sub _Links 
sub _Links {
    my $self = shift;
    
    unless ($self->CurrentUserHasRight('ShowTicket')) {
	return (0, "Permission Denied");
    }
    #TODO: Field isn't the right thing here. but I ahave no idea what mnemonic ---
    #tobias meant by $f
    my $field = shift;
    my $type =shift || "";
    unless (exists $self->{"$field$type"}) {
	
	$self->{"$field$type"} = new RT::Links($self->CurrentUser);
	$self->{"$field$type"}->Limit(FIELD=>$field, VALUE=>$self->URI);
	$self->{"$field$type"}->Limit(FIELD=>'Type', VALUE=>$type) if ($type);
    }
    return ($self->{"$field$type"});
}

# }}}


# {{{ sub URI 

=head2 URI

Returns this ticket's URI

=cut

sub URI {
    my $self = shift;
    return $RT::TicketBaseURI.$self->id;
}

# }}}

# {{{ sub MergeInto

=head2 MergeInto
MergeInto take the id of the ticket to merge this ticket into.

=cut

sub MergeInto {
  my $self = shift;
  my $MergeInto = shift;

  unless ($self->CurrentUserHasRight('ModifyTicket')) {
    return (0, "Permission Denied");
  }
  
  #TODO: Merge must be implemented +++
  die "Ticket::Merge stubbed";
  #Make sure this user can modify this ticket
  #Load $MergeInto as Ticket $Target

  #Make sure this user can modify $Target
  #If I have an owner and the $Target doesn't, set them on the target
  
  #If I have a Due Date and it's before the $Target's due date, set the $Target's due date
  #Merge the requestor lists
  #Set my effective_sn to the $Target's Effective SN.
  #Set all my transactions Effective_SN to the $Target's Effective_Sn
  
  #Make sure this ticket object thinks its merged

  return ($TransactionObj, "Merge Successful");
}  

# }}}

# {{{ sub LinkTo

=head2 LinkTo

TODO What the hell does this take for args?

=cut

sub LinkTo {
    my $self = shift;
    my %args = ( dir => 'T',
		 Base => $self->URI,
		 Target => '',
		 Type => '',
		 @_ );
   return( $self->_NewLink(%args));
    
}

# }}}

# {{{ sub LinkFrom

=head2 LinkFrom

What the hell does this take for args?

=cut


sub LinkFrom {
    my $self = shift;
    my %args = ( dir => 'F',
		 Base => '',
		 Target => $self->URI,
		 Type => '',
		 @_);
    return($self->_NewLink(%args));
}

# }}}

# {{{ sub _NewLink

=head2 _NewLink

TODO Rewrite _NewLink so it's easy to understand.

=cut

sub _NewLink {
  my $self = shift;
  my %args = ( dir => '',
	       Target => '',
	       Base => '',
	       Type => '',
	       @_ );
  
  unless ($self->CurrentUserHasRight('ModifyTicket')) {
      return (0, "Permission Denied",0);
  }
  
  # {{{ We don't want references to ourself
  if ($args{Base} eq $args{Target}) {
      return (0,"You're linking up yourself, that doesn't make sense");
  }	
  # }}}
 


  # If the base isn't a URI, make it a URI. 
  # If the target isn't a URI, make it a URI. 
  
  
  # {{{ Check if the link already exists - we don't want duplicates
  my $Links=RT::Links->new($self->CurrentUser);
  $Links->Limit(FIELD=>'Type',VALUE => $args{Type});
  $Links->Limit(FIELD=>'Base',VALUE => $args{Base});
  $Links->Limit(FIELD=>'Target',VALUE => $args{Target});
  my $l=$Links->First;
  if ($l) {
      $RT::Logger->log(level=>'info', 
		       message=>"Somebody tried to duplicate a link");
      return ($l->id, "Link already exists",0);
  }
  # }}}

  # TODO: URIfy local tickets
  
  # Storing the link in the DB.
  my $link = RT::Link->new($self->CurrentUser);
  my ($linkid) = $link->Create(Target => $args{Target}, 
			       Base => $args{Base}, 
			       Type => $args{Type});
  
  #Write the transaction
  my  ($b, $t);

  if ($args{dir} eq 'T') {
      $t=$args{Target};
      $b=$self->Id;
  } else {
      $t=$self->Id;
      $b=$args{Base};
  }
  my $TransString="Ticket $b $args{Type} ticket $t.";
  
  my ($Trans, $Msg, $TransObj) = $self->_NewTransaction
    (Type => 'Link',
     Data => $TransString,
     TimeTaken => 0 # Is this always true?
    );
  
  return ($linkid, "Link created ($TransString)", $transactionid);

}  

# }}}
  
# }}}
  
# {{{ Actions + Routines dealing with transactions

# {{{ Routines dealing with ownership

# {{{ sub Owner

=head2 OwnerObj

Takes nothing and returns an RT::User object of 
this ticket's owner

=cut

sub OwnerObj {
    my $self = shift;
    

    #If this gets ACLed, we lose on a rights check in User.pm and
    #get deep recursion. if we need ACLs here, we need
    #an equiv without ACLs
    
    #If the owner object ain't loaded yet
    if (! exists $self->{'owner'})  {
	require RT::User;
	$self->{'owner'} = new RT::User ($self->CurrentUser);
	$self->{'owner'}->Load($self->SUPER::_Value('Owner'));
    }
    
    
    #Return the owner object
    return ($self->{'owner'});
}

# }}}

# {{{ sub OwnerAsString 

=head2 OwnerAsString

Returns the owner's email address

=cut

sub OwnerAsString {
  my $self = shift;
  return($self->OwnerObj->EmailAddress);

}

# }}}

# {{{ sub SetOwner

=head2 SetOwner

Takes two arguments:
     the Id or UserId of the owner 
and  (optionally) the type of the SetOwner Transaction. It defaults
to 'Give'.  'Steal' is also a valid option.

=cut

sub SetOwner {
  my $self = shift;
  my $NewOwner = shift;
  my $Type = shift || "Give";
  my ($NewOwnerObj);
  

  unless ($self->CurrentUserHasRight('ModifyTicket')) {
      return (0, "Permission Denied");
  }  

  $RT::Logger->debug("in RT::Ticket->SetOwner()");
  
  $NewOwnerObj = RT::User->new($self->CurrentUser);
  my $OldOwnerObj = $self->OwnerObj;
  
  if (!$NewOwnerObj->Load($NewOwner)) {
	return (0, "That user does not exist");
    }
  
  #If thie ticket has an owner and it's not the current user
  
  if (($Type ne 'Steal' ) and  #If we're not stealing
      ($self->OwnerObj->Id != $RT::Nobody->Id ) and  #and the owner is set
      ($self->CurrentUser->Id ne $self->OwnerObj->Id())) { #and it's not us
      return(0, "You can only reassign tickets that you own or that are unowned");
  }
  
  #If we've specified a new owner and that user can't modify the ticket
  elsif (($NewOwnerObj) and 
	 (!$NewOwnerObj->HasQueueRight(Right => 'OwnTickets',
				       QueueObj => $self->QueueObj))
	) {
      return (0, "That user may not own requests in that queue");
  }
  
  
  #If the ticket has an owner and it's the new owner, we don't need
  #To do anything
  elsif (($self->OwnerObj) and ($NewOwnerObj->Id eq $self->OwnerObj->Id)) {
      return(0, "That user already owns that request");
  }
  
  
  my ($trans,$msg)=$self->_Set(Field => 'Owner',
			       Value => $NewOwnerObj->Id, 
			       TimeTaken => 0,
			       TransactionType => $Type);
  
  #Clean out the owner object
  delete $self->{'owner'};

  if ($trans) {
      $msg = "Owner changed from ".$OldOwnerObj->UserId." to ".$NewOwnerObj->UserId;
  }
  return ($trans, $msg);
	  
}

# }}}

# {{{ sub Take

=head2 Take

A convenince method to set the ticket's owner to the current user

=cut

sub Take {
  my $self = shift;
  
  return ($self->SetOwner($self->CurrentUser->Id, 'Take'));
}
# }}}

# {{{ sub Untake

=head2 Untake

Convenience method to set the owner to 'nobody' if the current user is the owner.

=cut

sub Untake {
  my $self = shift;
  
  return($self->SetOwner($RT::Nobody->UserObj, 'Untake'));
}
# }}}

# {{{ sub Steal 

=head2 Steal

A convenience method to change the owner of the current ticket to the
current user. Even if it's owned by another user.

=cut

sub Steal {
  my $self = shift;
  
   if ($self->OwnerObj->Id eq $self->CurrentUser->Id ) {
      return (0,"You already own this ticket"); 
  }
  else {
      return($self->SetOwner($self->CurrentUser->Id, 'Steal'));
      
  }
  
}

# }}}

# }}}

# {{{ Routines dealing with status


# {{{ sub SetStatus
sub SetStatus { 
  my $self = shift;
  my $status = shift;
  my $action = 
    $status =~ /new/i ? 'New' :
      $status =~ /open/i ? 'Open' :
	$status =~ /stalled/i ? 'Stall' :
	  $status =~ /resolved/i ? 'Resolve' :
	    $status =~ /dead/i ? 'Kill' : 'huh?';
  
  if ($action eq 'huh?') {
    return (0,"The status '$status' is not valid.");
  }


  unless ($self->CurrentUserHasRight('ModifyTicket')) {
      return (undef);
  }
  
	  #TODO check ACL

  my $now = new RT::Date($self->CurrentUser);
  $now->SetToNow();

  #If we're changing the status from new, record that we've started
  if (($self->Status =~ /new/) && ($status ne 'new')) {
 	#Set the Started time to "now"
	$self->_Set(Field => 'Started',
		   Value => $now->ISO,
		   RecordTransaction => 0);
  }

  
  if ($status eq 'resolved') {
      #TODO: this needs ACLing
      
      #When we resolve a ticket, set the 'Resolved' attribute to now.
      $self->_Set(Field => 'Resolved',
		  Value => $now->ISO, 
		  RecordTransaction => 0);
  }
  
  #Actually update the status
  return($self->_Set(Field => 'Status', 
		     Value => $status,
		     TimeTaken => 0,
		     TransactionType => 'Status'));
}
# }}}

# {{{ sub Kill

=head2 Kill

Takes no arguments. Marks this ticket for garbage collection

=cut

sub Kill {
  my $self = shift;
  return ($self->SetStatus('dead'));
  # TODO: garbage collection
}
# }}}

# {{{ sub Stall

=head2 Stall

Sets this ticket's status to stalled

=cut

sub Stall {
  my $self = shift;
  return ($self->SetStatus('stalled'));
}
# }}}

# {{{ sub Open

=head2 Open

Sets this ticket's status to Open

=cut

sub Open {
  my $self = shift;
  return ($self->SetStatus('open'));
}
# }}}

# {{{ sub Resolve

=head2

Sets this ticket's status to Resolved

=cut

sub Resolve {
  my $self = shift;
  return ($self->SetStatus('resolved'));
}
# }}}

# }}}

# {{{ sub SetTold and _SetTold

=head2 SetTold 

Updates the told and records a transaction

=cut

sub SetTold {
    my $self=shift;
    my $timetaken=shift || 0;
    my $now = new RT::Date($self->CurrentUser);
    $now->SetToNow(); 

    return($self->_Set(Field => 'Told', 
		       Value => $now->ISO,
		       TimeTaken => $timetaken,
		       TransactionType => 'Told'));
}

=head2 _SetTold

Updates the told without the transaction, that's  useful when we're sending replies.

=cut

sub _SetTold {
    my $self=shift;
    my $now = new RT::Date($self->CurrentUser);
    $now->SetToNow();
    return($self->_Set(Field => 'Told', 
		       Value => $now->ISO, 
		       RecordTransaction => 0));
}

# }}}

# {{{ sub Transactions 

=head2 Transactions

  Returns an RT::Transactions object of all
transactions on this ticket

=cut
  
sub Transactions {
    my $self = shift;
    
    unless ($self->CurrentUserHasRight('ShowTicketHistory')) {
	return (0, "Permission Denied");
    }
    
    
    use RT::Transactions;
    my $transactions = RT::Transactions->new($self->CurrentUser);
    $transactions->Limit( FIELD => 'Ticket',
			  VALUE => $self->id() );
    
    return($transactions);
}

# }}}

# {{{ sub _NewTransaction

sub _NewTransaction {
  my $self = shift;
  my %args = (TimeTaken => 0,
	     Type => undef,
	     OldValue => undef,
	     NewValue => undef,
	     Data => undef,
	     Field => undef,
	     MIMEObj => undef,
	     @_);
  
  
  require RT::Transaction;
  my $trans = new RT::Transaction($self->CurrentUser);
  my ($transaction, $msg) = 
      $trans->Create( Ticket => $self->Id,
		      TimeTaken => $args{'TimeTaken'},
		      Type => $args{'Type'},
		      Data => $args{'Data'},
		      Field => $args{'Field'},
		      NewValue => $args{'NewValue'},
		      OldValue => $args{'OldValue'},
		      MIMEObj => $args{'MIMEObj'}
		      );

  warn $msg unless $transaction;
  
  $self->_SetLastUpdated;
  
  if (defined $args{'TimeTaken'} ) {
    $self->_UpdateTimeTaken($args{'TimeTaken'}); 
  }
  return($transaction, $msg, $trans);
}

# }}}

# }}}

# {{{ PRIVATE UTILITY METHODS. Mostly needed so Ticket can be a DBIx::Record

# {{{ sub _Accessible

sub _Accessible {

  my $self = shift;  
  my %Cols = (
	      Queue => 'read/write',
	      Alias => 'read/write',
	      Requestors => 'read/write',
	      Owner => 'read/write',
	      Subject => 'read/write',
	      InitialPriority => 'read',
	      FinalPriority => 'read/write',
	      Priority => 'read/write',
	      Status => 'read/write',
	      TimeWorked => 'read/write',
	      TimeLeft => 'read/write',
	      Created => 'read/auto',
	      Creator => 'auto',
	      Told => 'read/write',
	      Resolved => 'read',
	      Starts => 'read,write',
	      Started => 'read,write',
	      Due => 'read/write',
	      LastUpdated => 'read/auto/public',
	      LastUpdatedBy => 'read/auto/public'


	     );
  return($self->SUPER::_Accessible(@_, %Cols));
}

# }}}

# {{{ sub _Set

sub _Set {
  my $self = shift;
  
  unless ($self->CurrentUserHasRight('ModifyTicket')) {
    return (0, "Permission Denied");
  }

  my %args = (Field => undef,
	      Value => undef,
	      TimeTaken => 0,
	      RecordTransaction => 1,
	      TransactionType => 'Set',
	      @_
	     );
  #if the user is trying to modify the record
  
  #Take care of the old value we really don't want to get in an ACL loop.
  # so ask the super::_Value
  my $Old=$self->SUPER::_Value("$args{'Field'}");

  #Set the new value
  my ($ret, $msg)=$self->SUPER::_Set(Field => $args{'Field'}, 
				     Value=> $args{'Value'});
  
  #If we can't actually set the field to the value, don't record
  # a transaction. instead, get out of here.
  if ($ret==0) {return (0,$msg);}
  
  if ($args{'RecordTransaction'} == 1) {
      
      my ($Trans, $Msg, $TransObj) =	
	$self->_NewTransaction(Type => $args{'TransactionType'},
			       Field => $args{'Field'},
			       NewValue => $args{'Value'},
			       OldValue =>  $Old,
			       TimeTaken => $args{'TimeTaken'},
			      );
      return ($Trans,$TransObj->Description);
  }
  else {
      return ($ret, $msg);
  }
}

# }}}

# {{{ sub _Value 

=head2 _Value

Takes the name of a table column.
Returns its value as a string, if the user passes an ACL check

=cut

sub _Value  {

  my $self = shift;
  my $field = shift;

  
  #if the field is public, return it.
  if ($self->_Accessible($field, 'public')) {
      $RT::Logger->debug("Skipping ACL check for $field\n");
      return($self->SUPER::_Value($field));
      
  }
  
  #If the current user doesn't have ACLs, don't let em at it.  
  
  unless ($self->CurrentUserHasRight('ShowTicket')) {
      return (0, "Permission Denied");
  }
  return($self->SUPER::_Value($field));
  
}

# }}}

# {{{ sub _UpdateTimeTaken

=head2 _UpdateTimeTaken

This routine will increment the timeworked counter. it should
only be called from _NewTransaction 

=cut

sub _UpdateTimeTaken {
  my $self = shift;
  my $Minutes = shift;
  my ($Total);
   
  $Total = $self->SUPER::_Value("TimeWorked");
  $Total = ($Total || 0) + ($Minutes || 0);
  $self->SUPER::_Set(Field => "TimeWorked", 
		     Value => $Total);

  return ($Total);
}

# }}}

# }}}

# {{{ Routines dealing with ACCESS CONTROL

# {{{ sub CurrentUserHasRight 

=head2 CurrentUserHasRight

  Takes the textual name of a Ticket scoped right (from RT::ACE) and returns
1 if the user has that right. It returns 0 if the user doesn't have that right.

=cut

sub CurrentUserHasRight {
  my $self = shift;
  my $right = shift;
  
  return ($self->HasRight( Principal=> $self->CurrentUser->UserObj(),
			    Right => "$right"));

}

# }}}

# {{{ sub HasRight 

=head2 HasRight

 Takes a paramhash with the attributes 'Right' and 'Principal'
  'Right' is a ticket-scoped textual right from RT::ACE 
  'Principal' is an RT::User object

  Returns 1 if the principal has the right. Returns undef if not.

=cut

sub HasRight {
    my $self = shift;
	my %args = ( Right => undef,
		     Principal => undef,
	 	     @_);
    
    unless ((defined $args{'Principal'}) and (ref($args{'Principal'}))) {
	$RT::Logger->warning("Principal attrib undefined for Ticket::HasRight");
    }
    
    return($args{'Principal'}->HasQueueRight(TicketObj => $self,
					     Right => $args{'Right'}));
    
    
}

# }}}

# }}}


1;

=head1 AUTHOR

Jesse Vincent, jesse@fsck.com

=head1 SEE ALSO

RT

=cut


  

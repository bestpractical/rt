# $Header$
# (c) 1996-2000 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL
#
package RT::Ticket;
use RT::User;
use RT::Record;
use RT::Link;
use RT::Links;
use RT::Date;
use Carp;

@ISA= qw(RT::Record);

# {{{ POD

=head1 NAME

 Ticket - Manipulate an RT Ticket Object

=head1 SYNOPSIS

  use RT::Ticket;
    ...
  my $ticket = RT::Ticket->new($self->CurrentUser);
  $ticket->Load($ticket_id);

  ....

=head1 DESCRIPTION
 
This module lets you manipulate RT's most key object. The Ticket.


=cut

# }}}

# {{{ sub new

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $self->{'table'} = "Tickets";
  $self->_Init(@_);
  return ($self);
}

# }}}

# {{{ sub Create

=over 10

=item Create (ARGS)

Arguments: ARGS is a hash of named parameters.  Valid parameters are:

    id 
    EffectiveId
    Queue  - Either a Queue object or a QueueId
    QueueTag
    Requestor -- A requestor object, if available.  Eventually taken from the MIME object.
    RequestorEmail -- the requestors email.  Eventually taken from Requestor or the MIME object
    Alias  -- unused
    Type --unused
    Owner -- is this a user id or a a username?
    Subject -- A string describing the subject of the ticket
    InitialPriority -- an integer from 0 to 99
    FinalPriority -- an integer from 0 to 99
    Status -- a textual tag. one of 'open' 'stalled' 'resolved' for now
    TimeWorked -- an integer
    Told -- a unix time. time of last contact (stubbed!)
    Due -- a unix time or an RT::Time object describing the due date (stubbed!)
    MIMEObj -- a MIME::Entity object with the content of the initial ticket request.

Returns: TICKETID, Transaction Object, Error Message

=cut


sub Create {
  my $self = shift;
  my ( $ErrStr, $Queue, $Owner);

  my %args = (id => undef,
	      EffectiveId => undef,
	      Queue => undef,
	      Requestor => undef,
	      RequestorEmail => undef,
	      Alias => undef,
	      Type => undef,
	      Owner => $RT::Nobody->UserObj,
	      Subject => '[no subject]',
	      InitialPriority => "0",
	      FinalPriority => "0",
	      Status => 'new',
	      TimeWorked => "0",
	      Due => "0",
	      MIMEObj => undef,
	      @_);

  #TODO Load queue defaults

  
  if ( (defined($args{'Queue'})) && (!ref($args{'Queue'})) ) {
    $Queue=RT::Queue->new($self->CurrentUser);
    $Queue->Load($args{'Queue'});
    #TODO error check this and return 0 if it's not loading properly
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

  if ( !defined($args{'Owner'})) {
	#TODO this shouldn't need to exist
	$Owner = $RT::Nobody->UserObj;
  }
  elsif ( (defined($args{'Owner'})) && (!ref($args{'Owner'})) ) {
    
    $Owner=RT::User->new($self->CurrentUser);
    $Owner->Load($args{'Owner'});
    #TODO error check this and return 0 if it's not loading properly
  }
  elsif (ref($args{'Owner'}) eq 'RT::User') {
        $Owner = $args{'Owner'};
  }
  else {
        $RT::Logger->err($args{'Owner'} . " not a recognised user object.");
   }

   #TODO: return an error if the owner can't own tickets in this queue ACL +++ 

   unless ($Queue->CurrentUserHasRight('CreateTicket')) {
    return (0,0,"Permission Denied");
  }

  #TODO we should see what sort of due date we're getting, rather +
  # than assuming it's in ISO format.
  my $due = new RT::Date($self->CurrentUser);
  $due->Set (Format => 'ISO',
	     Value => $args{'Due'});

  my $id = $self->SUPER::Create(Id => $args{'id'},
				EffectiveId => $args{'EffectiveId'},
				Queue => $Queue->Id,
				Alias => $args{'Alias'},
				Owner => $Owner->Id,
				Subject => $args{'Subject'},
				InitialPriority => $args{'InitialPriority'},
				FinalPriority => $args{'FinalPriority'},
				Priority => $args{'InitialPriority'},
				Status => $args{'Status'},
				TimeWorked => $args{'TimeWorked'},
				Due => $due->ISO
				
			       );
  
  #Load 'er up.
  $self->Load($id);

  #Now that we know the self
  (my $error, my $message) = $self->_Set(Field => "EffectiveId", 
					 Value => $id,
					 RecordTransaction => 0);
  if ($error == 0) {
      $RT::Logger->warning("Couldn't set EffectiveId for Ticket $id: $message.");
      return (0, 0, $message);
  }


  #TODO make sure this is doing the right thing +++
  if (defined $args{Requestor} || defined $args{RequestorEmail}) {
    my %watcher=(Type=>'Requestor');
    if (defined $args{RequestorEmail}) {
      $watcher{Email} = $args{RequestorEmail};
    }
    if (defined $args{Requestor}) {
      $watcher{Owner}=$args{Requestor}->Id;
      if  ( $args{RequestorEmail} && 
	    $args{RequestorEmail} eq $args{Requestor}->EmailAddress 
	  ) {
	delete $watcher{Email};
      }
    }
    $self->AddWatcher(%watcher);
  } 
  if (defined $args{'MIMEObj'}) {
    my $head = $args{'MIMEObj'}->head;
    
    require Mail::Address;
    
    unless (defined $args{'Requestor'} || defined $args{'RequestorEmail'}) {
      #Add the requestor to the list of watchers
      my $FromLine = $head->get('Reply-To') || $head->get('From') || $head->get('Sender');
      my @From = Mail::Address->parse($FromLine);
      
      foreach $From (@From) {
	$self->AddWatcher ( Email => $From->address,
			    Type => "Requestor");
      }
    }
    
    my @Cc = Mail::Address->parse($head->get('Cc'));
    foreach $Cc (@Cc) {
      $self->AddWatcher ( Email => $Cc->address,
			  Type => "Cc");
    }
    
  }
  #Add a transaction for the create
  my ($Trans, $Msg, $TransObj) = $self->_NewTransaction(Type => "Create",
					    TimeTaken => 0, 
					    MIMEObj=>$args{'MIMEObj'});
  
  # Logging
  if ($self->Id && $Trans) {
      $ErrStr='New request #'.$self->Id." (".$self->Subject.") created in queue ".
	  $self->QueueObj->QueueId;

      $RT::Logger->log(level=>'info', 
		       message=>$ErrStr);
  } else {
      $RT::Logger->log(level=>'warning', 
		       message=>"New request couldn't be successfully made; $ErrStr");
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
Scope
Owner

If the watcher you\'re trying to set has an RT account, set the Owner paremeter to their User Id. Otherwise, set the Email parameter to their Email address.

=cut

# TODO: Watchers might want to be notified when they're added or
# removed (both to tickets and queues) -- Tobix

sub AddWatcher {
  my $self = shift;
  my %args = ( Value => $self->Id(),
	       Email => undef,
	       Type => undef,
	       Scope => 'Ticket',
	       Owner => 0,
	       @_ );

  unless ($self->CurrentUserHasRight('ModifyTicket')) {
    return (0, "Permission Denied");
  }
  
  #TODO: Look up the Email that's been passed in to find the watcher's
  # user id. Set Owner to that value.
  
  require RT::Watcher;
  my $Watcher = new RT::Watcher ($self->CurrentUser);
  $Watcher->Create(%args);
  
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

DeleteWatcher takes an email address and removes that watcher
from this Ticket\'s list of watchers. It\'s currently insufficient, as many watchers will have a null email address and a
valid owner.

=cut


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

=item B<Takes>

=item I<nothing>

=item B<Returns>

=item String: All Ticket/Queue Requestors.

=cut

sub RequestorsAsString {
    my $self=shift;
    return _CleanAddressesAsString ($self->Requestors->EmailsAsString() );
}

=head2 WatchersAsString

WatchersAsString ...
=item B<Takes>

=item I<nothing>

=item B<Returns>

=item String: All Ticket/Queue Watchers.

=cut

sub WatchersAsString {
    my $self=shift;
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
    return _CleanAddressesAsString ($self->Cc->EmailsAsString() . ", ".
		  $self->QueueObj->Cc->EmailsAsString());
}

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

# {{{ Routines that return RT::Watchers objects of Requestors, Ccs and AdminCcs

# {{{ sub Requestors
sub Requestors {
  my $self = shift;

  unless ($self->CurrentUserHasRight('ShowTicket')) {
    return (0, "Permission Denied");
  }

  if (! defined ($self->{'Requestors'})) {
    require RT::Watchers;
    $self->{'Requestors'} = RT::Watchers->new($self->CurrentUser);
    $self->{'Requestors'}->LimitToTicket($self->id);
    $self->{'Requestors'}->LimitToRequestors();
  }
  return($self->{'Requestors'});
  
}
# }}}

# {{{ sub Cc
# (see AdminCc comments!)
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
# TODO: Should this also return queue watchers?
# ...and are this used anywhere anyway?
# -- TobiX
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
sub IsWatcher {
my $self = shift;

my @args = (Type => 'Requestor',
	    Id => undef);


carp "Ticket::IsWatcher unimplemented";
return (0);
#TODO Implement. this sub should perform an SQL match along the lines of the ACL check

}
# }}}

# {{{ sub IsRequestor

sub IsRequestor {
  my $self = shift;
  my $whom = shift;

  my $mail;

  #TODO uncomment the line below and blow away the rest of the sub once IsWatcher is done.
  #return ($self->IsWatcher(Type => 'Requestor', Id => $whom);

  if (ref $whom eq "Mail::Address") {
    $mail=$whom->Address;
  } elsif (ref $whom eq "RT::User") {
    $mail=$whom->EmailAddress;
  } elsif (!ref $whom) {
    $mail=$whom;
  }
  
  #if the requestors string contains the username
  if ($self->RequestorsAsString() =~ /$mail/) {
    return(1);
  }
  else {
    return(undef);
  }
};

# }}}

# {{{ sub IsCc

sub IsCc {
  my $self = shift;
  my $cc = shift;
  
  return ($self->IsWatcher( Type => 'Cc', Identifier => $cc ));
  
}

# }}}

# {{{ sub IsAdminCc

sub IsAdminCc {
  my $self = shift;
  my $bcc = shift;
  
  return ($self->IsWatcher( Type => 'Bcc', Identifier => $bcc ));
  
}

# }}}

# }}}

# }}}

# {{{ Routines dealing with queues 

# {{{ sub ValidateQueue

sub ValidateQueue {
  my $self = shift;
  my $Value = shift;
  
  #TODO I don't think this should be here. We shouldn't allow anything to have an undef queue,
  if (!$Value) {
    carp " RT:::Queue::ValidateQueue called with a null value. this isn't ok.";
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
    elsif (!$NewQueueObj->CurrentUserHasRight('CreateTickets')) {
      return (0, "You may not create requests in that queue.");
    }
    elsif (!$NewQueueObj->HasRight('CreateTickets',$self->OwnerObj)) {
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
    $self->{'queue'} = RT::Queue->new($self->CurrentUser);
    #We call SUPER::_Value so that we can avoid the ACL decision and some deep recursion
    my ($result) = $self->{'queue'}->Load($self->SUPER::_Value('Queue'));

  }
  return ($self->{'queue'});
}


# }}}

# }}}

# {{{ Date printing routines

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


# {{{ sub ResolvedObj
sub ResolvedObj {
  my $self = shift;

  my $time = new RT::Date($self->CurrentUser);
  $time->Set(Format => 'sql', Value => $self->Resolved);
  return $time;
}
# }}}

# {{{ sub Start
=head2 Start

Takes a date in ISO format or undef
Returns a transaction id and a message
Start is used by PM, RT's Project Managment app.
The client calls "Start" to note that the project was started on the date in $date.
A null date means "now"

=cut

sub Start {
my $self = shift;
my $time = shift || 0;

#We create a date object to catch date weirdness
my $time_obj = new RT::Date($self->CurrentUser());
if ($time != 0)  {
$time_obj->Set(Format => 'ISO', Value => $value);
}
else {
$time_obj->SetToNow();
}
#Now that we're starting, open this ticket
$self->Open;
return ($self->_Set(Field => 'Started', Value =>$time_obj->ISO));

}
#}}}

# {{{ sub StartedObj
sub StartedObj {
  my $self = shift;

  my $time = new RT::Date($self->CurrentUser);
  $time->Set(Format => 'sql', Value => $self->Started);
  return $time;
}
# }}}

# {{{ sub StartsObj
sub StartsObj {
  my $self = shift;

  my $time = new RT::Date($self->CurrentUser);
  $time->Set(Format => 'sql', Value => $self->Starts);
  return $time;
}
# }}}



# {{{ sub ToldObj

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

#takes a subject, a cc list, a bcc list
sub Comment {
  my $self = shift;
  
  my %args = (BccMessageTo => undef,
	      CcMessageTo => undef,
	      MIMEObj => undef,
	      TimeTaken => 0,
	      @_ );

  unless ($self->CurrentUserHasRight('CommentOnTicket')) {
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
    warn "RT::Ticket::Comment needs to send mail to explicit CCs and BCCs";
  }
  
  return ($Trans, "The comment has been recorded");
}

# }}}

# {{{ sub Correspond

sub Correspond {
  my $self = shift;
  my %args = ( CcMessageTo => undef,
	       BccMessageTo => undef,
	       MIMEObj => undef,
	       TimeTaken => 0,
	       @_ );
  unless ($self->CurrentUserHasRight('CorrespondOnTicket')) {
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
      warn "stub"
    }
  
  unless ($Trans) {
      # TODO ... check what errors might be catched here, and deal
    # better with it
    warn;
    return ($Trans, "correspondence (probably) NOT sent", $args{'MIMEObj'});
  }

  my $T=RT::Transaction->new($self->CurrentUser);
  $T->Load($Trans);
  unless ($T->IsInbound) {
    # TODO: Should we record a transaction here or not?  I'll avoid it as
    # for now - because the transaction will involve an extra email.
    # -- TobiX
    $self->_UpdateTold;
  }

  return ($Trans, "correspondence (probably) sent", $args{'MIMEObj'});
}

# }}}

# }}}

# {{{ Routines dealing with keywords

# TODO: Implement keywords

# {{{ sub Keywords

sub Keywords {
  my $self = shift;
  #TODO Implement
  return($self->{'article_keys'});
}

# }}}

# {{{ sub NewKeyword
# TODO: keywords not implemented?
sub NewKeyword {
  my $self = shift;
  my $keyid = shift;
  
    my ($keyword);
  
  $keyword = new RT::Article::Keyword($self->CurrentUser);
  return($keyword->create( keyword => "$keyid",
			   article => $self->id));
  
  #reset the keyword listing...
  $self->{'article_keys'} = undef;
  return();
}
# }}}

# {{{ sub HasKeyword
sub HasKeyword {
  my $self = shift;
  
  die "HasKeyword stubbed";
}
# }}}
# }}}

# {{{ Routines dealing with Links and Relations between tickets

#TODO: This is not done.
#
# What do we need?

# directly from the web ticket display as of today:

# _all_ links (to and from).  How to tell EasySearch that?

# all unresolved dependencies (how to tell if a dependency is
# unresolved?  Dependencies can point out of this RT instance!)

# What else?

# all members ... this one is already used in my Action, I'd
# daresay.  The "pick all members"-logic should be moved to this file.

# - (all) parent(s)/group ticket ...


# {{{ sub Members

=head2 Members

  This returns an RT::Links object which references all the tickets that have 
this ticket as their target AND are of type 'MemberOf'

=cut

sub Members {
    my $self = shift;
    return $self->_Links('Target','MemberOf');
}


# }}}

# {{{ sub MemberOf

=head2 MemberOf

  This returns an RT::Links object which references all the tickets that have 
this ticket as their base AND are of type 'MemberOf'

=cut

sub MemberOf {
    my $self = shift;
    return $self->_Links('Base','MemberOf');
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


  #TODO: Field isn't the right thing here. but I ahave no idea what mnemonic
  #tobias meant by $f
  my $field = shift;
  my $type =shift || "";
    unless (exists $self->{"$field$type"}) {
	
	$self->{"$field$type"} = new RT::Links($self->CurrentUser);
	$self->{"$field$type"}->Limit(FIELD=>$field, VALUE=>$self->id);
	$self->{"$field$type"}->Limit(FIELD=>'Type', VALUE=>$type) if ($type);
    }
    return ($self->{"$field$type"});
}

# }}}

# {{{ sub AllLinks
# this should return a reference to an RT::Links object which contains
# all links to or from the current ticket

sub AllLinks {
  my $self= shift;
  #TODO this should work
  die "Stub!";
  
#  if (! $self->{'all_links'}) {
#      $self->{'all_links'} = new RT::Links($self->CurrentUser);
#    $self->{'all_links'}->Limit(FIELD => 'article',
#					      VALUE => $self->id);
#  }
#  return($self->{'pointer_to_links_object'});
}
# }}}

# {{{ sub URI 

sub URI {
    my $self = shift;
    return "fsck.com-rt://$rt::domain/$rt::rtname/ticket/".$self->id;
}

# }}}

# {{{ sub Merge

sub Merge {
  my $self = shift;
  my $MergeInto = shift;
  
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

sub LinkTo {
    my $self = shift;
    my %args = ( dir => 'T',
		 Base => $self->id,
		 Target => '',
		 Type => '',
		 @_ );
    $self->_NewLink(%args);
}

# }}}

# {{{ sub LinkFrom
sub LinkFrom {
    my $self = shift;
    my %args = ( dir => 'F',
		 Base => '',
		 Target => $self->id,
		 Type => '',
		 @_);
    $self->_NewLink(%args);
}

# }}}

# {{{ sub _NewLink

sub _NewLink {
  my $self = shift;
  my %args = ( dir => '',
	       Target => '',
	       Base => '',
	       Type => '',
	       @_ );

  # {{{ We don't want references to ourself
  return (0,"You're linking up yourself, that doesn't make sense",0) 
      if ($args{Base} eq $args{Target});
  # }}}

  # {{{ Check if the link already exists - we don't want duplicates
  my $Links=RT::Links->new($self->CurrentUser);
  $Links->Limit(FIELD=>'Type',VALUE => $args{Type});
  $Links->Limit(FIELD=>'Base',VALUE => $args{Base});
  $Links->Limit(FIELD=>'Target',VALUE => $args{Target});
  my $l=$Links->First;
  if ($l) {
      $RT::Logger->log(level=>'info', 
		       message=>"Somebody tried to duplicate a link");
      return ($l->id, "Link already exists", 0);
  }
  # }}}

  # TODO: URIfy local tickets
 
  # Storing the link in the DB.
  my $link = RT::Link->new($self->CurrentUser);
  my ($linkid) = $link->Create(Target => $args{Target}, Base => $args{Base}, Type => $args{Type});

  #Write the transaction
  my $b;
  my $t;
  if ($args{dir} eq 'T') {
      $t=$args{Target};
      $b='THIS';
  } else {
      $t='THIS';
      $b=$args{Base};
  }
  my $TransString="$b $args{Type} $t as of $linkid";
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

#TODO ACL ++
sub OwnerObj {
  my $self = shift;

  defined ($self->_Value('Owner')) || return undef;
	
  #If the owner object ain't loaded yet
  if (! exists $self->{'owner'})  {
    require RT::User;
    $self->{'owner'} = new RT::User ($self->CurrentUser);
    $self->{'owner'}->Load($self->_Value('Owner'));
  }
  
  # We return an empty owner object rather than undef because a ticket
  # without an owner may have Owner methods called on it.  Is this moot now that
  # nobody is an explicit user
  
  
  #Return the owner object
  return ($self->{'owner'});
}

# }}}

# {{{ sub OwnerAsString 
sub OwnerAsString {
  my $self = shift;
  return($self->OwnerObj->EmailAddress);

}

# }}}

# {{{ sub SetOwner

sub SetOwner {
  my $self = shift;
  my $NewOwner = shift;
  my $Type = shift || "Give";
  my ($NewOwnerObj);

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
  elsif (($NewOwnerObj) and (!$NewOwnerObj->HasTicketRight(Right => 'OwnTicket',
							   TicketObj => $self,
							))) {
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

  delete $self->{'owner'};
  return ($trans, 
	  ($trans 
	  ? ("Owner changed from ".$OldOwnerObj->UserId." to ".$NewOwnerObj->UserId)
	  : $msg));
}

# }}}

# {{{ sub Take
sub Take {
  my $self = shift;
  $RT::Logger->debug("in RT::Ticket->Take()");
  my ($trans,$msg)=$self->SetOwner($self->CurrentUser->Id, 'Take');
  if ($trans == 0) {
	return (0, $msg);
  }
  return ($trans, $msg);
}
# }}}

# {{{ sub Untake
sub Untake {
  my $self = shift;
  my ($trans,$msg)=$self->SetOwner($RT::Nobody->UserObj, 'Untake');
  return ($trans, 
	  $trans 
	  ? "Ticket untaken"
	  : $msg);
}
# }}}

# {{{ sub Steal 

sub Steal {
  my $self = shift;
  
  if (!$self->CurrentUserHasRight('ModifyTicket')){
    return (0,"Permission Denied");
  }
  elsif ($self->OwnerObj->Id eq $self->CurrentUser->Id ) {
    return (0,"You already own this ticket"); 
  }
  else {
      my ($trans,$msg)=$self->SetOwner($self->CurrentUser->Id, 'Steal'); 
      return ($trans, 
	      $trans 
	      ? "Ticket stolen"
	      : $msg);
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
    #&open_parents($in_serial_num, $in_current_user) || $transaction_num=0; 
    #TODO: we need to check for open parents.
  }
 


  return($self->_Set(Field => 'Status', 
		     Value => $status,
		     TimeTaken => 0,
		     TransactionType => 'Status'));
}
# }}}

# {{{ sub Kill
sub Kill {
  my $self = shift;
  return ($self->SetStatus('dead'));
  # TODO: garbage collection
}
# }}}

# {{{ sub Stall
sub Stall {
  my $self = shift;
  return ($self->SetStatus('stalled'));
}
# }}}

# {{{ sub Open
sub Open {
  my $self = shift;
  return ($self->SetStatus('open'));
}
# }}}

# {{{ sub Resolve
sub Resolve {
  my $self = shift;
  return ($self->SetStatus('resolved'));
}
# }}}

# }}}

# {{{ sub UpdateTold and _UpdateTold

# UpdateTold - updates the told and makes a transaction

sub UpdateTold {
    my $self=shift;
    my $timetaken=shift || 0;
    my $now = new RT::Date($self->CurrentUser);
    $now->SetToNow(); 

    return($self->_Set(Field => 'Told', 
		       Value => $now->ISO,
		       TimeTaken => $timetaken,
		       TransactionType => 'Told'));
}

# _UpdateTold - updates the told without the transaction, that's
# useful when we're sending replies.

sub _UpdateTold {
    my $self=shift;
    my $now = new RT::Date($self->CurrentUser);
    $now->SetToNow();
    return($self->_Set(Field => 'Told', 
		       Value => $now->ISO, 
		       UpdateTransaction => 0));
}

# }}}

# {{{ sub Transactions 

# Get the right transactions object. 
sub Transactions {
  my $self = shift;

  unless ($self->CurrentUserHasRight('ShowTicketHistory')) {
    return (0, "Permission Denied");
  }
  
  if (!$self->{'transactions'}) {
    use RT::Transactions;
    $self->{'transactions'} = RT::Transactions->new($self->CurrentUser);
    $self->{'transactions'}->Limit( FIELD => 'EffectiveTicket',
                                    VALUE => $self->id() );
  }
  return($self->{'transactions'});
}

# }}}

# {{{ sub NewTransaction

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
      $trans->Create( Ticket => $self->EffectiveId,
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
	      TimeLeft => 'read/write',
	      Created => 'read/auto',
	      Creator => 'auto',
	      Told => 'read',
	      Resolved => 'read',
	      Starts => 'read',
	      Started => 'read',
	      LastUpdated => 'read/auto',
	      LastUpdatedBy => 'read/auto',
	      Due => 'read/write'

	     );
  return($self->SUPER::_Accessible(@_, %Cols));
}

# }}}

# {{{ sub _Set

#This subclasses rt::record
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
  
  #Take care of the old value we really don't want to get in an ACL loop. so ask the super::_Value
  my $Old=$self->SUPER::_Value("$args{'Field'}");
  #Set the new value
  my ($ret, $msg)=$self->SUPER::_Set(Field => $args{'Field'}, 
				     Value=> $args{'Value'});
  
  #record the transaction
  $ret or return (0,$msg);
    
  if ($args{'RecordTransaction'} == 1) {
      my ($Trans, $Msg, $TransObj) =	$self->_NewTransaction 
	(Type => $args{'TransactionType'},
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

sub _Value  {

  my $self = shift;
  my $field = shift;

 #If the current user doesn't have ACLs, don't let em at it.  
 
 unless ($self->CurrentUserHasRight('ShowTicket')) {
    return (0, "Permission Denied");
  }
  
  return($self->SUPER::_Value($field));
  
}

# }}}

# {{{ sub _UpdateTimeTaken

#This routine will increment the timeworked counter. it should
#only be called from _NewTransaction 

sub _UpdateTimeTaken {
  my $self = shift;
  my $Minutes = shift;
  my ($Total);
   
  $Total = $self->_Value("TimeWorked");
  $Total = ($Total || 0) + ($Minutes || 0);
  $self->_Set(Field => "TimeWorked", 
	      Value => $Total, 
	      RecordTransaction => 0);
  return ($Total);
}

# }}}

# {{{ sub _SetLastUpdated
sub _SetLastUpdated {
  my $self = shift;

  #TODO ACL this ++
  $self->SUPER::_SetLastUpdated();
}
# }}}

# }}}

# {{{ Routines dealing with ACCESS CONTROL

# {{{ sub CurrentUserHasRight 
sub CurrentUserHasRight {
  my $self = shift;
  my $right = shift;
  
  return ($self->HasRight( Principal=> $self->CurrentUser->UserObj(),
			    Right => "$right"));

}

# }}}

# {{{ sub HasRight 

# TAKES: Right and optional "Principal" 
sub HasRight {
    my $self = shift;
	my %args = ( Right => undef,
		     Principal => undef,
	 	     @_);

	unless ((defined $args{'Principal'}) and (ref($args{'Principal'}))) {
		$RT::Logger->warn("Principal attrib undefined for Ticket::HasRight");
	}
       
	return($args{'Principal'}->HasTicketRight(TicketObj => $self, 
						  Right => $args{'Right'}));
	
	    
	#TODO this needs to move into User.pm's 'hasTicketRight'

    $PrincipalsClause .= " OR (PrincipalType = 'Owner') "  if ($actor == $self->OwnerObj->Id);
    $PrincipalsClause .= "OR (PrincipalType = 'TicketRequestor') " if ($self->IsRequestor($actor));
    $PrincipalsClause .= "OR (PrincipalType = 'TicketCc') " if  ($self->IsCc($actor));
    $PrincipalsClause .= "OR (PrincipalType = 'TicketAdminCc') " if ($self->IsAdminCc($actor));
}

# }}}

# }}}

1;

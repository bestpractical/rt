# $Header$
# (c) 1996-2000 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL
#

package RT::Ticket;
use RT::Record;
use RT::Link;
@ISA= qw(RT::Record);

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

sub Create {
  my $self = shift;
  
  my %args = (id => undef,
	      EffectiveId => undef,
	      Queue => undef,
	      QueueTag => undef,
	      Requestor => undef,
	      Alias => undef,
	      Type => undef,
	      Owner => $RT::Nobody,
	      Subject => undef,
	      InitialPriority => 0,
	      FinalPriority => 0,
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
				Owner => $args{'Owner'} || $RT::Nobody,
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
  (my $code, my $message) = $self->SUPER::_Set("EffectiveId",$id);
  if ($code == 0) {
    warn $message;
  }
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

  }
  #Add a transaction for the create
  my $Trans = $self->_NewTransaction(Type => "Create",
				     TimeTaken => 0, 
				     MIMEEntity=>$args{'MIMEEntity'});
  
  
  return($self->Id, $Trans, $ErrStr);
}

# }}}

# {{{ Routines dealing with watchers.

# {{{ sub AddWatcher

=head2 AddWatcher

AddWatcher takes a parameter hash. The keys are as follows:

Email
Type
Scope
Owner

If the watcher you\'re trying to set has an RT account, set the Owner paremeter to their User Id. Otherwise, set the Email parameter to their Email address.

=cut


sub AddWatcher {
  my $self = shift;
  my %args = ( Value => $self->Id(),
	       Email => undef,
	       Type => undef,
	       Scope => 'Ticket',
	       Owner => 0,
	       @_ );

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

# TODO: Should this one only return the _ticket_ watchers or the queue
# + ticket watchers?  I think the latter would make most sense, and
# the current AdminCcAsString and CcAsString subs (which are used for
# mail sending) is using this sub. -- TobiX

# It should return only the ticket watchers. the actual FooAsString
# methods capture the queue watchers too. I don't feel thrilled about this,
# but we don't want the Cc Requestors and AdminCc objects to get filled up
# with all the queue watchers too. we've got seperate objects for that.
  # should we rename these as s/(.*)AsString/$1Addresses/ or somesuch?

=cut

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
		  $self->Queue->Watchers->EmailsAsString());
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
		  $self->Queue->AdminCc->EmailsAsString());
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
		  $self->Queue->Cc->EmailsAsString());
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

# {{{ sub Requestors
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
# }}}

# {{{ sub Cc
# (see also AdminCc comments)
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

# }}}

# {{{ sub AdminCc
# TODO: Should this also return queue watchers?
# ...and are this used anywhere anyway?
# -- TobiX
sub AdminCc {
  my $self = shift;
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

# {{{ Routines dealing with queues 

# {{{ sub ValidateQueue

sub ValidateQueue {
  my $self = shift;
  my $Value = shift;
  if (!$Value) {
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
    

    else {
      return($self->_Set('Queue', $NewQueueObj->Id()));
    }
  }
  else {
    return (0,"No queue specified");
  }
}
# }}}

# {{{ sub Queue
sub Queue {
  my $self = shift;
  if (!$self->{'queue'})  {
    require RT::Queue;
    $self->{'queue'} = RT::Queue->new($self->CurrentUser);
    $self->{'queue'}->Load($self->_Value('Queue'));
  }
  return ($self->{'queue'});
}
# }}}

# }}}

# {{{ Routines dealing with ownership

# {{{ sub Owner

sub Owner {
  my $self = shift;

  defined ($self->_Value('Owner')) || return undef;
	
  #If the owner object ain't loaded yet
  if (! exists $self->{'owner'})  {
    require RT::User;
    $self->{'owner'} = new RT::User ($self->CurrentUser);
    $self->{'owner'}->Load($self->_Value('Owner'));
  }
  
  #TODO It feels unwise, but we're returning an empty owner
  # object rather than undef.
  
  #Return the owner object
  return ($self->{'owner'});
}

# }}}

# {{{ sub OwnerAsString 
sub OwnerAsString {
  my $self = shift;
  return($self->Owner->EmailAddress);

}

# }}}

# {{{ sub Take
sub Take {
  my $self = shift;
  return($self->SetOwner($self->CurrentUser->Id, 'Take'));
}
# }}}

# {{{ sub Untake
sub Untake {
  my $self = shift;
  return($self->SetOwner($RT::Nobody, 'Untake'));
}
# }}}

# {{{ sub Steal 
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
    return($self->_Set('owner',$self->CurrentUser->Id, 'Steal'));
  }
    
}
# }}}

# {{{ sub SetOwner

sub SetOwner {
  my $self = shift;
  my $NewOwner = shift;
  my $Type = shift;
  my $more_params={};
  $more_params->{TransactionType}=$Type if $Type;
  my ($NewOwnerObj);

  require RT::User;
  $NewOwnerObj = RT::User->new($self->CurrentUser);
  
  if (!$NewOwnerObj->Load($NewOwner)) {
    
    return (0, "That user does not exist");
  }
  
  
  #If thie ticket has an owner and it's not the current user

  # TODO: check this
  
  if ($Type ne 'Steal' and 
      $self->Owner->Id!=$RT::Nobody and 
      $self->CurrentUser->Id ne $self->Owner->Id()) {
    
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
  #	return (0,"That user doesn't have permission to modify this request");
  #	}
  
  else {
    #TODO
    #If we're giving the request to someone other than $self->CurrentUser
    #send them mail
  }

  return($self->_Set('Owner',$NewOwnerObj->Id,0,$more_params));
}

# }}}

# }}}

# {{{ Routines dealing with status


# {{{ sub SetStatus
sub SetStatus { 
  my $self = shift;
  my $status = shift;
  my $action = shift;
  
  if (($status ne 'open') and ($status ne 'stalled') and 
      ($status ne 'resolved') and ($status ne 'dead') ) {
    return (0,"That status is not valid.");
  }
  
  if ($status eq 'resolved') {

    #&open_parents($in_serial_num, $in_current_user) || $transaction_num=0; 
    #TODO: we need to check for open parents.
  }
  
  return($self->_Set('Status',$status, 0,{TransactionType=>$action}));
}
# }}}

# {{{ sub Kill
sub Kill {
  my $self = shift;
  return ($self->SetStatus('dead', 'Kill'));
  # TODO: garbage collection
}
# }}}

# {{{ sub Stall
sub Stall {
  my $self = shift;
  return ($self->SetStatus('stalled', 'Stall'));
}
# }}}

# {{{ sub Owner
sub Open {
  my $self = shift;
  return ($self->SetStatus('open', 'Open'));
}
# }}}

# {{{ sub Resolve
sub Resolve {
  my $self = shift;
  return ($self->SetStatus('resolved', 'Resolve'));
}
# }}}

# }}}

# {{{ Date printing routines


# {{{ sub DueAsString 
sub DueAsString {
  my $self = shift;
  if ($self->Due) {
    return (scalar(localtime($self->Due)));
  }
  else {
    return("Never");
  }
}
# }}}

# {{{ sub CreatedAsString
sub CreatedAsString {
  my $self = shift;
  return (scalar(localtime($self->Created)));
}
# }}}

# {{{ sub ToldAsString
sub ToldAsString {
  my $self = shift;
  if ($self->Due) {
    return (scalar(localtime($self->Told)));
  }
  else {
    return("Never");
  }
}
# }}}

# {{{ #sub LastUpdatedAsString
sub LastUpdatedAsString {
  my $self = shift;
  if ($self->Due) {
    return (scalar(localtime($self->LastUpdated)));
  }
  else {
    return("Never");
  }
}
# }}}

# }}}

# {{{ Routines dealing with requestor metadata

# {{{ sub Notify
sub Notify {
    my $self = shift;
    return ($self->_Set("Told",time()));
}
# }}}

# {{{ sub SinceTold
sub SinceTold {
  my $self = shift;
  return ("Ticket->SinceTold unimplemented");
}
# }}}

# {{{ sub Age
sub Age {
  my $self = shift;
  return("Ticket->Age unimplemented\n");
}
# }}}

# }}}

# {{{ Routines dealing with ticket relations

# {{{ sub Merge
sub Merge {
  my $self = shift;
  my $MergeInto = shift;
  
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

# }}}

# {{{ Routines dealing with correspondence/comments

# {{{ sub Comment
#takes a subject, a cc list, a bcc list
sub Comment {
  my $self = shift;
  
  # MIMEObj here ... and MIMEEntity somewhere else ... it would have been better
  # to be consistant.  But hey - it works!  We'll just leave it here as for now.
  # -- TobiX
  my %args = (BccMessageTo => undef,
	      CcMessageTo => undef,
	      MIMEObj => undef,
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

  if ($args{'CcMessageTo'} || 
      $args{'BccMessageTo'} ) {
      #send a copy of the correspondence to the CC list and BCC list
      warn "Stub!";
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
  
  # This is no longer true. -- jv


  if ($args{BccMessageTo} || 
      $args{CcMessageTo}) {
      warn "stub"
  }
  
  return ($Trans, "correspondence (probably) sent", $MIME);
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
  
  $keyword = new RT::Article::Keyword;
  return($keyword->create( keyword => "$keyid",
			   article => $self->id));
  
  #reset the keyword listing...
  $self->{'article_keys'} = undef;
  return();
}
# }}}

# }}}

# {{{ Routines dealing with links

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

#
# {{{ sub AllLinks
sub AllLinks {
  my $self= shift;
  die "Stub!";
  
#  if (! $self->{'all_links'}) {
#      $self->{'all_links'} = new RT::Links;
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

# {{{ Static sub "URIIsLocal" checks whether an URI is local or not
sub URIIsLocal {
    my $URI=shift;
    # TODO: More thorough check
    $URI =~ /^(\d+)$/;
    return $1;
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
    $self->_NewLink(target=>$self->id, %args);
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
 
  # Storing the link in the DB.
  my $link = RT::Link->new($self->CurrentUser);
  my ($linkid) = $link->Create(Target => $args{Target}, Base => $args{Base}, Type => $args{Type});

  #Write the transaction
  my $b;
  my $t;
  if ($args{dir} eq 'F') {
      $b=$args{Base};
      $t='THIS';
  } else {
      $b='THIS';
      $t=$args{Target};
  }
  my $Trans = $self->_NewTransaction
      (Type => 'Link',
       Data => "$b $args{Type} $t as of $linkid",
       TimeTaken => 0 # Is this always true?
       );
  
  return ($linkid, "Link created", $transactionid);
}

# }}}
 
# }}}

# {{{ Routines dealing with transactions

# {{{ sub Transactions 

# Get the right transactions object. 
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
	     MIMEEntity => undef,
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
		      MIMEEntity => $args{'MIMEEntity'}
		      );

  warn $msg unless $transaction;
  
  $self->_UpdateDateActed;
  
  if (defined $args{'TimeTaken'} ) {
    $self->_UpdateTimeTaken($args{'TimeTaken'}); 
  }
  return($trans);
}
# }}}

# }}}

# {{{ UTILITY METHODS
    
# {{{ sub IsRequestor
sub IsRequestor {
  my $self = shift;
  my $whom = shift;

  my $mail;

  #Todo: more advanced checking

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

# {{{ PRIVATE UTILITY METHODS

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
	      Created => 'read',
	      Told => 'read',
	      LastUpdated => 'read',
	      LastUpdatedBy => 'read',
	      Due => 'read/write'

	     );
  return($self->SUPER::_Accessible(@_, %Cols));
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
  $self->SUPER::_Set("TimeWorked", $Total);
  return ($Total);
}
# }}}

# {{{ sub _UpdateDateActed
sub _UpdateDateActed {
  my $self = shift;
  $self->SUPER::_Set('LastUpdated',undef);
}
# }}}

# {{{ sub _Set

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
    
    #TODO: what the hell are moreoptions?

    # Generally, more options that are needed for doing the
    # transaction correct.  I'm just using "TransactionType" which
    # usually differs from "Set".  I'd agree "MoreOptions" seems a bit
    # kludgy, the "new" calling style should have been used instead 
    # -- 
    # TobiX

    my $MoreOptions = shift if @_;
    
    $TimeTaken = 0 if (!defined $TimeTaken);

    #record what's being done in the transaction
    $self->_NewTransaction (Type => $MoreOptions->{'TransactionType'}||"Set",
			    Field => $Field,
			    NewValue => $Value || undef,
			    OldValue =>  $self->_Value("$Field") || undef,
			    TimeTaken => $TimeTaken || 0
			   );
    $self->SUPER::_Set($Field, $Value);
  }
  
}
# }}}

# }}}

# }}}

# {{{ Routines dealing with ACCESS CONTROL

# {{{ sub _HasRight 

# TAKES: Right and optional "Actor" which defaults to the current user
sub _HasRight {
    my $self = shift;
    #TODO For now, they always do
    return(1);

    my $right = shift;
    # by default, the actor is the current user
    if (!@_) {
	my $actor = $self->CurrentUser->Id();
    }
    else {
	my $actor = shift;   
    }
  
    return ($self->Queue->_HasRight(@_));
}

# }}}

# {{{ sub DisplayPermitted
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
# }}}

# {{{ sub ModifyPermitted

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

# }}}

# {{{ sub AdminPermitted

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

# }}}

# }}}
1;




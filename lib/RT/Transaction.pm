# $Header$
# Copyright 1999-2000 Jesse Vincent <jesse@fsck.com>
# Released under the terms of the GNU Public License

package RT::Transaction;
use RT::Record;
@ISA= qw(RT::Record);

# {{{ sub new 
sub new  {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);

  $self->{'table'} = "Transactions";
  $self->_Init(@_);


  return ($self);
}
# }}}

# {{{ sub Create 

=head2 Create

Create a new transaction
TODO: Document what gets passed to this
=cut

sub Create  {
    my $self = shift;
    my %args = ( id => undef,
		 TimeTaken => 0,
		 Ticket => 0 ,
		 Type => 'undefined',
		 Data => '',
		 Field => undef,
		 OldValue => undef,
		 NewValue => undef,
		 MIMEObj => undef,
		 @_
	       );
    
    #if we didn't specify a ticket, we need to bail
    unless ( $args{'Ticket'} ) {
	return(0, "RT::Transaction->Create couldn't, as you didn't specify a ticket id");
    }
    
    
    
    #lets create our transaction
    my $id = $self->SUPER::Create(Ticket => $args{'Ticket'},
				  EffectiveTicket  => $args{'Ticket'},
				  TimeTaken => $args{'TimeTaken'},
				  Type => $args{'Type'},
				  Data => $args{'Data'},
				  Field => $args{'Field'},
				  OldValue => $args{'OldValue'},
				  NewValue => $args{'NewValue'},
				 );
    $self->Load($id);
    $self->_Attach($args{'MIMEObj'})
      if defined $args{'MIMEObj'};
    
    #We're really going to need a non-acled ticket for the scrips to work
    #TODO this MUST be as the "System" principal or it all breaks
    my $TicketAsSystem = RT::Ticket->new($RT::SystemUser);
    $TicketAsSystem->Load($args{'Ticket'}) || 
      $RT::Logger->err("RT::Transaction couldn't load $args{'Ticket'}\n");
    
    # {{{ Deal with Scrips
    
    #Load a scripscopes object
    use RT::ScripScopes;
    my $PossibleScrips = RT::ScripScopes->new($RT::SystemUser);
    $PossibleScrips->LimitToQueue($TicketAsSystem->QueueObj->Id); #Limit it to queue 0 or $Ticket->QueueObj->Id
    
    my $ScripsAlias = $PossibleScrips->NewAlias(Scrips);
    
  $PossibleScrips->Join(ALIAS1 => 'main',  FIELD1 => 'Scrip',
			   ALIAS2 => $ScripsAlias, FIELD2=> 'id');
    
    
    #We only want things where the scrip applies to this sort of transaction
    $PossibleScrips->Limit(ALIAS=> $ScripsAlias,
			   FIELD=>'Type',
			   OPERATOR => 'LIKE',
			   VALUE => $args{'Type'},
			   ENTRYAGGREGATOR => 'OR',
			  );
    
    # Or where the scrip applies to any transaction
    $PossibleScrips->Limit(ALIAS=> $ScripsAlias,
			   FIELD=>'Type',
			   OPERATOR => 'LIKE',
			   VALUE => "Any",
			   ENTRYAGGREGATOR => 'OR',
			  );			    
    
    $RT::Logger->debug("$self: Searching for scrips for transaction #".$self->Id.
		       " (".$self->Type()."), ticket #".$TicketAsSystem->Id."\n");
    
    #Iterate through each script and check it's applicability.
    
    while (my $Scrip = $PossibleScrips->Next()) {
      
      #TODO: properly deal with errors raised in this scrip loop
      
      eval {
	#local $SIG{__DIE__} = sub { $RT::Logger->debug($_[0])};
	
	#Load the scrip's action;
	$Scrip->ScripObj->LoadAction(TicketObj => $TicketAsSystem, 
				     TemplateObj => $Scrip->ScripObj->TemplateObj,
				     TransactionObj => $self);
	
	
	#If it's applicable, prepare and commit it
	$RT::Logger->debug ("$self: Checking $Scrip ".$Scrip->ScripObj->id. " (ScripScope: ".$Scrip->id .")\n");
	
	if ( $Scrip->ScripObj->IsApplicable() ) {
	  
	  $RT::Logger->debug ("$self: Preparing $Scrip\n");
	  
	  #TODO: handle some errors here
	  
	  $Scrip->ScripObj->Prepare() &&   
	    $Scrip->ScripObj->Commit() &&
	      $RT::Logger->info("$self: Committed $Scrip\n");
	  
	  #We're done with it. lets clean up.
	  #TODO: why the fuck do we need to do this? 
	  $Scrip->ScripObj->DESTROY();
	}
	
	
	else {
	  #TODO: why the fuck does this not catch all
	  # ScripObjs we create. and why do we explictly need to destroy them?
	  $Scrip->ScripObj->DESTROY;
	}
      }	
    }
  
  # }}}
    return ($id, "Transaction Created");
}
# }}}

# {{{ Routines dealing with Attachments

# {{{ sub Message 

=head2 Message

  Returns the RT::Attachment Object which is the top-level message object
for this transaction

=cut

sub Message  {

    my $self = shift;
    
    use RT::Attachments;
    if (!defined ($self->{'message'}) ){
	
	$self->{'message'} = new RT::Attachments($self->CurrentUser);
	$self->{'message'}->Limit(FIELD => 'TransactionId',
				  VALUE => $self->Id);
	
	$self->{'message'}->ChildrenOf(0);
    } 
    return($self->{'message'});
}
# }}}

# {{{ sub Attachments 
=head2 Attachments

  Returns all the RT::Attachment objects which are attached
to this transaction. Takes an optional parameter, which is
a ContentType that Attachments should be restricted to.

=cut


sub Attachments  {
  my $self = shift;
  if (@_) {
    my $Types = shift;
  }
  
  #TODO cache this
  use RT::Attachments;
  my $Attachments = new RT::Attachments($self->CurrentUser);
  $Attachments->Limit(FIELD => 'TransactionId',
		      VALUE => $self->Id);

  if ($Types) {
    $Attachments->Limit(FIELD => 'ContentType',
			VALUE => "$Types",
			OPERATOR => "LIKE");
  }
  
  
  return($Attachments);

}
# }}}

# {{{ sub _Attach 

=head2 _Attach

A private method used to attach a mime object to this transaction.

=cut

sub _Attach  {
  my $self = shift;
  my $MIMEObject = shift;

  if (!defined($MIMEObject)) {
    die "RT::Transaction::_Attach: We can't attach a mime object if you don't give us one.\n";
  }
  

  use RT::Attachment;
  my $Attachment = new RT::Attachment ($self->CurrentUser);
  $Attachment->Create(TransactionId => $self->Id,
		      Attachment => $MIMEObject);
  return ($Attachment, "Attachment created");
  
}
# }}}

# }}}

# {{{ Routines dealing with Transaction Attributes

# {{{ sub TicketObj

=head2 TicketObj

Returns this transaction's ticket object.

=cut

sub TicketObj {
    my $self = shift;
    if (! exists $self->{'TicketObj'}) {
	$self->{'TicketObj'} = new RT::Ticket($self->CurrentUser);
	$self->{'TicketObj'}->Load($self->Ticket);
    }
    
    return $self->{'TicketObj'};
}
# }}}

# {{{ sub Description 

=head2 Description

Returns a text string which describes this transaction

=cut


sub Description  {
  my $self = shift;
  if (!defined($self->Type)) {
    return("No transaction type specified");
  }
  if ($self->Type eq 'Create'){
    return("Request created by ".$self->Creator->UserId);
  }
  elsif ($self->Type =~ /Status/) {
    if ($self->Field eq 'Status') {
      if ($self->NewValue eq 'dead') {
	  return ("Request killed by ". $self->Creator->UserId);
      }
      else {
	  return( "Status changed from ".  $self->OldValue . 
		  " to ". $self->NewValue.
		  " by ".$self->Creator->UserId);
      }
  }
    # Generic:
    return $self->Field." changed from ".($self->OldValue||"(empty value)")." to ".$self->NewValue." by ".$self->Creator->UserId;
  }

  if ($self->Type eq 'Correspond')    {
    return("Mail sent by ". $self->Creator->UserId);
  }
  
  elsif ($self->Type eq 'Comment')  {
    return( "Comments added by ".$self->Creator->UserId);
  }
  
  
  elsif ($self->Type eq 'queue_id'){
    return( "Queue changed to ".$self->Data." by ".$self->Creator->UserId);
  }
  elsif ($self->Type =~ /^(Take|Steal|Untake|Give)$/){
      if ($self->Type eq 'Untake'){
	  return( "Untaken by ".$self->Creator->UserId);
      }
    
      if ($self->Type eq "Take") {
	  return( "Taken by ".$self->Creator->UserId);
      }

      if ($self->Type eq "Steal") {
	  my $Old = RT::User->new($self->CurrentUser);
	  $Old->Load($self->OldValue);
	  return "Request stolen from ".$Old->UserId." by ".$self->Creator->UserId;
      }

      if ($self->Type eq "Give") {
	  
	  my $New = RT::User->new($self->CurrentUser);
	  $New->Load($self->NewValue);

	  return( "Request given to ".$New->UserId." by ". $self->Creator->UserId);
      }

      my $New = RT::User->new($self->CurrentUser);
      $New->Load($self->NewValue);
      my $Old = RT::User->new($self->CurrentUser);
      $Old->Load($self->OldValue);

      return "Owner changed from ".$New->UserId." to ".$Old->UserId." by ".$self->Creator->UserId;

  }
  elsif ($self->Type eq 'requestors'){
    return( "User changed to ".$self->Data." by ".$self->Creator->UserId);
  }
  elsif ($self->Type eq 'priority') {
    return( "Priority changed to ".$self->Data." by ".$self->Creator->UserId);
      }    
  elsif ($self->Type eq 'final_priority') {
    return( "Final Priority changed to ".$self->Data." by ".$self->Creator->UserId);
      }
  elsif ($self->Type eq 'date_due') {  
    ($wday, $mon, $mday, $hour, $min, $sec, $TZ, $year)=&parse_time(".$self->Data.");
      $text_time = sprintf ("%s, %s %s %4d %.2d:%.2d:%.2d", $wday, $mon, $mday, $year,$hour,$min,$sec);
    return( "Date Due changed to $text_time by ".$self->Creator->UserId);
    }
  elsif ($self->Type eq 'Subject') {
      return( "Subject changed to ".$self->Data." by ".$self->Creator->UserId);
      }
  elsif ($self->Type eq 'Told') {
    return( "User notified by ".$self->Creator->UserId);
      }
  
  elsif ($self->Type eq 'Link') {
    #TODO: make pretty output.
      
      return "Linked up.  (  ". $self->Data. "  )";
  }
  elsif ($self->Type eq 'Set') {
      return ($self->Field . " changed from " . $self->OldValue . " to ".$self->NewValue."\n");
  }	
  else {
    return($self->Type . " modified. RT Should be more explicit about this!");
  }
  
  
}
# }}}

# {{{ sub _Accessible 
sub _Accessible  {
  my $self = shift;
  my %Cols = (
	      TimeTaken => 'read',
	      Ticket => 'read',
	      Type=> 'read',
	      Field => 'read',
	      Data => 'read',
	      NewValue => 'read',
	      OldValue => 'read',
	      EffectiveTicket => 'read',
	      Creator => 'read/auto',
	      Created => 'read/auto',
	      LastUpdated => 'read/auto'
	     );
  return $self->SUPER::_Accessible(@_, %Cols);
}
# }}}

# }}}

# {{{ Utility methods

# {{{ sub IsInbound

=head2 IsInbound

Returns true if the creator of the transaction is a requestor of the ticket.
Returns false otherwise

=cut

sub IsInbound {
  my $self=shift;
  return ($self->TicketObj->IsRequestor($self->Creator));
}

# }}}

# }}}

=head2 CurrentUserHasRight

Calls $self->TicketObj->CurrentUserHasRight with the argument list
passed in here.

=cut

sub CurrentUserHasRight {
    my $self = shift;
    return ($self->TicketObj->CurrentUserHasRight(@_));
}

=head2 HasRight

Calls $self->TicketObj->HasRight with the argument list
passed in here.

=cut


sub HasRight {
    my $self = shift;
    return ($self->TicketObj->HasRight(@_));
}


1;

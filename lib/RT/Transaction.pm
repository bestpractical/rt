# Copyright 1999-2000 Jesse Vincent <jesse@fsck.com>
# Released under the terms of the GNU Public License
# $Header$
#
#
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

#This is "Create Transaction"
sub Create  {
    my $self = shift;
    my %args = ( id => undef,
		 TimeTaken => 0,
		 Ticket => 0 ,
		 Type => '',
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
    
    #lets create our parent object
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
    use RT::Ticket;
    #TODO this MUST be as the "System" principal or it all breaks
    my $TicketAsSystem = RT::Ticket->new($RT::SystemUser);
    $TicketAsSystem->Load($args{'Ticket'}) || $RT::Logger->err("RT::Transaction couldn't load $args{'Ticket'}\n");
   
    $RT::Logger->err("RT::Transaction::Create is about to limit to queue: ".$TicketAsSystem->Queue."\n"); 
    # Deal with Scrips
    
    #Load a scrips object
    use RT::ScripScopes;
    my $ScripScopes = RT::ScripScopes->new($RT::SystemUser);
    $ScripScopes->LimitToQueue($TicketAsSystem->QueueObj->Id); #Limit it to queue 0 or $Ticket->QueueId
    
    #Load a ScripsScopes object
    #Iterate through each script and check it's applicability.
    $RT::Logger->debug("Searching for scrips for transaction #".$self->Id." (".$self->Type()."), ticket #".$TicketAsSystem->Id);
   
    while (my $Scope = $ScripScopes->Next()) {
	
	# TODO: we're really doing a lot of unneccessary
	# TODO: loading here. I think we really should do a search on two
	# TODO: tables.  --TobiX
	# TODO: Agreed - jesse. It'll probably wait until after the 2.0 
	# TODO  release unless it appears to be a serious perf bottleneck.
	
	$RT::Logger->debug("Trying out ".$Scope->ScripObj->Name." (".$Scope->ScripObj->Type.")");
	if ($Scope->ScripObj->Type && 
	    $Scope->ScripObj->Type =~ /(Any)|(\b$args{'Type'}\b)/) {

	    #TODO: properly deal with errors raised in this scrip loop

	    # Why do we need an eval here anyway?  What errors can be
	    # raised here?

	    eval {
		#Load the scrip's action;
		$Scope->ScripObj->LoadAction(TicketObj => $TicketAsSystem, 
					     TemplateObj => $Scope->ScripObj->TemplateObj,
					     TransactionObj => $self);
	
		#If it's applicable, prepare and commit it
		$RT::Logger->debug("Found a Scrip (".join("/",$Scope->ScripObj->Name,$Scope->ScripObj->Description,$Scope->ScripObj->Describe).") at ticket #".$TicketAsSystem->Id);

		if ( $Scope->ScripObj->IsApplicable() ) {

		    $RT::Logger->debug("Running a Scrip (".join("/",$Scope->ScripObj->Name,$Scope->ScripObj->Description,$Scope->ScripObj->Describe,($Scope->ScripObj->TemplateObj ? $Scope->ScripObj->TemplateObj->id : "")).") at ticket #".$TicketAsSystem->Id);


		    #TODO: handle some errors here

		    $Scope->ScripObj->Prepare() &&   
		    $Scope->ScripObj->Commit() &&
		    $RT::Logger->info("Successfully executed a Scrip (".join("/",$Scope->ScripObj->Name,$Scope->ScripObj->Description,$Scope->ScripObj->Describe).") at ticket #".$TicketAsSystem->Id);
		   
		    #We're done with it. lets clean up.
		    #TODO: why the fuck do we need to do this? 
		    $Scope->ScripObj->DESTROY();
		}
	    }
	} else {
	    #TODO: why the fuck does this not catch all
	    # ScripObjs we create. and why do we explictly need to destroy them?
	    $Scope->ScripObj->DESTROY;
	}
    }    
    return ($id, "Transaction Created");
}
# }}}

# {{{ Routines dealing with Attachments

# {{{ sub Message 
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
			VALUE => "%$Types%",
			OPERATOR => "LIKE");
  }
  
  
  return($Attachments);

}
# }}}

# {{{ sub _Attach 
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
sub TicketObj {
    my $self=shift;
    my $ticket=new RT::Ticket($self->CurrentUser);
    return $self->{'TicketObj'}
        if exists $self->{'TicketObj'};
    $ticket->Load($self->Ticket);
    return $self->{'TicketObj'}=$ticket;
}
# }}}

# {{{ sub Description 
sub Description  {
  my $self = shift;
  if (!defined($self->Type)) {
    return("No transaction type specified");
  }
  if ($self->Type eq 'Create'){
    return("Request created by ".$self->Creator->UserId);
  }
  elsif ($self->Type =~ /Set|Stall|Open|Resolve|Kill/) {
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
  
  elsif ($self->Type eq 'area')  {
    my $to = $self->{'data'};
    $to = 'none' if ! $to;
    return( "Area changed to $to by". $self->Creator->UserId);
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
	  my $Old = RT::User->new($CurrentUser);
	  $Old->Load($self->OldValue);
	  return "Request stolen from ".$Old->UserId." by ".$self->Creator->UserId;
      }

      if ($self->Type eq "Give") {
	  
	  my $New = RT::User->new($CurrentUser);
	  $New->Load($self->NewValue);

	  return( "Request given to ".$New->UserId." by ". $self->Creator->UserId);
      }

      my $New = RT::User->new($CurrentUser);
      $New->Load($self->NewValue);
      my $Old = RT::User->new($CurrentUser);
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
  elsif ($self->Type eq 'effective_sn') {
    return( "Request $self->{'serial_num'} merged into ".$self->Data." by ".$self->Creator->UserId);
  }
  elsif ($self->Type eq 'subreqrsv') {
    return "Subrequest #".$self->Data." resolved by ".$self->Creator->UserId;
  }
  elsif ($self->Type eq 'Link') {
    #TODO: make pretty output.
    
    return "Linked up.  (  ". $self->Data. "  )";
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

# TODO:  This sub will return wrong if the one entering the request
# (i.e. through the cli) is a different person than the real
# requestor. --tobix
# Arguably, that's the right action, as the goal of this routine
# is to notify the requestor if someone other than the requestor
# performs an action, right?  -- jesse
sub IsInbound {
  my $self=shift;
  return ($self->TicketObj->IsRequestor($self->Creator));
}
# }}}

# }}}

# {{{ Routines dealing with ACCESS CONTROL

# {{{ sub DisplayPermitted 
sub DisplayPermitted  {
  my $self = shift;

  my $actor = shift;
  if (!$actor) {
 #   my $actor = $self->CurrentUser->Id();
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
sub ModifyPermitted  {
  my $self = shift;
  my $actor = shift;
  if (!$actor) {
    my $actor = $self->CurrentUser->Id();
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
sub AdminPermitted  {
  my $self = shift;
  my $actor = shift;
  if (!$actor) {
    my $actor = $self->CurrentUser->Id();
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

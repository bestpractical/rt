#$Header$

package RT::Tickets;
use RT::EasySearch;
@ISA= qw(RT::EasySearch);


# {{{ sub _Init 
sub _Init  {
  my $self = shift;
  $self->{'table'} = "Tickets";
  $self->{'primary_key'} = "id";
  $self->SUPER::_Init(@_);
  
}
# }}}

# {{{ sub Limit 
sub Limit  {
  my $self = shift;
 
   my %args = (ENTRYAGGREGATOR => 'AND',
	       @_);

  $self->SUPER::Limit(%args);
}
# }}}

# {{{ sub NewItem 
sub NewItem  {
  my $self = shift;
  my $Handle = shift;
  my $item;
  use RT::Ticket;
  $item = new RT::Ticket($self->CurrentUser);
  return($item);
}
# }}}

# {{{ sub Next 
sub Next {
	my $self = shift;
	my $Ticket = $self->SUPER::Next();
	if ((defined($Ticket)) and (ref($Ticket))) {

  	    if ($Ticket->CurrentUserHasRight('ShowTicket')) {
		return($Ticket);
	    }

	    #If the user doesn't have the right to show this ticket
	    else {	
		return($self->Next());
	    }
	}
	#if there never was any ticket
	else {
		return(undef);
	}	

}
# }}}
# {{{ sub Owner 
sub Owner  {
   my $self = shift;
   my $owner = shift;
   $self->Limit(FIELD=> 'Owner',
		VALUE=> "$owner");

}
# }}}

# {{{ sub Status 
sub Status  {
  my $self = shift;
  my $Status;
  foreach $Status (@_) {
    $self->Limit(
		 FIELD => 'Status',
		 OPERATOR => '=',
		 VALUE => "%$Status%",
		 ENTRYAGGREGATOR => 'or'
		);
  }
}
# }}}

# {{{ sub Requestor 
sub Requestor  {
  my $self = shift;
  my $Requestor;
  foreach $Requestor (@_) {
    $self->Limit(
		 ALIAS => 'ARequestor',
		 FIELD => 'Requestors',
		 OPERATOR => 'LIKE',
		 VALUE => "%$Requestor%",
		 ENTRYAGGREGATOR => 'or'
		);
  }
}
# }}}

# {{{ sub Priority 
sub Priority  {
  my $self = shift;
  
}
# }}}

# {{{ sub InitialPriority 
sub InitialPriority  {
  my $self = shift;
}
# }}}

# {{{ sub FinalPriority 
sub FinalPriority  {
  my $self = shift;
  
}
# }}}

# {{{ sub Queue 
sub Queue  {
  my $self = shift;
}
# }}}

# {{{ sub Subject 
sub Subject  {
  my $self = shift;
}
# }}}

# {{{ sub Content 
sub Content  {
  my $self = shift;
}
# }}}

# {{{ sub Creator 
sub Creator  {
  my $self = shift;
}
# }}}

#Restrict by date

# {{{ sub Created 
sub Created  {
  my $self = shift;
}
# }}}

# {{{ sub Modified 
sub Modified  {
  my $self = shift;
}
# }}}

# {{{ sub Contacted 
sub Contacted  {
  my $self = shift;
}
# }}}

# {{{ sub Due 
sub Due  {
  my $self = shift;
}
# }}}

# {{{ sub Link 

#Restrict by links.

sub Link  {
  my $self = shift;
  my %args = (
              Base => undef,
	      Target => undef,
	      Type => undef,
              @_);

}
# }}}

# {{{ sub ParentOf  
sub ParentOf   {
  my $self = shift;
}
# }}}

# {{{ sub ChildOf 
sub ChildOf  {
  my $self = shift;
}
# }}}

# {{{ sub DependsOn 
sub DependsOn  {
  my $self = shift;
}
# }}}

# {{{ sub DependedOnBy 
sub DependedOnBy  {
  my $self = shift;
}
# }}}

  1;



#$Header$

package RT::Tickets;
use RT::EasySearch;
@ISA= qw(RT::EasySearch);

# {{{ TYPES
%TYPES =    ( Status => 'ENUM',
	      Queue  => 'ENUM',
	      Type => 'ENUM',
	      Creator => 'ENUM',
	      LastUpdatedBy => 'ENUM',
	      Owner => 'ENUM',
	      id => 'INT',
	      EffectiveId => 'INT',
	      InitialPriority => 'INT',
	      FinalPriority => 'INT',
	      Priority => 'INT',
	      TimeLeft => 'INT',
	      TimeWorked => 'INT',
	      MemberOf => 'LINK',
	      DependsOn => 'LINK',
	      HasMember => 'LINK',
	      HasDepender => 'LINK',
	      RelatedTo => 'LINK',
              Told => 'DATE',
              StartsBy => 'DATE',
              Started => 'DATE',
              Due  => 'DATE',
              Resolved => 'DATE',
              LastUpdated => 'DATE',
              Created => 'DATE',
              Subject => 'STRING',
              Content => 'TRANSFIELD',
	      WatcherEmail => 'WATCHERFIELD'
	    );
# }}}

# {{{ sub _Init 
sub _Init  {
  my $self = shift;
  $self->{'table'} = "Tickets";
  $self->{'RecalcTicketLimits'} = 1;
  $self->{'restriction_index'} =1;
  $self->{'primary_key'} = "id";
  $self->SUPER::_Init(@_);
  
}
# }}}

sub _NextIndex {
    my $self = shift;
      return ($self->{'restriction_index'}++);
}

# {{{ sub Limit 
sub Limit {
   my $self = shift;
   my %args = ( FIELD => undef,
	        OPERATOR => '=',
	        VALUE => undef,
	        DESCRIPTION => undef,
                @_
	      );
   $args{'DESCRIPTION'} = "Autodescribed: ".$args{'FIELD'} . $args{'OPERATOR'} . $ARGS{'VALUE'}
   if (!defined $args{'DESCRIPTION'}) ;
   
   my $index = $self->_NextIndex;
   %{$self->{'TicketRestrictions'}{"$index"}} = ( FIELD => $args{'FIELD'},
						  VALUE => $args{'VALUE'},
						  OPERATOR => $args{'OPERATOR'},
						  DESCRIPTION => $args{'DESCRIPTION'}
						);
   $self->{'RecalcTicketLimits'} = 1;
   return ($index);
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
	
	$self->_ProcessRestrictions if ($self->{'RecalcTicketLimits'} == 1 );


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

# {{{ sub LoadRestrictions

=head2 LoadRestrictions

LoadRestrictions takes a string which can fully populate the TicketRestrictons hash.
TODO It is not yet implemented

=cut

# }}}

# {{{ sub DescribeRestrictions

=head2 DescribeRestrictions

takes nothing.
Returns a hash keyed by restriction id. 
Each element of the hash is currently a one element hash that contains DESCRIPTION which
is a description of the purpose of that TicketRestriction
=cut

sub DescribeRestrictions  {
    my $self = shift;
    
    my ($row, %listing);
    
    foreach $row (keys %{$self->{'TicketRestrictions'}}) {
	$listing{$row} = $self->{'TicketRestrictions'}{"$row"}{'DESCRIPTION'};
    }
    return (%listing);
}
# }}}

# {{{ sub ClearRestrictions

=head2 ClearRestrictions

Removes all restrictions irretrievably

=cut
  
sub ClearRestrictions {
    my $self = shift;
    delete $self->{'TicketRestrictions'};
    $self->{'RecalcTicketLimits'} =1;
}

# {{{ sub DeleteRestriction

=head2 DeleteRestriction

Takes the row Id of a restriction (From DescribeRestrictions' output, for example.
Removes that restriction from the session's limits.

=cut


sub DeleteRestriction {
    my $self = shift;
    my $row = shift;
    delete $self->{'TicketRestrictions'}{"$row"};
    
    $self->{'RecalcTicketLimits'} = 1;
    #make the underlying easysearch object forget all its preconceptions
}

# }}}

# {{{ sub _ProcessRestrictions 

sub _ProcessRestrictions {
    my $self = shift;

    #Need to clean the EasySearch slate because it makes things too sticky
    $self->CleanSlate();

    #Blow away ticket aliases since we'll need to regenerate them for a new search
    delete $self->{'TicketAliases'};

    my $row;
    foreach $row (keys %{$self->{'TicketRestrictions'}}) {

	# {{{ if it's an int
	
	if ($TYPES{$self->{'TicketRestrictions'}{"$row"}{'FIELD'}} eq 'INT' ) {
	    if ($self->{'RecalcTicketLimits'}{"$row"}{'OPERATOR'} eq '=') {
		$self->SUPER::Limit( FIELD => $self->{'TicketRestrictions'}{"$row"}{'FIELD'},
			      ENTRYAGGREGATOR => 'AND',
			      OPERATOR => '=',
			      VALUE => $self->{'TicketRestrictions'}{"$row"}{'VALUE'}
			      );
	    }
	    elsif ($self->{'TicketRestrictions'}{"$row"}{'OPERATOR'} eq '!=') {
		$self->SUPER::Limit( FIELD => $self->{'TicketRestrictions'}{"$row"}{'FIELD'},
			      ENTRYAGGREGATOR => 'AND',
			      OPERATOR => '!=',
			      VALUE => $self->{'TicketRestrictions'}{"$row"}{'VALUE'}
			    );
	    }
	    elsif ($self->{'TicketRestrictions'}{"$row"}{'OPERATOR'} eq '>') {
		$self->SUPER::Limit( FIELD => $self->{'TicketRestrictions'}{"$row"}{'FIELD'},
			      ENTRYAGGREGATOR => 'AND',
			      OPERATOR => '>',
			      VALUE => $self->{'TicketRestrictions'}{"$row"}{'VALUE'}
			    );
	    }
	    elsif ($self->{'TicketRestrictions'}{"$row"}{'OPERATOR'} eq '<') {
		$self->SUPER::Limit( FIELD => $self->{'TicketRestrictions'}{"$row"}{'FIELD'},
			      ENTRYAGGREGATOR => 'AND',
			      OPERATOR => '<',
			      VALUE => $self->{'TicketRestrictions'}{"$row"}{'VALUE'}
			    );	
	    }
	}
	# }}}
	# {{{ if it's an enum
	elsif ($TYPES{$self->{'TicketRestrictions'}{"$row"}{'FIELD'}} eq 'ENUM') {
	    
	    if ($self->{'TicketRestrictions'}{"$row"}{'OPERATOR'} eq '=') {
		$self->SUPER::Limit( FIELD => $self->{'TicketRestrictions'}{"$row"}{'FIELD'},
			      ENTRYAGGREGATOR => 'OR',
			      OPERATOR => '=',
			      VALUE => $self->{'TicketRestrictions'}{"$row"}{'VALUE'}
			    );
	    }
	    elsif ($self->{'TicketRestrictions'}{"$row"}{'OPERATOR'} eq '!=') {
		$self->SUPER::Limit( FIELD => $self->{'TicketRestrictions'}{"$row"}{'FIELD'},
			      ENTRYAGGREGATOR => 'AND',
			      OPERATOR => '!=',
			      VALUE => $self->{'TicketRestrictions'}{"$row"}{'VALUE'}
			    );
	    }
	    
	}
	# }}}
	# {{{ if it's a date

	elsif ($TYPES{$self->{'TicketRestrictions'}{"$row"}{'FIELD'}} eq 'DATE') {
	    
	    if ($self->{'TicketRestrictions'}{"$row"}{'OPERATOR'} eq '=') {
		$self->SUPER::Limit( FIELD => $self->{'TicketRestrictions'}{"$row"}{'FIELD'},
			      ENTRYAGGREGATOR => 'AND',
			      OPERATOR => '=',
			      VALUE => $self->{'TicketRestrictions'}{"$row"}{'VALUE'}
			    );
	    }
	    elsif ($self->{'TicketRestrictions'}{"$row"}{'OPERATOR'} eq '>') {
		$self->SUPER::Limit( FIELD => $self->{'TicketRestrictions'}{"$row"}{'FIELD'},
			      ENTRYAGGREGATOR => 'AND',
			      OPERATOR => '>',
			      VALUE => $self->{'TicketRestrictions'}{"$row"}{'VALUE'}
			    );
	    }
	    elsif ($self->{'TicketRestrictions'}{"$row"}{'OPERATOR'} eq '<') {
		$self->SUPER::Limit( FIELD => $self->{'TicketRestrictions'}{"$row"}{'FIELD'},
			      ENTRYAGGREGATOR => 'AND',
			      OPERATOR => '<',
			      VALUE => $self->{'TicketRestrictions'}{"$row"}{'VALUE'}
			    );
	    }	    
	}
	# }}}
 	# {{{ if it's a string

	elsif ($TYPES{$self->{'TicketRestrictions'}{"$row"}{'FIELD'}} eq 'STRING') {
	    
	    if ($self->{'TicketRestrictions'}{"$row"}{'OPERATOR'} eq '=') {
		$self->SUPER::Limit( FIELD => $self->{'TicketRestrictions'}{"$row"}{'FIELD'},
			      ENTRYAGGREGATOR => 'OR',
			      OPERATOR => '=',
			      VALUE => $self->{'TicketRestrictions'}{"$row"}{'VALUE'}
			    );
	    }
	    elsif ($self->{'TicketRestrictions'}{"$row"}{'OPERATOR'} eq 'LIKE') {
		$self->SUPER::Limit( FIELD => $self->{'TicketRestrictions'}{"$row"}{'FIELD'},
			      ENTRYAGGREGATOR => 'AND',
			      OPERATOR => 'LIKE',
			      VALUE => $self->{'TicketRestrictions'}{"$row"}{'VALUE'}
			    );
	    }
	}

	# }}}
	# {{{ if it's Transaction content that we're hunting for
	elsif ($TYPES{$self->{'TicketRestrictions'}{"$row"}{'FIELD'}} eq 'TRANSFIELD') {

	    #Basically, we want to make sure that the limits apply to the same attachment,
	    #rather than just another attachment for the same ticket, no matter how many 
	    #clauses we lump on. 
	    #We put them in TicketAliases so that they get nuked when we redo the join.
	    
	    unless (defined $self->{'TicketAliases'}{'TransFieldAlias'}) {
		$self->{'TicketAliases'}{'TransFieldAlias'} = $self->NewAlias ('Transactions');
	    }
	    unless (defined $self->{'TicketAliases'}{'TransFieldAttachAlias'}){
		$self->{'TicketAliases'}{'TransFieldAttachAlias'} = $self->NewAlias('Attachments');
		
	    }
	    $self->Join( ALIAS1 => $self->{'TicketAliases'}{'TransFieldAttachAlias'},  
			 FIELD1 => 'TransactionId',
			 ALIAS2 => $self->{'TicketAliases'}{'TransFieldAlias'}, FIELD2=> 'id');
	    
	    $self->Join( ALIAS1 => 'main', FIELD1 => $self->{'primary_key'},
			 ALIAS2 =>$self->{'TicketAliases'}{'TransFieldAlias'}, FIELD2 => 'Ticket');

	    $self->SUPER::Limit(ALIAS => $self->{'TicketAliases'}{'TransFieldAttachAlias'},
				  ENTRYAGGREGATOR => 'AND',
				  FIELD =>    $self->{'TicketRestrictions'}{"$row"}{'FIELD'},
				  OPERATOR => $self->{'TicketRestrictions'}{"$row"}{'OPERATOR'} ,
				  VALUE =>    $self->{'TicketRestrictions'}{"$row"}{'VALUE'} );
	    

	}



	# }}}

	# {{{ if it's Transaction content that we're hunting for
	elsif ($TYPES{$self->{'TicketRestrictions'}{"$row"}{'FIELD'}} eq 'WATCHERFIELD') {
	    my $Watch = $self->NewAlias('Watchers');
	    my $User = $self->NewAlias('Users');
	    $self->Join( ALIAS1 => $Watch, FIELD1 => 'Owner',
			 ALIAS2 => $User, FIELD2 => 'id');
	    $self->Join( ALIAS1 => 'main', FIELD1 => 'id',
			 ALIAS2 => $Watch, FIELD2 => 'Value');
	    $self->Limit( ALIAS => $Watch,
			  FIELD => 'Scope',
			  VALUE => 'Ticket',
			  OPERATOR => '=');
	    $self->Limit( ALIAS => $User,
			  FIELD => 'EmailAddress',
			  ENTRYAGGREGATOR => 'OR',
			  VALUE => $self->{'TicketRestrictions'}{"$row"}{'VALUE'},
			  OPERATOR => $self->{'TicketRestrictions'}{"$row"}{'OPERATOR'}
			);
	}
	# }}}
    }
    $self->{'RecalcTicketLimits'} = 0;
}
# }}}

# {{{ sub NextPage
sub NextPage {
  my $self = shift;
  $self->FirstRow( $self->FirstRow + $self->Rows );
}
# }}}

# {{{ sub FirstPage
sub FirstPage {
  my $self = shift;
  $self->FirstRow(1);
}
# }}}

# {{{ sub PrevPage
sub PrevPage {
  my $self = shift;
  if ($self->FirstRow > 1) {
    $self->FirstRow( $self->FirstRow - $self->Rows );
  }
  else {
    $self->FirstRow(1);
  }
}
# }}}

=head2 notes
"Enum" Things that get Is, IsNot


"Int" Things that get Is LessThan and GreaterThan
id
EffectiveId
InitialPriority
FinalPriority
Priority
TimeLeft
TimeWorked

"Text" Things that get Is, Like
Subject
TransactionContent


"Link" OPERATORs


"Date" OPERATORs Is, Before, After

=cut
  1;



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
	      ContentType => 'TRANSFIELD',
	      WatcherEmail => 'WATCHERFIELD',
	      LinkedTo => 'LINKFIELD',
	      
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

=head2 Limit

Takes a paramhash with the fields FIELD, OPERATOR, VALUE and DESCRIPTION
Generally best called from LimitFoo methods

=cut
sub Limit {
   my $self = shift;
   my %args = ( FIELD => undef,
	        OPERATOR => '=',
	        VALUE => undef,
	        DESCRIPTION => undef,
                @_
	      );
   $args{'DESCRIPTION'} = "Autodescribed: ".$args{'FIELD'} . $args{'OPERATOR'} . $args{'VALUE'},
   if (!defined $args{'DESCRIPTION'}) ;
   
   my $index = $self->_NextIndex;
   
   #make the TicketRestrictions hash the equivalent of whatever we just passed in;
   %{$self->{'TicketRestrictions'}{"$index"}} = %args;
   
   
   $self->{'RecalcTicketLimits'} = 1;
   return ($index);
}
# }}}
# {{{ sub LimitQueue

=head2 LimitQueue

LimitQueue takes a paramhash with the fields OPERATOR and QUEUE.
OPERATOR is one of = or !=.
VALUE is a queue id. eventually, it should also take queue names and 
queue objects

=cut

sub LimitQueue {
    my $self = shift;
    my %args = (@_);
    my $queue = new RT::Queue($self->CurrentUser);
    $queue->Load($args{'VALUE'});
    $self->Limit (FIELD => 'Queue',
		  VALUE => $queue->id(),
		  OPERATOR => $args{'OPERATOR'},
		  DESCRIPTION => 'Queue ' .  $args{'OPERATOR'}. " ". $queue->QueueId
		 );
    
}

# }}}
# {{{ sub LimitOwner

=head2 LimitOwner

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of = or !=.
VALUE is a user id.

=cut

sub LimitOwner {
    my $self = shift;
    my %args = (@_);
    
    my $owner = new RT::User($self->CurrentUser);
    $owner->Load($args{'VALUE'});
    $self->Limit (FIELD => 'Owner',
		  VALUE => $args{'VALUE'},
		  OPERATOR => $args{'OPERATOR'},
		  DESCRIPTION => 'Owner ' .  $args{'OPERATOR'}. " ". $owner->UserId
		 );
    
}

# }}}
# {{{ sub LimitStatus

=head2 LimitStatus

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of = or !=.
VALUE is a status.

=cut

sub LimitStatus {
    my $self = shift;
    my %args = (@_);
    $self->Limit (FIELD => 'Status',
		  VALUE => $args{'VALUE'},
		  OPERATOR => $args{'OPERATOR'},
		  DESCRIPTION => 'Status ' .  $args{'OPERATOR'}. " ". $args{'VALUE'},
		 );
}

# }}}
# {{{ sub LimitSubject

=head2 LimitSubject

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of = or !=.
VALUE is a string to search for in the subject of the ticket.

=cut

sub LimitSubject {
    my $self = shift;
    my %args = (@_);
    $self->Limit (FIELD => 'Subject',
		  VALUE => $args{'VALUE'},
		  OPERATOR => $args{'OPERATOR'},
		  DESCRIPTION => 'Subject ' .  $args{'OPERATOR'}. " ". $args{'VALUE'},
		 );
}

# }}}
# {{{ sub LimitContent

=head LimitContent

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of =, LIKE, NOT LIKE or !=.
VALUE is a string to search for in the body of the ticket

=cut
sub LimitContent {
    my $self = shift;
    my %args = (@_);
    $self->Limit (FIELD => 'Content',
		  VALUE => $args{'VALUE'},
		  OPERATOR => $args{'OPERATOR'},
		  DESCRIPTION => 'Ticket content ' .  $args{'OPERATOR'}. " ". $args{'VALUE'},
		 );
}

# }}}
# {{{ sub LimitContentType

=head LimitContentType

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of =, LIKE, NOT LIKE or !=.
VALUE is a content type to search ticket attachments for

=cut
  
sub LimitContentType {
    my $self = shift;
    my %args = (@_);
    $self->Limit (FIELD => 'ContentType',
		  VALUE => $args{'VALUE'},
		  OPERATOR => $args{'OPERATOR'},
		  DESCRIPTION => 'Ticket content type ' .  $args{'OPERATOR'}. " ". $args{'VALUE'},
		 );
}
# }}}
# {{{ sub LimitPriority

=head2 LimitPriority

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of =, >, < or !=.
VALUE is a value to match the ticket\'s priority against

=cut

sub LimitPriority {
    my $self = shift;
    my %args = (@_);
    $self->Limit (FIELD => 'Priority',
		  VALUE => $args{'VALUE'},
		  OPERATOR => $args{'OPERATOR'},
		  DESCRIPTION => 'Priority ' .  $args{'OPERATOR'}. " ". $args{'VALUE'},
		 );
}

# }}}
# {{{ sub LimitInitialPriority

=head2 LimitInitialPriority

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of =, >, < or !=.
VALUE is a value to match the ticket\'s initial priority against


=cut

sub LimitInitialPriority {
    my $self = shift;
    my %args = (@_);
    $self->Limit (FIELD => 'InitialPriority',
		  VALUE => $args{'VALUE'},
		  OPERATOR => $args{'OPERATOR'},
		  DESCRIPTION => 'Initial Priority ' .  $args{'OPERATOR'}. " ". $args{'VALUE'},
		 );
}

# }}}
# {{{ sub LimitFinalPriority

=head2 LimitFinalPriority

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of =, >, < or !=.
VALUE is a value to match the ticket\'s final priority against

=cut

sub LimitFinalPriority {
    my $self = shift;
    my %args = (@_);
    $self->Limit (FIELD => 'FinalPriority',
		  VALUE => $args{'VALUE'},
		  OPERATOR => $args{'OPERATOR'},
		  DESCRIPTION => 'Final Priority ' .  $args{'OPERATOR'}. " ". $args{'VALUE'},
		 );
}

# }}}

# {{{ sub LimitWatcher


=head2 LimitWatcher
  
  Takes a paramhash with the fields OPERATOR, TYPE and VALUE.
  OPERATOR is one of =, LIKE, NOT LIKE or !=.
  VALUE is a value to match the ticket\'s watcher email addresses against
  TYPE is the sort of watchers you want to match against. Leave it undef if you want to search all of them

=cut
   
sub LimitWatcher {
    my $self = shift;
    my %args = (@_);
    my ($field, $desc);
    if ($args{'TYPE'}) {
	$field = $args{'TYPE'};
    }
    else {
	$field = "Watcher";
    }
    $desc = "$field ".$ARGS{'OPERATOR'}." ".$args{'VALUE'};
    $self->Limit (FIELD => 'WatcherEmail',
		  VALUE => $args{'VALUE'},
		  OPERATOR => $args{'OPERATOR'},
		  TYPE => $args{'TYPE'},
		  DESCRIPTION => "$desc"
		 );
}

# }}}

# {{{ sub LimitRequestor

=head2 LimitRequestor

It\'s like LimitWatcher, but it presets TYPE to Requestor

=cut


sub LimitRequestor {
    my $self = shift;
    $self->LimitWatcher(TYPE=> 'Requestor', @_);
}

# }}}

# {{{ sub LimitCc

=head2 LimitCC

It\'s like LimitWatcher, but it presets TYPE to Cc

=cut

sub LimitCc {
    my $self = shift;
    $self->LimitWatcher(TYPE=> 'Cc', @_);
}

# }}}

# {{{ sub LimitAdminCc

=head2 LimitAdminCc

It\'s like LimitWatcher, but it presets TYPE to AdminCc

=cut
  
sub LimitAdminCc {
    my $self = shift;
    $self->LimitWatcher(TYPE=> 'AdminCc', @_);
}

# }}}

# {{{ LimitLinkedTo

=head2 LimitLinkedTo

LimitLinkedTo takes a paramhash with two fields: TYPE and TICKET
TYPE limits the sort of relationship we want to search on
TICKET is the id of the BASE of the link

=cut

sub LimitLinkedTo {
    my $self = shift;
    my %args = ( FIELD => undef,
		 TICKET => undef,
		 TYPE => undef,
		 @_);
 
    $self->Limit( FIELD => 'LinkedTo',
		  BASE => undef,
		  TARGET => $args{'TICKET'},
		  TYPE => $args{'TYPE'},
		  DESCRIPTION => "Tickets ".$args{'TYPE'}." by ".$args{'TICKET'}
		);
}


# }}}
# {{{ LimitLinkedFrom

=head2 LimitLinkedFrom

LimitLinkedFrom takes a paramhash with two fields: TYPE and TICKET
TYPE limits the sort of relationship we want to search on
TICKET is the id of the BASE of the link

=cut

sub LimitLinkedFrom {
    my $self = shift;
    my %args = ( FIELD => undef,
		 TICKET => undef,
		 TYPE => undef,
		 @_);

    $self->Limit( FIELD => 'LinkedTo',
		  TARGET => undef,
		  BASE => $args{'TICKET'},
		  TYPE => $args{'TYPE'},
		  DESCRIPTION => "Tickets " .$ARGS{'TICKET'} ." ".$args{'TYPE'}
		);
}


# }}}

# {{{ LimitMemberOf 
sub LimitMemberOf {
    my $self = shift;
    my $ticket_id = shift;
    $self->LimitLinkedTo ( TICKET=> "$ticket_id",
			   TYPE => 'MemberOf',
			  );
    
}
# }}}
# {{{ LimitHasMember
sub LimitHasMember {
    my $self = shift;
    my $ticket_id =shift;
    $self->LimitLinkedFrom ( TICKET => "$ticket_id",
			     TYPE => 'MemberOf',
			     );
    
}
# }}}
# {{{ LimitDependsOn
sub LimitDependsOn {
    my $self = shift;
    my $ticket_id = shift;
    $self->LimitLinkedTo ( TICKET => "$ticket_id",
                           TYPE => 'DependsOn',
			   );
    
}
# }}}
# {{{ LimitDependedOnBy
sub LimitDependedOnBy {
    my $self = shift;
    my $ticket_id = shift;
    $self->LimitLinkedFrom (  TICKET=> "$ticket_id",
                               TYPE => 'DependsOn',
			     );
    
}
# }}}
=head1 TODO
sub LimitDate
<OPTION VALUE="Created">Created</OPTION>
<OPTION VALUE="Started">Started</OPTION>
<OPTION VALUE="Resolved">Resolved</OPTION>
<OPTION VALUE="Told">Last Contacted</OPTION>
<OPTION VALUE="LastUpdated">Last Updated</OPTION>
<OPTION VALUE="StartsBy">Starts By</OPTION>
<OPTION VALUE="Due">Due</OPTION>


sub LimitDependsOn
sub LimitDependedOnBy
}

=cut


# {{{ sub LimitTimeWorked

=head2 LimitTimeWorked

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of =, >, < or !=.
VALUE is a value to match the ticket's TimeWorked attribute

=cut

sub LimitTimeWorked {
    my $self = shift;
    my %args = (@_);
    $self->Limit (FIELD => 'TimeWorked',
		  VALUE => $args{'VALUE'},
		  OPERATOR => $args{'OPERATOR'},
		  DESCRIPTION => 'Time worked ' .  $args{'OPERATOR'}. " ". $args{'VALUE'},
		 );
}

# }}}
# {{{ sub LimitTimeLeft

=head2 LimitTimeLeft

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of =, >, < or !=.
VALUE is a value to match the ticket's TimeLeft attribute

=cut

sub LimitTimeLeft {
    my $self = shift;
    my %args = (@_);
    $self->Limit (FIELD => 'TimeLeft',
		  VALUE => $args{'VALUE'},
		  OPERATOR => $args{'OPERATOR'},
		  DESCRIPTION => 'Time left ' .  $args{'OPERATOR'}. " ". $args{'VALUE'},
		 );
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
# }}}

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
			      VALUE => $self->{'TicketRestrictions'}{"$row"}{'VALUE'},
			      );
	    }
	    elsif ($self->{'TicketRestrictions'}{"$row"}{'OPERATOR'} eq '!=') {
		$self->SUPER::Limit( FIELD => $self->{'TicketRestrictions'}{"$row"}{'FIELD'},
			      ENTRYAGGREGATOR => 'AND',
			      OPERATOR => '!=',
			      VALUE => $self->{'TicketRestrictions'}{"$row"}{'VALUE'},
			    );
	    }
	    elsif ($self->{'TicketRestrictions'}{"$row"}{'OPERATOR'} eq '>') {
		$self->SUPER::Limit( FIELD => $self->{'TicketRestrictions'}{"$row"}{'FIELD'},
			      ENTRYAGGREGATOR => 'AND',
			      OPERATOR => '>',
			      VALUE => $self->{'TicketRestrictions'}{"$row"}{'VALUE'},
			    );
	    }
	    elsif ($self->{'TicketRestrictions'}{"$row"}{'OPERATOR'} eq '<') {
		$self->SUPER::Limit( FIELD => $self->{'TicketRestrictions'}{"$row"}{'FIELD'},
			      ENTRYAGGREGATOR => 'AND',
			      OPERATOR => '<',
			      VALUE => $self->{'TicketRestrictions'}{"$row"}{'VALUE'},
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
			      VALUE => $self->{'TicketRestrictions'}{"$row"}{'VALUE'},
			    );
	    }
	    elsif ($self->{'TicketRestrictions'}{"$row"}{'OPERATOR'} eq '!=') {
		$self->SUPER::Limit( FIELD => $self->{'TicketRestrictions'}{"$row"}{'FIELD'},
			      ENTRYAGGREGATOR => 'AND',
			      OPERATOR => '!=',
			      VALUE => $self->{'TicketRestrictions'}{"$row"}{'VALUE'},
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
			      VALUE => $self->{'TicketRestrictions'}{"$row"}{'VALUE'},
			    );
	    }
	    elsif ($self->{'TicketRestrictions'}{"$row"}{'OPERATOR'} eq '>') {
		$self->SUPER::Limit( FIELD => $self->{'TicketRestrictions'}{"$row"}{'FIELD'},
			      ENTRYAGGREGATOR => 'AND',
			      OPERATOR => '>',
			      VALUE => $self->{'TicketRestrictions'}{"$row"}{'VALUE'},
			    );
	    }
	    elsif ($self->{'TicketRestrictions'}{"$row"}{'OPERATOR'} eq '<') {
		$self->SUPER::Limit( FIELD => $self->{'TicketRestrictions'}{"$row"}{'FIELD'},
			      ENTRYAGGREGATOR => 'AND',
			      OPERATOR => '<',
			      VALUE => $self->{'TicketRestrictions'}{"$row"}{'VALUE'},
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
			      VALUE => $self->{'TicketRestrictions'}{"$row"}{'VALUE'},
			    );
	    }
	    elsif ($self->{'TicketRestrictions'}{"$row"}{'OPERATOR'} eq 'LIKE') {
		$self->SUPER::Limit( FIELD => $self->{'TicketRestrictions'}{"$row"}{'FIELD'},
			      ENTRYAGGREGATOR => 'AND',
			      OPERATOR => 'LIKE',
			      VALUE => $self->{'TicketRestrictions'}{"$row"}{'VALUE'},
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
	    #Join transactions to attachments
	    $self->Join( ALIAS1 => $self->{'TicketAliases'}{'TransFieldAttachAlias'},  
			 FIELD1 => 'TransactionId',
			 ALIAS2 => $self->{'TicketAliases'}{'TransFieldAlias'}, FIELD2=> 'id');
	    
	    #Join transactions to tickets
	    $self->Join( ALIAS1 => 'main', FIELD1 => $self->{'primary_key'},
			 ALIAS2 =>$self->{'TicketAliases'}{'TransFieldAlias'}, FIELD2 => 'Ticket');
	    
	    #Search for the right field
	    $self->SUPER::Limit(ALIAS => $self->{'TicketAliases'}{'TransFieldAttachAlias'},
				  ENTRYAGGREGATOR => 'AND',
				  FIELD =>    $self->{'TicketRestrictions'}{"$row"}{'FIELD'},
				  OPERATOR => $self->{'TicketRestrictions'}{"$row"}{'OPERATOR'} ,
				  VALUE =>    $self->{'TicketRestrictions'}{"$row"}{'VALUE'} );
	    

	}



	# }}}
	# {{{ if it's a relationship that we're hunting for
	
	# Takes FIELD: which is something like "LinkedTo"
	# takes TARGET or BASE which is the TARGET or BASE id that we're searching for
	# takes TYPE which is the type of link we're looking for.

	elsif ($TYPES{$self->{'TicketRestrictions'}{"$row"}{'FIELD'}} eq 'LINKFIELD') {

	    
	    my $LinkAlias = $self->NewAlias ('Links');

	    
	    #Make sure we get the right type of link, if we're restricting it
	    if ($self->{'TicketRestrictions'}{"$row"}{'TYPE'}) {
		$self->SUPER::Limit(ALIAS => $LinkAlias,
				    ENTRYAGGREGATOR => 'AND',
				    FIELD =>   'Type',
				    OPERATOR => '=',
				    VALUE =>    $self->{'TicketRestrictions'}{"$row"}{'TYPE'} );
	    }
	    
	    #If we're trying to limit it to things that are target of
	    if ($self->{'TicketRestrictions'}{"$row"}{'TARGET'}) {
		$self->SUPER::Limit(ALIAS => $LinkAlias,
				    ENTRYAGGREGATOR => 'AND',
				    FIELD =>   'Target',
				    OPERATOR => '=',
				    VALUE =>    $self->{'TicketRestrictions'}{"$row"}{'TARGET'} );

		
		#If we're searching on target, join the base to ticket.id
		$self->Join( ALIAS1 => 'main', FIELD1 => $self->{'primary_key'},
			     ALIAS2 => $LinkAlias,
			     FIELD2 => 'Base');

	    


	    }
	    #If we're trying to limit it to things that are base of
	    elsif ($self->{'TicketRestrictions'}{"$row"}{'BASE'}) {
		$self->SUPER::Limit(ALIAS => $LinkAlias,
				    ENTRYAGGREGATOR => 'AND',
				    FIELD =>   'Base',
				    OPERATOR => '=',
				    VALUE =>    $self->{'TicketRestrictions'}{"$row"}{'BASE'} );
		
		#If we're searching on base, join the target to ticket.id
		$self->Join( ALIAS1 => 'main', FIELD1 => $self->{'primary_key'},
			     ALIAS2 => $LinkAlias,
			     FIELD2 => 'Target');
		
	    }

	}
		
	# }}}
	# {{{ if it's a watcher that we're hunting for
	elsif ($TYPES{$self->{'TicketRestrictions'}{"$row"}{'FIELD'}} eq 'WATCHERFIELD') {
	    my $Watch = $self->NewAlias('Watchers');
	    my $User = $self->NewAlias('Users');

	    #Join watchers to users
	    $self->Join( ALIAS1 => $Watch, FIELD1 => 'Owner',
			 ALIAS2 => $User, FIELD2 => 'id');

	    #Join Ticket to watchers
	    $self->Join( ALIAS1 => 'main', FIELD1 => 'id',
			 ALIAS2 => $Watch, FIELD2 => 'Value');

	    #Make sure we're only talking about ticket watchers
	    $self->SUPER::Limit( ALIAS => $Watch,
			  FIELD => 'Scope',
			  VALUE => 'Ticket',
			  OPERATOR => '=');

	    #Limit it to the address we want
	    $self->SUPER::Limit( ALIAS => $User,
			  FIELD => 'EmailAddress',
			  ENTRYAGGREGATOR => 'OR',
			  VALUE => $self->{'TicketRestrictions'}{"$row"}{'VALUE'},
			  OPERATOR => $self->{'TicketRestrictions'}{"$row"}{'OPERATOR'}
			);

	    #If we only want a specific type of watchers, then limit it to that
	    if ($self->{'TicketRestrictions'}{"$row"}{'TYPE'}) {
		$self->SUPER::Limit( ALIAS => $Watch,
			      FIELD => 'Type',
			      ENTRYAGGREGATOR => 'OR',
			      VALUE => $self->{'TicketRestrictions'}{"$row"}{'TYPE'},
			      OPERATOR => '=');
	    }
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



#$Header$
=head1 NAME

  RT::Tickets - A collection of Ticket objects

=head1 SYNOPSIS

  use RT::Tickets;
my $tickets = new RT::Tickets($CurrentUser);

=head1 DESCRIPTION


=head1 METHODS

=cut
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
	      Type => 'STRING',
              Content => 'TRANSFIELD',
	      ContentType => 'TRANSFIELD',
	      Watcher => 'WATCHERFIELD',
	      LinkedTo => 'LINKFIELD',
              Keyword => 'KEYWORDFIELD'
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

# {{{ sub _NextItem
sub _NextIndex {
    my $self = shift;
    return ($self->{'restriction_index'}++);
}
# }}}

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
    %{$self->{'TicketRestrictions'}{$index}} = %args;
    
    
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
    my %args = ( OPERATOR => '=',
                 @_);
    
    my $owner = new RT::User($self->CurrentUser);
    $owner->Load($args{'VALUE'});
    $self->Limit (FIELD => 'Owner',
		  VALUE => $owner->Id,
		  OPERATOR => $args{'OPERATOR'},
		  DESCRIPTION => 'Owner ' .  $args{'OPERATOR'}. " ". $owner->UserId()
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
    my %args = ( OPERATOR => '=',
                  @_);
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
# {{{ sub LimitType

=head2 LimitType

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of = or !=.
VALUE is a string to search for in the type of the ticket.

=cut

sub LimitType {
    my $self = shift;
    my %args = (@_);
    $self->Limit (FIELD => 'Type',
                  VALUE => $args{'VALUE'},
                  OPERATOR => $args{'OPERATOR'},
                  DESCRIPTION => 'Type ' .  $args{'OPERATOR'}. " ". $args{'VALUE'},
                 );
}

# }}}

# {{{ sub LimitId

=head2 LimitId

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of =, >, < or !=.
VALUE is a ticket Id to search for

=cut

sub LimitId {
    my $self = shift;
    my %args = (OPERATOR => '=',
                @_);
    $self->Limit (FIELD => 'id',
                  VALUE => $args{'VALUE'},
                  OPERATOR => $args{'OPERATOR'},
                  DESCRIPTION => 'Id ' .  $args{'OPERATOR'}. " ". $args{'VALUE'},
                 );
}

# }}}

# {{{ sub LimitContent

=head2 LimitContent

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

=head2 LimitContentType

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
    my %args = ( OPERATOR => '=',
		 VALUE => undef,
		 TYPE => undef,
		@_);


    #build us up a description
    my ($watcher_type, $desc);
    if ($args{'TYPE'}) {
	$watcher_type = $args{'TYPE'};
    }
    else {
	$watcher_type = "Watcher";
    }
    $desc = "$watcher_type ".$ARGS{'OPERATOR'}." ".$args{'VALUE'};


    $self->Limit (FIELD => 'Watcher',
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
# {{{ LimitDate 
sub LimitDate
<OPTION VALUE="Created">Created</OPTION>
<OPTION VALUE="Started">Started</OPTION>
<OPTION VALUE="Resolved">Resolved</OPTION>
<OPTION VALUE="Told">Last Contacted</OPTION>
<OPTION VALUE="LastUpdated">Last Updated</OPTION>
<OPTION VALUE="StartsBy">Starts By</OPTION>
<OPTION VALUE="Due">Due</OPTION>
# }}}

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


# {{{ sub LimitKeyword

=head2 KEY=>VALUE, ...

Takes a list of key/value pairs with the following keys:

=over 4

=item KEYWORDSELECT - KeywordSelect id

=item OPERATOR - (for KEYWORD only - KEYWORDSELECT operator is always `=')

=item KEYWORD - Keyword id

=back

=cut

sub LimitKeyword {
    my $self = shift;
    my %args = ( KEYWORD => undef,
                 KEYWORDSELECT => undef,
		 OPERATOR => '=',
		 DESCRIPTION => undef,
		 FIELD => 'Keyword',
		 @_
	       );

    use RT::KeywordSelect;
    my $KeywordSelect = RT::KeywordSelect->new($self->CurrentUser);
    $KeywordSelect->Load($args{KEYWORDSELECT});
    use RT::Keyword;
    my $Keyword = RT::Keyword->new($self->CurrentUser);
    $Keyword->Load($args{KEYWORD});
    $args{'DESCRIPTION'} ||= $KeywordSelect->Name. " $args{OPERATOR} ". $Keyword->Name;
    
    my $index = $self->_NextIndex;
    %{$self->{'TicketRestrictions'}{$index}} = %args;
    
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
	$listing{$row} = $self->{'TicketRestrictions'}{$row}{'DESCRIPTION'};
    }
    return (%listing);
}
# }}}

# {{{ sub RestrictionValues

=head2 RestrictionValues FIELD

Takes a restriction field and returns a list of values this field is restricted
to.

=cut

sub RestrictionValues {
    my $self = shift;
    my $field = shift;
    map $self->{'TicketRestrictions'}{$_}{'VALUE'},
      grep {
             $self->{'TicketRestrictions'}{$_}{'FIELD'} eq $field
             && $self->{'TicketRestrictions'}{$_}{'OPERATOR'} eq "="
           }
        keys %{$self->{'TicketRestrictions'}};
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
    delete $self->{'TicketRestrictions'}{$row};
    
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
        my $restriction = $self->{'TicketRestrictions'}{$row};
	# {{{ if it's an int
	
	if ($TYPES{$restriction->{'FIELD'}} eq 'INT' ) {
	    if ($restriction->{'OPERATOR'} eq '=') {
		$self->SUPER::Limit( FIELD => $restriction->{'FIELD'},
			      ENTRYAGGREGATOR => 'AND',
			      OPERATOR => '=',
			      VALUE => $restriction->{'VALUE'},
			      );
	    }
	    elsif ($restriction->{'OPERATOR'} eq '!=') {
		$self->SUPER::Limit( FIELD => $restriction->{'FIELD'},
			      ENTRYAGGREGATOR => 'AND',
			      OPERATOR => '!=',
			      VALUE => $restriction->{'VALUE'},
			    );
	    }
	    elsif ($restriction->{'OPERATOR'} eq '>') {
		$self->SUPER::Limit( FIELD => $restriction->{'FIELD'},
			      ENTRYAGGREGATOR => 'AND',
			      OPERATOR => '>',
			      VALUE => $restriction->{'VALUE'},
			    );
	    }
	    elsif ($restriction->{'OPERATOR'} eq '<') {
		$self->SUPER::Limit( FIELD => $restriction->{'FIELD'},
			      ENTRYAGGREGATOR => 'AND',
			      OPERATOR => '<',
			      VALUE => $restriction->{'VALUE'},
			    );	
	    }
	}
	# }}}
	# {{{ if it's an enum
	elsif ($TYPES{$restriction->{'FIELD'}} eq 'ENUM') {
	    
	    if ($restriction->{'OPERATOR'} eq '=') {
		$self->SUPER::Limit( FIELD => $restriction->{'FIELD'},
			      ENTRYAGGREGATOR => 'OR',
			      OPERATOR => '=',
			      VALUE => $restriction->{'VALUE'},
			    );
	    }
	    elsif ($restriction->{'OPERATOR'} eq '!=') {
		$self->SUPER::Limit( FIELD => $restriction->{'FIELD'},
			      ENTRYAGGREGATOR => 'AND',
			      OPERATOR => '!=',
			      VALUE => $restriction->{'VALUE'},
			    );
	    }
	    
	}
	# }}}
	# {{{ if it's a date

	elsif ($TYPES{$restriction->{'FIELD'}} eq 'DATE') {
	    
	    if ($restriction->{'OPERATOR'} eq '=') {
		$self->SUPER::Limit( FIELD => $restriction->{'FIELD'},
			      ENTRYAGGREGATOR => 'AND',
			      OPERATOR => '=',
			      VALUE => $restriction->{'VALUE'},
			    );
	    }
	    elsif ($restriction->{'OPERATOR'} eq '>') {
		$self->SUPER::Limit( FIELD => $restriction->{'FIELD'},
			      ENTRYAGGREGATOR => 'AND',
			      OPERATOR => '>',
			      VALUE => $restriction->{'VALUE'},
			    );
	    }
	    elsif ($restriction->{'OPERATOR'} eq '<') {
		$self->SUPER::Limit( FIELD => $restriction->{'FIELD'},
			      ENTRYAGGREGATOR => 'AND',
			      OPERATOR => '<',
			      VALUE => $restriction->{'VALUE'},
			    );
	    }	    
	}
	# }}}
 	# {{{ if it's a string

	elsif ($TYPES{$restriction->{'FIELD'}} eq 'STRING') {
	    
	    if ($restriction->{'OPERATOR'} eq '=') {
		$self->SUPER::Limit( FIELD => $restriction->{'FIELD'},
			      ENTRYAGGREGATOR => 'OR',
			      OPERATOR => '=',
			      VALUE => $restriction->{'VALUE'},
			    );
	    }
	    elsif ($restriction->{'OPERATOR'} eq 'LIKE') {
		$self->SUPER::Limit( FIELD => $restriction->{'FIELD'},
			      ENTRYAGGREGATOR => 'AND',
			      OPERATOR => 'LIKE',
			      VALUE => $restriction->{'VALUE'},
			    );
	    }
	}

	# }}}
	# {{{ if it's Transaction content that we're hunting for
	elsif ($TYPES{$restriction->{'FIELD'}} eq 'TRANSFIELD') {

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
				  FIELD =>    $restriction->{'FIELD'},
				  OPERATOR => $restriction->{'OPERATOR'} ,
				  VALUE =>    $restriction->{'VALUE'} );
	    

	}



	# }}}
	# {{{ if it's a relationship that we're hunting for
	
	# Takes FIELD: which is something like "LinkedTo"
	# takes TARGET or BASE which is the TARGET or BASE id that we're searching for
	# takes TYPE which is the type of link we're looking for.

	elsif ($TYPES{$restriction->{'FIELD'}} eq 'LINKFIELD') {

	    
	    my $LinkAlias = $self->NewAlias ('Links');

	    
	    #Make sure we get the right type of link, if we're restricting it
	    if ($restriction->{'TYPE'}) {
		$self->SUPER::Limit(ALIAS => $LinkAlias,
				    ENTRYAGGREGATOR => 'AND',
				    FIELD =>   'Type',
				    OPERATOR => '=',
				    VALUE =>    $restriction->{'TYPE'} );
	    }
	    
	    #If we're trying to limit it to things that are target of
	    if ($restriction->{'TARGET'}) {
		$self->SUPER::Limit(ALIAS => $LinkAlias,
				    ENTRYAGGREGATOR => 'AND',
				    FIELD =>   'LocalTarget',
				    OPERATOR => '=',
				    VALUE =>    $restriction->{'TARGET'} );

		
		#If we're searching on target, join the base to ticket.id
		$self->Join( ALIAS1 => 'main', FIELD1 => $self->{'primary_key'},
			     ALIAS2 => $LinkAlias,
			     FIELD2 => 'LocalBase');

	    


	    }
	    #If we're trying to limit it to things that are base of
	    elsif ($restriction->{'BASE'}) {
		$self->SUPER::Limit(ALIAS => $LinkAlias,
				    ENTRYAGGREGATOR => 'AND',
				    FIELD =>   'LocalBase',
				    OPERATOR => '=',
				    VALUE =>    $restriction->{'BASE'} );
		
		#If we're searching on base, join the target to ticket.id
		$self->Join( ALIAS1 => 'main', FIELD1 => $self->{'primary_key'},
			     ALIAS2 => $LinkAlias,
			     FIELD2 => 'LocalTarget');
		
	    }

	}
		
	# }}}
	# {{{ if it's a watcher that we're hunting for
	elsif ($TYPES{$restriction->{'FIELD'}} eq 'WATCHERFIELD') {
	    my $Watch = $self->NewAlias('Watchers');

	    #TODO use this to allow searching on things like email addresses.
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
	    $self->SUPER::Limit( ALIAS => $Watch,
				 FIELD => 'Owner',
				 ENTRYAGGREGATOR => 'OR',
				 VALUE => $restriction->{'VALUE'},
				 OPERATOR => $restriction->{'OPERATOR'}
			       );
	    
	    #If we only want a specific type of watchers, then limit it to that
	    if ($restriction->{'TYPE'}) {
		$self->SUPER::Limit( ALIAS => $Watch,
				     FIELD => 'Type',
				     ENTRYAGGREGATOR => 'OR',
				     VALUE => $restriction->{'TYPE'},
				     OPERATOR => '=');
	    }
	}
	# }}}
	# {{{ keyword
	elsif ($TYPES{$restriction->{'FIELD'}} eq 'KEYWORDFIELD') {
            my $ObjKeywordsAlias = $self->NewAlias('ObjectKeywords');
            $self->Join(
                         ALIAS1 => 'main',
                         FIELD1 => 'id',
                         ALIAS2 => $ObjKeywordsAlias,
                         FIELD2 => 'ObjectId'
                       );
            $self->SUPER::Limit(
                                 ALIAS => $ObjKeywordsAlias,
                                 FIELD => 'Keyword',
                                 VALUE => $restriction->{'KEYWORD'},
                                 OPERATOR => $restriction->{'OPERATOR'},
                                 ENTRYAGGREGATOR => 'AND',
                               );
            $self->SUPER::Limit(
                                 ALIAS => $ObjKeywordsAlias,
                                 FIELD => 'KeywordSelect',
                                 VALUE => $restriction->{'KEYWORDSELECT'},
                                 ENTRYAGGREGATOR => 'AND',
                               );
            $self->SUPER::Limit(
                                 ALIAS => $ObjKeywordsAlias,
                                 FIELD => 'ObjectType',
                                 VALUE => 'Ticket',
                                 ENTRYAGGREGATOR => 'AND',
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

# {{{ POD
=head2 notes
"Enum" Things that get Is, IsNot


"Int" Things that get Is LessThan and GreaterThan
id
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
# }}}





=head2 SetListingFormat

Takes a single Format string as specified below. parses that format string and makes the various listing output
things DTRT.

=item Format strings

Format strings are made up of a chain of Elements delimited with vertical pipes (|).
Elements of a Format string 


FormatString:    Element[::FormatString]

Element:         AttributeName[;HREF=<URL>][;TITLE=<TITLE>]

AttributeName    Id | Subject | Status | Owner | Priority | InitialPriority | TimeWorked | TimeLeft |
  
                 Keywords[;SELECT=<KeywordSelect>] | 
	
                <Created|Starts|Started|Contacted|Due|Resolved>Date<AsString|AsISO|AsAge>


=cut




#accept a format string


sub SetListingFormat {
    my $self = shift;
    my $listing_format = shift;
    
    my ($element, $attribs);
    my $i = 0;
    foreach $element (split (/::/,$listing_format)) {
	if ($element =~ /^(.*?);(.*)$/) {
	    $element = $1;
	    $attribs = $2;
	}	
	$self->{'format_string'}->[$i]->{'Element'} = $element;
	foreach $attrib (split (/;/, $attribs)) {
	    my $value = "";
	    if ($attrib =~ /^(.*?)=(.*)$/) {
		$attrib = $1;
		$value = $2;
	    }	
	    $self->{'format_string'}->[$i]->{"$attrib"} = $val;
	    
	}
    
    }
    return(1);
}





#Seperate methods for

#Print HTML Header
sub HTMLHeader {
    my $self = shift;
    my $header = "";
    my $col;
    foreach $col ( @{[ $self->{'format_string'} ]}) {
	$header .= "<TH>" . $self->_ColumnTitle($self->{'format_string'}->[$col]) . "</TH>";
	
    }
    return ($header);
}


#Print text header
sub TextHeader {
    my $self = shift;
    my ($header);
    
    return ($header);
}


#Print HTML row
sub TicketAsHTMLRow {
    my $self = shift;
    my $Ticket = shift;
    my ($row, $col);
    foreach $col (@{[$self->{'format_string'}]}) {
	$row .= "<TD>" . $self->_TicketColumnValue($ticket,$self->{'format_string'}->[$col]) . "</TD>";
	
    }
    return ($row);
}


#Print text row
sub TicketAsTextRow {
    my $self = shift;
    my ($row);
    
    return ($row);
}


# {{{ _ColumnTitle {

sub _ColumnTitle {
    my $self = shift;
    
    # Attrib is a hash 
    my $attrib = shift;
    
    # return either attrib->{'TITLE'} or..
    if ($attrib->{'TITLE'}) {
	return($attrib->{'TITLE'});
    }	
    # failing that, Look up the title in a hash
    else {
	#TODO create $self->{'ColumnTitles'};
	return ($self->{'ColumnTitles'}->{$attrib->{'Element'}});
    }	
    
}

# }}}

# {{{ _TicketColumnValue
sub _TicketColumnValue {
    my $self = shift;
    my $Ticket = shift;
    my $attrib = shift;

    
    my $out;

  SWITCH: {
	/^id/i && do {
	    $out = $Ticket->id;
	    last SWITCH; 
	};
	/^subj/i && do {
	    last SWITCH; 
	    $Ticket->Subject;
		   };	
	/^status/i && do {
	    last SWITCH; 
	    $Ticket->Status;
	};
	/^prio/i && do {
	    last SWITCH; 
	    $Ticket->Priority;
	};
	/^finalprio/i && do {
	    
	    last SWITCH; 
	    $Ticket->FinalPriority
	};
	/^initialprio/i && do {
	    
	    last SWITCH; 
	    $Ticket->InitialPriority;
	};	
	/^timel/i && do {
	    
	    last SWITCH; 
	    $Ticket->TimeWorked;
	};
	/^timew/i && do {
	    
	    last SWITCH; 
	    $Ticket->TimeLeft;
	};
	
	/^(.*?)date(.*)$/i && do {
	    my $o = $1;
	    my $m = $2;
	    my ($obj);
	    #TODO: optimize
	    $obj = $Ticket->DueObj         if $o =~ /due/i;
	    $obj = $Ticket->CreatedObj     if $o =~ /created/i;
	    $obj = $Ticket->StartsObj      if $o =~ /starts/i;
	    $obj = $Ticket->StartedObj     if $o =~ /started/i;
	    $obj = $Ticket->ToldObj        if $o =~ /told/i;
	    $obj = $Ticket->LastUpdatedObj if $o =~ /lastu/i;
	    
	    $method = 'ISO' if $m =~ /iso/i;
	    
	    $method = 'AsString' if $m =~ /asstring/i;
	    $method = 'AgeAsString' if $m =~ /age/i;
	    last SWITCH;
	    $obj->$method
	      
	};
	  
	  /^watcher/i && do {
	      last SWITCH; 
	      $Ticket->WatchersAsString();
	  };	
	
	/^requestor/i && do {
	    last SWITCH; 
	    $Ticket->RequestorsAsString();
	};	
	/^cc/i && do {
	    last SWITCH; 
	    $Ticket->CCAsString();
	};	
	
	
	/^admincc/i && do {
	    last SWITCH; 
	    $Ticket->AdminCcAsString();
	};
	
	/^keywords/i && do {
	    last SWITCH; 
	    #Limit it to the keyword select we're talking about, if we've got one.
	    my $objkeys =$Ticket->KeywordsObj($attrib->{'SELECT'});
	    $objkeys->KeywordRelativePathsAsString();
	};
	
    }
      
}

# }}}
1;

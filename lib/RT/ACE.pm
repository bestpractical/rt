#$Header$

package RT::ACE;
use RT::Record;
@ISA= qw(RT::Record);

use vars qw (%SCOPE 
   	     %QUEUERIGHTS
	     %TICKETRIGHTS
	     %SYSTEMRIGHTS
	     %METAPRINCIPALS); 

%SCOPES = ( System => 'System-level right',
	   Queue => 'Queue-level right'
		 );

# Queue rights are the sort of queue rights that can only be granted
# to real people or groups
%QUEUERIGHTS = ( See => 'Can this principal see this queue',
		 List => 'Display a listing of ticket',
		 ModifyWatchers => 'Modify the queue watchers',
		 ModifyACL => 'Modify this queue\'s ACL',
		 CreateTicket => 'Create a ticket in this queue'
	   );

# System rights are rights granted to the whole system
%SYSTEMRIGHTS = ( CreateQueue => 'Create queues',
		  DeleteQueue => 'Delete queues',
		  AdminUsers => 'Create, Delete and Modify users',
		  ModifySelf => 'Modify one\'s own RT account',
		  ModifySystemACL => 'Modify system ACLs'
		);

#Ticket rights are the sort of queue rights that can be granted to 
#principals and metaprincipals

%TICKETRIGHTS = ( ShowTicket => 'Show ticket summary',
		  ShowTicketHistory => 'Show ticket history',
		  ShowTicketComments => 'Show ticket private commentary',
		  CorrespondOnTicket => 'Reply to ticket',
		  CommentOnTicket => 'Comment on ticket',
		  OwnTicket => 'Own a ticket',
		  ModifyTicket => 'Modify ticket',
		  DeleteTicket => 'Delete ticket'
		);

%TICKET_METAPRINCIPALS = ( Owner => 'The owner of a ticket',
			   Requestor => 'The requestor of a ticket',
			   Cc => 'The CC of a ticket',
			   AdminCc => 'The administrative CC of a ticket',
			 );

%GLOBAL_METAPRINCIPALS = ( Everyone => 'Any valid RT principal' );




# {{{ sub new 
sub new  {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $self->{'table'} = "ACL";
  $self->_Init(@_);
  return ($self);
}
# }}}

# {{{ sub _Create

sub _Create {
my $self = shift;
my %args = ( PrincipalId => undef,
	     PrincipalType => undef,
	     RightName => undef,
	     RightScope => undef,
	     RightAppliesTo => undef
	   );
	use Carp;

	Carp::confess "RT::ACE::_Create not yet implemented\n";
return (1, 'Granted');
}
# }}}

# {{{ sub GrantQueueRight 

sub GrantQueueRight {
	
	my $self = shift;
	my %args = ( PrincipalType => undef,
				 PrincipalId => undef,
				 @_);
	
	
	if ($args->{'RightScope'} ne 'Queue') {
		return (0, 'Scope must be queue for queue rights');
	}
	
	
	#unless $self->CurrentUser->id has 'ModifyQueueACL' for (queue == $args->{'AppliesTo'}) {
    # if the user can't do it, return a (0, 'No permission to grant rights');
	#}
   
  return ($self->_Create($args));
}

# }}}

# {{{ sub GrantGlobalQueueRight

sub GrantGlobalQueueRight {
  my $self = shift;
  my %args = ( RightAppliesTo => 0,
	       @_);

  return ($self->GrantQueueRight($args));
}

# }}}

# {{{ sub GrantSystemRight

sub GrantSystemRight {
  my $self = shift;
  my %args = (RightScope => 'System',
	      RightAppliesTo => 0,
	      @_);
  
  #If the user can't grant system rights, 
  unless ($self->CurrentUser->HasRight('ModifySystemACL')) {
    
    return (0, 'No permission to grant rights');
  }
  return ($self->_Create( $args ));
		       
}
# }}}

# {{{ sub _Accessible 
sub _Accessible  {
  my $self = shift;  
  my %Cols = (
	      PrincipalId => 'read/write',
	      PrincipalType => 'read/write',
	      RightName => 'read/write', 
	      RightScope => 'read/write',
	      RightAppliesTo => 'read/write'
	    );
  return($self->SUPER::_Accessible(@_, %Cols));
}
# }}}

# {{{ sub _Set
sub _Set {
  my $self = shift;
  return (0, "ACEs can only be created and deleted.");
}
# }}}
1;

__DATA__

=title RT::ACE

=head1 Table Structure

PrincipalType, PrincipalId, Right,Scope,AppliesTo


=head1 Scopes

Scope is the scope of the right granted, not the granularity of the grant.
For example, Queue and Ticket rights are both granted for a "queue." 
Rights with a scope of "Ticket" are rights that act on a single existing ticket.The 'AppliesTo' for a right with the scope of 'Ticket' is the Queue that the
right applies to.  The 'AppliesTo' for a right with the scope of 'Queue' is the
Queue that the right applies to.  Rights with a scope of 'System' don't have an
AppliesTo. (They're global).
Rights with a scope of "Queue" are rights that act on a queue.
Rights with a scope of "System" are rights that act on some other aspect
of the system.


=item Ticket 
=item Queue
=item System


=head1 Rights

=head2 Scope: Queue

=head3 Queue rights that apply to a ticket within a queue

Display Ticket Summary in <queue>

	Name: ShowTicket
	Principals: <user> <group> Owner Requestor Cc AdminCc

Display Ticket History  <queue>

	Name: ShowTicketHistory
	Principals: <user> <group> Owner Requestor Cc AdminCc

Display Ticket Private Comments  <queue>

	Name: ShowTicketComments
	Principals: <user> <group> Owner Requestor Cc AdminCc

Reply to Ticket in <queue>

	Name: CorrespondOnTicket
	Principals: <user> <group> Owner Requestor Cc AdminCc

Comment on Ticket in <queue>

	Name: CommentOnTicket
	Principals: <user> <group> Owner Requestor Cc AdminCc

Modify Ticket in <queue>

	Name: ModifyTicket
	Principals: <user> <group> Owner Requestor Cc AdminCc

Delete Tickets in <queue>

	Name: DeleteTicket
	Principals: <user> <group> Owner Requestor Cc AdminCc


=head3 Queue Rights that apply to a whole queue

These rights can only be granted to "real people"

List Tickets in <queue>

	Name: ListQueue
	Principals: <user> <group>

Modify Queue Watchers for <queue>

	Name: ModifyQueueWatchers
	Principals: <user> <group>

Modify Queue Attributes for <queue> 

	Name: ModifyQueue
	Principals: <user> <group>

Modify Queue ACL for queue <queue>

	Name: ModifyQueueACL
	Principals: <user> <group>

Create Ticket in <queue>

        Name: CreateTicket
	Principals: <user> <group>

=head2 Rights that apply to the System scope

=head3 SystemRights

Create Queue
  
        Name: CreateQueue
	Principals: <user> <group>
Delete Queue
  
        Name: DeleteQueue
  	Principals: <user> <group>

Create Users
  
        Name: CreateUser
	Principals: <user> <group>

Delete Users
  
        Name: DeleteUser
  	Principals: <user> <group>
  
Modify Users
  
        Name: ModifyUser
	Principals: <user> <group>

Modify Self
        Name: ModifySelf
	Principals: <user> <group>

Browse Users

        Name: BrowseUsers (NOT IMPLEMENTED in 2.0)
	Principals: <user> <group>

Modify Self
		    
	Name: ModifySelf
	Principals: <user> <group>

Modify System ACL

	Name: ModifySystemACL		  
	Principals: <user> <group>

=head1 The Principal Side of the ACE

=head2 PrincipalTypes,PrincipalIds in our Neighborhood

  User,<userid>
  Group,<groupip>
  TicketOwner,NULL
  TicketRequestor,NULL
  TicketCc,NULL
  TicketAdminCc,NULL
  Everyone,NULL

=cut

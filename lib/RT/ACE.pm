#$Header$

=head1 NAME

  RT::ACE - RT's ACE object

=head1 SYNOPSIS

  use RT::ACE;
my $ace = new RT::ACE($CurrentUser);

=head1 DESCRIPTION


=head1 METHODS

=cut

package RT::ACE;
use RT::Record;
@ISA= qw(RT::Record);

use vars qw (%SCOPES
   	     %QUEUERIGHTS
	     %SYSTEMRIGHTS
	    ); 



%SCOPES = (
	   System => 'System-level right',
	   Queue => 'Queue-level right'
	  );

# {{{ Descriptions of rights
# Queue rights are the sort of queue rights that can only be granted
# to real people or groups
%QUEUERIGHTS = ( 
		SeeQueue => 'Can this principal see this queue',
		ExploreQueue => 'Look at this queue\'s configuration, watchers, etc',
		AdminQueue => 'Create, delete and modify queues', 
		
		ModifyACL => 'Modify this queue\'s ACL',
		ModifyQueueWatchers => 'Modify the queue watchers',
		
		CreateTemplate => 'Create email templates for this queue',
		ModifyTemplate => 'Modify email templates for this queue',
		ShowTemplate => 'Display email templates for this queue',
		
		ModifyScripScopes => 'Modify ScripScopes for this queue',
		ShowScripScopes => 'Display ScripScopes for this queue',

		ShowTicket => 'Show ticket summaries',
		ShowTicketHistory => 'Show ticket histories',
		ShowTicketComments => 'Show ticket private commentary',
		CreateTicket => 'Create tickets in this queue',
		ReplyToTicket => 'Reply to tickets',
		CommentOnTicket => 'Comment on tickets',
		OwnTicket => 'Own tickets',
		ModifyTicket => 'Modify tickets',
		DeleteTicket => 'Delete tickets'
	       );	


# System rights are rights granted to the whole system
%SYSTEMRIGHTS = (
         SuperUser => 'Do anything and everything',
		 AdminGroups => 'Create, delete and modify groups',
		 AdminUsers => 'Create, Delete and Modify users',
		 ModifySelf => 'Modify one\'s own RT account',
		 ModifySystemACL => 'Modify system ACLs',

		);


# }}}

# {{{ Descriptions of principals

%TICKET_METAPRINCIPALS = ( Owner => 'The owner of a ticket',
            			   Requestor => 'The requestor of a ticket',
		            	   Cc => 'The CC of a ticket',
			               AdminCc => 'The administrative CC of a ticket',
			 );


# }}}


# {{{ sub _Init
sub _Init  {
  my $self = shift;
  $self->{'table'} = "ACL";
  return($self->SUPER::_Init(@_));
}
# }}}

# {{{ sub Create

sub Create {
    my $self = shift;
    my %args = ( PrincipalId => undef,
		 PrincipalType => undef,
		 RightName => undef,
		 RightScope => undef,
		 RightAppliesTo => undef,
		 @_
	       );
    
    if ($args{'RightScope'} eq 'System') {
	
	unless ($self->CurrentUser->HasSystemRight('ModifySystemACL')) {
	    $RT::Logger->error("No permission to grant rights");
	    return(undef);
	}
	
	#TODO check if it's a valid RightName/Principaltype
    }
    elsif ($args{'RightScope'} eq 'Queue') {
   	
    unless ($self->CurrentUser->HasQueueRight( Queue => $args{'RightAppliesTo'},
						  Right => 'ModifyQueueACL')) {
	    return (0, 'No permission to grant rights');
	}
	
	#TODO check if it's a valid RightName/Principaltype
	
    }
    #If it's not a scope we recognise, something scary is happening.
    else {
	$RT::Logger->err("RT::ACE->Create got a scope it didn't recognize: ".
			 $args{'RightScope'}." Bailing. \n");
	return(0,"System error. Unable to grant rights.");
    }
    
    $RT::Logger->debug("$self ->Create Granting ". $args{'RightName'} ." to ".  $args{'PrincipalId'}."\n");
    my $id = $self->SUPER::Create( PrincipalId => $args{'PrincipalId'},
				   PrincipalType => $args{'PrincipalType'},
				   RightName => $args{'RightName'},
				   RightScope => $args {'RightScope'},
				   RightAppliesTo => $args{'RightAppliesTo'}
				 );
    
    
    if ($id > 0 ) {
	return ($id, 'Right Granted');
    }
    else {
	$RT::Logger->err('System error. right not granted.');
	return(undef);
    }
}
# }}}

# {{{ sub _BootstrapRight 

=head2 _BootstrapRight

Grant a right with no error checking and no ACL. this is _only_ for 
installation. If you use this routine without jesse@fsck.com's explicit 
written approval, he will hunt you down and make you spend eternity
translating mozilla's code into FORTRAN or intercal.

=cut

sub _BootstrapRight {
    my $self = shift;
    my %args = @_;

    my $id = $self->SUPER::Create( PrincipalId => $args{'PrincipalId'},
				   PrincipalType => $args{'PrincipalType'},
				   RightName => $args{'RightName'},
				   RightScope => $args {'RightScope'},
				   RightAppliesTo => $args{'RightAppliesTo'}
				 );
    
    if ($id > 0 ) {
	return ($id);
    }
    else {
	$RT::Logger->err('System error. right not granted.');
	return(undef);
    }
    
}

# }}}

# {{{ sub QueueRights

=head2 QueueRights

Returns a hash of all the possible rights at the queue scope

=cut

sub QueueRights {
        return (%QUEUERIGHTS);
}

# }}}

# {{{ sub SystemRights

=head2 SystemRights

Returns a hash of all the possible rights at the system scope

=cut

sub SystemRights {
	return (%SYSTEMRIGHTS);
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

# {{{ POD

=head1 RT::ACE

=head2 Table Structure

PrincipalType, PrincipalId, Right,Scope,AppliesTo

=head2 The docs are out of date. so you know.

=head1 Scopes

Scope is the scope of the right granted, not the granularity of the grant.
For example, Queue and Ticket rights are both granted for a "queue." 
Rights with a scope of 'System' don't have an AppliesTo. (They're global).
Rights with a scope of "Queue" are rights that act on a queue.
Rights with a scope of "System" are rights that act on some other aspect
of the system.


=item Queue
=item System


=head1 Rights

=head2 Scope: Queue

=head2 Queue rights that apply to a ticket within a queue

Create Ticket in <queue>

        Name: Create
	Principals: <user> <group>
Display Ticket Summary in <queue>

	Name: Show
	Principals: <user> <group> Owner Requestor Cc AdminCc

Display Ticket History  <queue>

	Name: ShowHistory
	Principals: <user> <group> Owner Requestor Cc AdminCc

Display Ticket Private Comments  <queue>

	Name: ShowComments
	Principals: <user> <group> Owner Requestor Cc AdminCc

Reply to Ticket in <queue>

	Name: Reply
	Principals: <user> <group> Owner Requestor Cc AdminCc

Comment on Ticket in <queue>

	Name: Comment
	Principals: <user> <group> Owner Requestor Cc AdminCc

Modify Ticket in <queue>

	Name: Modify
	Principals: <user> <group> Owner Requestor Cc AdminCc

Delete Tickets in <queue>

	Name: Delete
	Principals: <user> <group> Owner Requestor Cc AdminCc


=head2 Queue Rights that apply to a whole queue

These rights can only be granted to "real people"

List Tickets in <queue>

	Name: ListQueue
	Principals: <user> <group>

Know that <queue> exists
    
    Name: See
    Principals: <user> <group>

Display queue settings

    Name: Explore
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


=head2 Rights that apply to the System scope

=head2 SystemRights

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
  Everyone,NULL

=cut

# }}}

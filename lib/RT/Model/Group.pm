use warnings; 
use strict;


package RT::Model::Group;

=head1 NAME

  RT::Model::Group - RT\'s group object

=head1 SYNOPSIS

use RT::Model::Group;
my $group = new RT::Model::Group($CurrentUser);

=head1 DESCRIPTION

An RT group object.

=head1 METHODS


=cut


use Jifty::DBI::Schema;
use base qw/RT::Record/;

use Jifty::DBI::Record schema {
    column Name        => type is 'varchar(200)';
    column Description => type is 'text';
    column Domain      => type is 'varchar(64)';
    column Type        => type is 'varchar(64)';
    column Instance    => type is 'integer';

};


sub table { 'Groups'}

use RT::Model::UserCollection;
use RT::Model::GroupMemberCollection;
use RT::Model::PrincipalCollection;
use RT::Model::ACECollection;

use vars qw/$RIGHTS/;

$RIGHTS = {
    AdminGroup           => 'Modify group metadata or delete group',  # loc_pair
    AdminGroupMembership =>
      'Modify membership roster for this group',                      # loc_pair
    DelegateRights =>
        "Delegate specific rights which have been granted to you.",   # loc_pair
    ModifyOwnMembership => 'join or leave this group',                 # loc_pair
    EditSavedSearches => 'Edit saved searches for this group',        # loc_pair
    ShowSavedSearches => 'Display saved searches for this group',        # loc_pair
    SeeGroup => 'Make this group visible to user',                    # loc_pair
};

# Tell RT::Model::ACE that this sort of object can get acls granted
$RT::Model::ACE::OBJECT_TYPES{'RT::Model::Group'} = 1;


#

# TODO: This should be refactored out into an RT::Model::ACECollectionedObject or something
# stuff the rights into a hash of rights that can exist.

foreach my $right ( keys %{$RIGHTS} ) {
    $RT::Model::ACE::LOWERCASERIGHTNAMES{ lc $right } = $right;
}


=head2 AvailableRights

Returns a hash of available rights for this object. The keys are the right names and the values are a description of what the rights do

=cut

sub AvailableRights {
    my $self = shift;
    return($RIGHTS);
}


# {{{ sub SelfDescription

=head2 SelfDescription

Returns a user-readable description of what this group is for and what it's named.

=cut

sub SelfDescription {
	my $self = shift;
	if ($self->Domain eq 'ACLEquivalence') {
		my $user = RT::Model::Principal->new($self->current_user);
		$user->load($self->Instance);
		return $self->loc("user [_1]",$user->Object->Name);
	}
	elsif ($self->Domain eq 'UserDefined') {
		return $self->loc("group '[_1]'",$self->Name);
	}
	elsif ($self->Domain eq 'Personal') {
		my $user = RT::Model::User->new($self->current_user);
		$user->load($self->Instance);
		return $self->loc("personal group '[_1]' for user '[_2]'",$self->Name, $user->Name);
	}
	elsif ($self->Domain eq 'RT::System-Role') {
		return $self->loc("system [_1]",$self->Type);
	}
	elsif ($self->Domain eq 'RT::Model::Queue-Role') {
		my $queue = RT::Model::Queue->new($self->current_user);
		$queue->load($self->Instance);
		return $self->loc("queue [_1] [_2]",$queue->Name, $self->Type);
	}
	elsif ($self->Domain eq 'RT::Model::Ticket-Role') {
		return $self->loc("ticket #[_1] [_2]",$self->Instance, $self->Type);
	}
	elsif ($self->Domain eq 'SystemInternal') {
		return $self->loc("system group '[_1]'",$self->Type);
	}
	else {
		return $self->loc("undescribed group [_1]",$self->id);
	}
}

# }}}

# {{{ sub load 

=head2 Load ID

Load a group object from the database. Takes a single argument.
If the argument is numerical, load by the column 'id'. Otherwise, 
complain and return.

=cut

sub load {
    my $self       = shift;
    my $identifier = shift || return undef;

    #if it's an int, load by id. otherwise, load by name.
    if ( $identifier !~ /\D/ ) {
        $self->SUPER::load_by_id($identifier);
    }
    else {
        $RT::Logger->crit("Group -> Load called with a bogus argument");
        return undef;
    }
}

# }}}

# {{{ sub loadUserDefinedGroup 

=head2 LoadUserDefinedGroup NAME

Loads a system group from the database. The only argument is
the group's name.


=cut

sub loadUserDefinedGroup {
    my $self       = shift;
    my $identifier = shift;

        $self->load_by_cols( "Domain" => 'UserDefined',
                           "Name" => $identifier );
}

# }}}

# {{{ sub load_acl_equivalence_group 

=head2 load_acl_equivalence_group  PRINCIPAL

Loads a user's acl equivalence group. Takes a principal object.
ACL equivalnce groups are used to simplify the acl system. Each user
has one group that only he is a member of. Rights granted to the user
are actually granted to that group. This greatly simplifies ACL checks.
While this results in a somewhat more complex setup when creating users
and granting ACLs, it _greatly_ simplifies acl checks.



=cut

sub load_acl_equivalence_group {
    my $self       = shift;
    my $princ = shift;

        $self->load_by_cols( "Domain" => 'ACLEquivalence',
                            "Type" => 'UserEquiv',
                           "Instance" => $princ->id);
}

# }}}

# {{{ sub loadPersonalGroup 

=head2 LoadPersonalGroup {Name => NAME, User => USERID}

Loads a personal group from the database. 

=cut

sub loadPersonalGroup {
    my $self       = shift;
    my %args =  (   Name => undef,
                    User => undef,
                    @_);

        $self->load_by_cols( "Domain" => 'Personal',
                           "Instance" => $args{'User'},
                           "Type" => '',
                           "Name" => $args{'Name'} );
}

# }}}

# {{{ sub load_system_internal_group 

=head2 load_system_internal_group NAME

Loads a Pseudo group from the database. The only argument is
the group's name.


=cut

sub load_system_internal_group {
    my $self       = shift;
    my $identifier = shift;

        $self->load_by_cols( "Domain" => 'SystemInternal',
                           "Type" => $identifier );
}

# }}}

# {{{ sub load_ticket_role_group 

=head2 load_ticketRoleGroup  { Ticket => TICKET_ID, Type => TYPE }

Loads a ticket group from the database. 

Takes a param hash with 2 parameters:

    Ticket is the TicketId we're curious about
    Type is the type of Group we're trying to load: 
        Requestor, Cc, AdminCc, Owner

=cut

sub load_ticket_role_group {
    my $self       = shift;
    my %args = (Ticket => '0',
                Type => undef,
                @_);
        $self->load_by_cols( Domain => 'RT::Model::Ticket-Role',
                           Instance =>$args{'Ticket'}, 
                           Type => $args{'Type'}
                           );
}

# }}}

# {{{ sub loadQueueRoleGroup 

=head2 LoadQueueRoleGroup  { Queue => Queue_ID, Type => TYPE }

Loads a Queue group from the database. 

Takes a param hash with 2 parameters:

    Queue is the QueueId we're curious about
    Type is the type of Group we're trying to load: 
        Requestor, Cc, AdminCc, Owner

=cut

sub loadQueueRoleGroup {
    my $self       = shift;
    my %args = (Queue => undef,
                Type => undef,
                @_);
        $self->load_by_cols( Domain => 'RT::Model::Queue-Role',
                           Instance =>$args{'Queue'}, 
                           Type => $args{'Type'}
                           );
}

# }}}

# {{{ sub loadSystemRoleGroup 

=head2 LoadSystemRoleGroup  Type

Loads a System group from the database. 

Takes a single param: Type

    Type is the type of Group we're trying to load: 
        Requestor, Cc, AdminCc, Owner

=cut

sub loadSystemRoleGroup {
    my $self       = shift;
    my $type = shift;
        $self->load_by_cols( Domain => 'RT::System-Role',
                           Type => $type
                           );
}

# }}}

# {{{ sub create

=head2 Create

You need to specify what sort of group you're creating by calling one of the other
Create_____ routines.

=cut

sub create {
    my $self = shift;
    $RT::Logger->crit("Someone called RT::Model::Group->create. this method does not exist. someone's being evil");
    return(0,$self->loc('Permission Denied'));
}

# }}}

# {{{ sub _create

=head2 _create

Takes a paramhash with named arguments: Name, Description.

Returns a tuple of (Id, Message).  If id is 0, the create failed

=cut

sub _create {
    my $self = shift;
    my %args = (
        Name        => undef,
        Description => undef,
        Domain      => undef,
        Type        => undef,
        Instance    => '0',
        InsideTransaction => undef,
        _RecordTransaction => 1,
        @_
    );
    Jifty->handle->begin_transaction() unless ($args{'InsideTransaction'});
    # Groups deal with principal ids, rather than user ids.
    # When creating this group, set up a principal Id for it.
    my $principal    = RT::Model::Principal->new( $self->current_user );
    my ($principal_id,$msg) = $principal->create(
        PrincipalType => 'Group',
        ObjectId      => '0'
    );
    $principal->__set(column => 'ObjectId', value => $principal_id);


    $self->SUPER::create(
        id          => $principal_id,
        Name        => $args{'Name'},
        Description => $args{'Description'},
        Type        => $args{'Type'},
        Domain      => $args{'Domain'},
        Instance    => ($args{'Instance'} || '0')
    );
    my $id = $self->id;
    unless ($id) {
        return ( 0, $self->loc('Could not create group') );
    }

    # If we couldn't create a principal Id, get the fuck out.
    unless ($principal_id) {
        Jifty->handle->rollback() unless ($args{'InsideTransaction'});
        $RT::Logger->crit( "Couldn't create a Principal on new user create. Strange things are afoot at the circle K" );
        return ( 0, $self->loc('Could not create group') );
    }

    # Now we make the group a member of itself as a cached group member
    # this needs to exist so that group ACL checks don't fall over.
    # you're checking CachedGroupMembers to see if the principal in question
    # is a member of the principal the rights have been granted too

    # in the ordinary case, this would fail badly because it would recurse and add all the members of this group as 
    # cached members. thankfully, we're creating the group now...so it has no members.
    my $cgm = RT::Model::CachedGroupMember->new($self->current_user);
    $cgm->create(Group =>$self->PrincipalObj, Member => $self->PrincipalObj, ImmediateParent => $self->PrincipalObj);


    if ( $args{'_RecordTransaction'} ) {
	$self->_NewTransaction( Type => "Create" );
    }

    Jifty->handle->commit() unless ($args{'InsideTransaction'});

    return ( $id, $self->loc("Group Created") );
}

# }}}

# {{{ create_userDefinedGroup

=head2 create_userDefinedGroup { Name => "name", Description => "Description"}

A helper subroutine which creates a system group 

Returns a tuple of (Id, Message).  If id is 0, the create failed

=cut

sub create_userDefinedGroup {
    my $self = shift;

    unless ( $self->current_user_has_right('AdminGroup') ) {
        $RT::Logger->warning( $self->current_user->Name
              . " Tried to create a group without permission." );
        return ( 0, $self->loc('Permission Denied') );
    }

    return($self->_create( Domain => 'UserDefined', Type => '', Instance => '', @_));
}

# }}}

# {{{ CcreateACLEquivalenceGroup

=head2 _createACLEquivalenceGroup { Principal }

A helper subroutine which creates a group containing only 
an individual user. This gets used by the ACL system to check rights.
Yes, it denormalizes the data, but that's ok, as we totally win on performance.

Returns a tuple of (Id, Message).  If id is 0, the create failed

=cut

sub _createACLEquivalenceGroup { 
    my $self = shift;
    my $princ = shift;
      my ($id,$msg) = $self->_create( Domain => 'ACLEquivalence', 
                           Type => 'UserEquiv',
                           Name => 'User '. $princ->Object->id,
                           Description => 'ACL equiv. for user '.$princ->Object->id,
                           Instance => $princ->id,
                           InsideTransaction => 1);

      unless ($id) {
        $RT::Logger->crit("Couldn't create ACL equivalence group -- $msg");
        return undef;
      }
    
       # We use stashuser so we don't get transactions inside transactions
       # and so we bypass all sorts of cruft we don't need
       my $aclstash = RT::Model::GroupMember->new($self->current_user);
       my ($stash_id, $add_msg) = $aclstash->_StashUser(Group => $self->PrincipalObj, Member => $princ);

      unless ($stash_id) {
        $RT::Logger->crit("Couldn't add the user to his own acl equivalence group:".$add_msg);
        # We call super delete so we don't get acl checked.
        $self->SUPER::delete();
        return(undef);
      }
    return ($id);
}

# }}}

# {{{ CreatePersonalGroup

=head2 CreatePersonalGroup { PrincipalId => PRINCIPAL_ID, Name => "name", Description => "Description"}

A helper subroutine which creates a personal group. Generally,
personal groups are used for ACL delegation and adding to ticket roles
PrincipalId defaults to the current user's principal id.

Returns a tuple of (Id, Message).  If id is 0, the create failed

=cut

sub createPersonalGroup {
    my $self = shift;
    my %args = (
        Name        => undef,
        Description => undef,
        PrincipalId => $self->current_user->PrincipalId,
        @_
    );
    if ( $self->current_user->PrincipalId == $args{'PrincipalId'} ) {

        unless ( $self->current_user_has_right('AdminOwnPersonalGroups') ) {
            $RT::Logger->warning( $self->current_user->Name
                  . " Tried to create a group without permission." );
            return ( 0, $self->loc('Permission Denied') );
        }

    }
    else {
        unless ( $self->current_user_has_right('AdminAllPersonalGroups') ) {
            $RT::Logger->warning( $self->current_user->Name
                  . " Tried to create a group without permission." );
            return ( 0, $self->loc('Permission Denied') );
        }

    }

    return (
        $self->_create(
            Domain      => 'Personal',
            Type        => '',
            Instance    => $args{'PrincipalId'},
            Name        => $args{'Name'},
            Description => $args{'Description'}
        )
    );
}

# }}}

# {{{ CreateRoleGroup 

=head2 CreateRoleGroup { Domain => DOMAIN, Type =>  TYPE, Instance => ID }

A helper subroutine which creates a  ticket group. (What RT 2.0 called Ticket watchers)
Type is one of ( "Requestor" || "Cc" || "AdminCc" || "Owner") 
Domain is one of (RT::Model::Ticket-Role || RT::Model::Queue-Role || RT::System-Role)
Instance is the id of the ticket or queue in question

This routine expects to be called from {Ticket||Queue}->createTicket_groups _inside of a transaction_

Returns a tuple of (Id, Message).  If id is 0, the create failed

=cut

sub createRoleGroup {
    my $self = shift;
    my %args = ( Instance => undef,
                 Type     => undef,
                 Domain   => undef,
                 @_ );
    unless ( $args{'Type'} =~ /^(?:Cc|AdminCc|Requestor|Owner)$/ ) {
        return ( 0, $self->loc("Invalid Group Type") );
    }


    return ( $self->_create( Domain            => $args{'Domain'},
                             Instance          => $args{'Instance'},
                             Type              => $args{'Type'},
                             InsideTransaction => 1 ) );
}

# }}}

# {{{ sub delete

=head2 Delete

Delete this object

=cut

sub delete {
    my $self = shift;

    unless ( $self->current_user_has_right('AdminGroup') ) {
        return ( 0, 'Permission Denied' );
    }

    $RT::Logger->crit("Deleting groups violates referential integrity until we go through and fix this");
    # TODO XXX 
   
    # Remove the principal object
    # Remove this group from anything it's a member of.
    # Remove all cached members of this group
    # Remove any rights granted to this group
    # remove any rights delegated by way of this group

    return ( $self->SUPER::delete(@_) );
}

# }}}

=head2 SetDisabled BOOL

If passed a positive value, this group will be disabled. No rights it commutes or grants will be honored.
It will not appear in most group listings.

This routine finds all the cached group members that are members of this group  (recursively) and disables them.

=cut 

 # }}}

 sub set_Disabled {
     my $self = shift;
     my $val = shift;
    if ($self->Domain eq 'Personal') {
   		if ($self->current_user->PrincipalId == $self->Instance) {
    		unless ( $self->current_user_has_right('AdminOwnPersonalGroups')) {
        		return ( 0, $self->loc('Permission Denied') );
    		}
    	} else {
        	unless ( $self->current_user_has_right('AdminAllPersonalGroups') ) {
   	    		 return ( 0, $self->loc('Permission Denied') );
    		}
    	}
	}
	else {
        unless ( $self->current_user_has_right('AdminGroup') ) {
                 return (0, $self->loc('Permission Denied'));
    }
    }
    Jifty->handle->begin_transaction();
    $self->PrincipalObj->set_Disabled($val);




    # Find all occurrences of this member as a member of this group
    # in the cache and nuke them, recursively.

    # The following code will delete all Cached Group members
    # where this member's group is _not_ the primary group 
    # (Ie if we're deleting C as a member of B, and B happens to be 
    # a member of A, will delete C as a member of A without touching
    # C as a member of B

    my $cached_submembers = RT::Model::CachedGroupMemberCollection->new( $self->current_user );

    $cached_submembers->limit( column    => 'ImmediateParentId', operator => '=', value    => $self->id);

    #Clear the key cache. TODO someday we may want to just clear a little bit of the keycache space. 
    # TODO what about the groups key cache?
    RT::Model::Principal->invalidate_acl_cache();



    while ( my $item = $cached_submembers->next() ) {
        my $del_err = $item->set_Disabled($val);
        unless ($del_err) {
            Jifty->handle->rollback();
            $RT::Logger->warning("Couldn't disable cached group submember ".$item->id);
            return (undef);
        }
    }

    Jifty->handle->commit();
    return (1, $self->loc("Succeeded"));

}

# }}}



sub Disabled {
    my $self = shift;
    $self->PrincipalObj->Disabled(@_);
}


# {{{ DeepMembersObj

=head2 DeepMembersObj

Returns an RT::Model::CachedGroupMemberCollection object of this group's members,
including all members of subgroups.

=cut

sub DeepMembersObj {
    my $self = shift;
    my $members_obj = RT::Model::CachedGroupMemberCollection->new( $self->current_user );

    #If we don't have rights, don't include any results
    # TODO XXX  WHY IS THERE NO ACL CHECK HERE?
    $members_obj->LimitToMembersOfGroup( $self->PrincipalId );

    return ( $members_obj );

}

# }}}

# {{{ MembersObj

=head2 MembersObj

Returns an RT::Model::GroupMemberCollection object of this group's direct members.

=cut

sub MembersObj {
    my $self = shift;
    my $members_obj = RT::Model::GroupMemberCollection->new( current_user => $self->current_user );

    #If we don't have rights, don't include any results
    # TODO XXX  WHY IS THERE NO ACL CHECK HERE?
    $members_obj->LimitToMembersOfGroup( $self->PrincipalId );

    return ( $members_obj );

}

# }}}

# {{{ GroupMembersObj

=head2 GroupMembersObj [Recursively => 1]

Returns an L<RT::Model::GroupCollection> object of this group's members.
By default returns groups including all subgroups, but
could be changed with C<Recursively> named argument.

B<Note> that groups are not filtered by type and result
may contain as well system groups, personal and other.

=cut

sub GroupMembersObj {
    my $self = shift;
    my %args = ( Recursively => 1, @_ );

    my $groups = RT::Model::GroupCollection->new( $self->current_user );
    my $members_table = $args{'Recursively'}?
        'CachedGroupMembers': 'GroupMembers';

    my $members_alias = $groups->new_alias( $members_table );
    $groups->join(
        alias1 => $members_alias,           column1 => 'MemberId',
        alias2 => $groups->PrincipalsAlias, column2 => 'id',
    );
    $groups->limit(
        alias    => $members_alias,
        column    => 'GroupId',
        value    => $self->PrincipalId,
    );
    $groups->limit(
        alias => $members_alias,
        column => 'Disabled',
        value => 0,
    ) if $args{'Recursively'};

    return $groups;
}

# }}}

# {{{ UserMembersObj

=head2 UserMembersObj

Returns an L<RT::Model::UserCollection> object of this group's members, by default
returns users including all members of subgroups, but could be
changed with C<Recursively> named argument.

=cut

sub UserMembersObj {
    my $self = shift;
    my %args = ( Recursively => 1, @_ );

    #If we don't have rights, don't include any results
    # TODO XXX  WHY IS THERE NO ACL CHECK HERE?

    my $members_table = $args{'Recursively'}?
        'CachedGroupMembers': 'GroupMembers';

    my $users = RT::Model::UserCollection->new($self->current_user);
    my $members_alias = $users->new_alias( $members_table );
    $users->join(
        alias1 => $members_alias,           column1 => 'MemberId',
        alias2 => $users->PrincipalsAlias, column2 => 'id',
    );
    $users->limit(
        alias => $members_alias,
        column => 'GroupId',
        value => $self->PrincipalId,
    );
    $users->limit(
        alias => $members_alias,
        column => 'Disabled',
        value => 0,
    ) if $args{'Recursively'};

    return ( $users);
}

# }}}

# {{{ MemberEmailAddresses

=head2 MemberEmailAddresses

Returns an array of the email addresses of all of this group's members


=cut

sub MemberEmailAddresses {
    my $self = shift;

    my %addresses;
    my $members = $self->UserMembersObj();
    while (my $member = $members->next) {
        $addresses{$member->EmailAddress} = 1;
    }
    return(sort keys %addresses);
}

# }}}

# {{{ MemberEmailAddressesAsString

=head2 MemberEmailAddressesAsString

Returns a comma delimited string of the email addresses of all users 
who are members of this group.

=cut


sub MemberEmailAddressesAsString {
    my $self = shift;
    return (join(', ', $self->MemberEmailAddresses));
}

# }}}

# {{{ AddMember

=head2 AddMember PRINCIPAL_ID

AddMember adds a principal to this group.  It takes a single principal id.
Returns a two value array. the first value is true on successful 
addition or 0 on failure.  The second value is a textual status msg.

=cut

sub AddMember {
    my $self       = shift;
    my $new_member = shift;



    if ($self->Domain eq 'Personal') {
   		if ($self->current_user->PrincipalId == $self->Instance) {
    		unless ( $self->current_user_has_right('AdminOwnPersonalGroups')) {
        		return ( 0, $self->loc('Permission Denied') );
    		}
    	} else {
        	unless ( $self->current_user_has_right('AdminAllPersonalGroups') ) {
   	    		 return ( 0, $self->loc('Permission Denied') );
    		}
    	}
	}
	
	else {	
    # We should only allow membership changes if the user has the right 
    # to modify group membership or the user is the principal in question
    # and the user has the right to modify his own membership
    unless ( ($new_member == $self->current_user->PrincipalId &&
	      $self->current_user_has_right('ModifyOwnMembership') ) ||
	      $self->current_user_has_right('AdminGroupMembership') ) {
        #User has no permission to be doing this
        return ( 0, $self->loc("Permission Denied") );
    }

  	} 
    $self->_AddMember(PrincipalId => $new_member);
}

# A helper subroutine for AddMember that bypasses the ACL checks
# this should _ONLY_ ever be called from Ticket/Queue AddWatcher
# when we want to deal with groups according to queue rights
# In the dim future, this will all get factored out and life
# will get better	

# takes a paramhash of { PrincipalId => undef, InsideTransaction }

sub _AddMember {
    my $self = shift;
    my %args = ( PrincipalId => undef,
                 InsideTransaction => undef,
                 @_);
    my $new_member = $args{'PrincipalId'};
    unless ($self->id) {
        $RT::Logger->crit("Attempting to add a member to a group which wasn't loaded. 'oops'");
        return(0, $self->loc("Group not found"));
    }

    unless ($new_member =~ /^\d+$/) {
        $RT::Logger->crit("_AddMember called with a parameter that's not an integer.");
    }


    my $new_member_obj = RT::Model::Principal->new( $self->current_user );
    $new_member_obj->load($new_member);


    unless ( $new_member_obj->id ) {
        $RT::Logger->debug("Couldn't find that principal");
        return ( 0, $self->loc("Couldn't find that principal") );
    }

    if ( $self->has_member( $new_member_obj ) ) {

        #User is already a member of this group. no need to add it
        return ( 0, $self->loc("Group already has member") );
    }
    if ( $new_member_obj->IsGroup &&
         $new_member_obj->Object->has_member_recursively($self->PrincipalObj) ) {

        #This group can't be made to be a member of itself
        return ( 0, $self->loc("Groups can't be members of their members"));
    }

    my $member_object = RT::Model::GroupMember->new( $self->current_user );
    my $id = $member_object->create(
        Member => $new_member_obj,
        Group => $self->PrincipalObj,
        InsideTransaction => $args{'InsideTransaction'}
    );
    if ($id) {
        return ( 1, $self->loc("Member added") );
    }
    else {
        return(0, $self->loc("Couldn't add member to group"));
    }
}
# }}}

# {{{ has_member

=head2 has_member RT::Model::Principal

Takes an RT::Model::Principal object returns a GroupMember Id if that user is a 
member of this group.
Returns undef if the user isn't a member of the group or if the current
user doesn't have permission to find out. Arguably, it should differentiate
between ACL failure and non membership.

=cut

sub has_member {
    my $self    = shift;
    my $principal = shift;


    unless (UNIVERSAL::isa($principal,'RT::Model::Principal')) {
        $RT::Logger->crit("Group::has_member was called with an argument that".
                          "isn't an RT::Model::Principal. It's $principal");
        return(undef);
    }

    unless ($principal->id) {
        return(undef);
    }

    my $member_obj = RT::Model::GroupMember->new( $self->current_user );
    $member_obj->load_by_cols( MemberId => $principal->id, 
                             GroupId => $self->PrincipalId );

    #If we have a member object
    if ( defined $member_obj->id ) {
        return ( $member_obj->id );
    }

    #If Load returns no objects, we have an undef id. 
    else {
        #$RT::Logger->debug($self." does not contain principal ".$principal->id);
        return (undef);
    }
}

# }}}

# {{{ has_member_recursively

=head2 has_member_recursively RT::Model::Principal

Takes an RT::Model::Principal object and returns true if that user is a member of 
this group.
Returns undef if the user isn't a member of the group or if the current
user doesn't have permission to find out. Arguably, it should differentiate
between ACL failure and non membership.

=cut

sub has_member_recursively {
    my $self    = shift;
    my $principal = shift;

    unless (UNIVERSAL::isa($principal,'RT::Model::Principal')) {
        $RT::Logger->crit("Group::has_member_recursively was called with an argument that".
                          "isn't an RT::Model::Principal. It's $principal");
        return(undef);
    }
    my $member_obj = RT::Model::CachedGroupMember->new( $self->current_user );
    $member_obj->load_by_cols( MemberId => $principal->id,
                             GroupId => $self->PrincipalId ,
                             Disabled => 0
                             );

    #If we have a member object
    if ( defined $member_obj->id ) {
        return ( 1);
    }

    #If Load returns no objects, we have an undef id. 
    else {
        return (undef);
    }
}

# }}}

# {{{ delete_member

=head2 delete_member PRINCIPAL_ID

Takes the principal id of a current user or group.
If the current user has apropriate rights,
removes that GroupMember from this group.
Returns a two value array. the first value is true on successful 
addition or 0 on failure.  The second value is a textual status msg.

=cut

sub delete_member {
    my $self   = shift;
    my $member_id = shift;


    # We should only allow membership changes if the user has the right 
    # to modify group membership or the user is the principal in question
    # and the user has the right to modify his own membership

    if ($self->Domain eq 'Personal') {
   		if ($self->current_user->PrincipalId == $self->Instance) {
    		unless ( $self->current_user_has_right('AdminOwnPersonalGroups')) {
        		return ( 0, $self->loc('Permission Denied') );
    		}
    	} else {
        	unless ( $self->current_user_has_right('AdminAllPersonalGroups') ) {
   	    		 return ( 0, $self->loc('Permission Denied') );
    		}
    	}
	}
	else {
    unless ( (($member_id == $self->current_user->PrincipalId) &&
	      $self->current_user_has_right('ModifyOwnMembership') ) ||
	      $self->current_user_has_right('AdminGroupMembership') ) {
        #User has no permission to be doing this
        return ( 0, $self->loc("Permission Denied") );
    }
	}
    $self->_delete_member($member_id);
}

# A helper subroutine for delete_member that bypasses the ACL checks
# this should _ONLY_ ever be called from Ticket/Queue  DeleteWatcher
# when we want to deal with groups according to queue rights
# In the dim future, this will all get factored out and life
# will get better	

sub _delete_member {
    my $self = shift;
    my $member_id = shift;

    my $member_obj =  RT::Model::GroupMember->new( $self->current_user );
    
    $member_obj->load_by_cols( MemberId  => $member_id,
                             GroupId => $self->PrincipalId);


    #If we couldn't load it, return undef.
    unless ( $member_obj->id() ) {
        $RT::Logger->debug("Group has no member with that id");
        return ( 0,$self->loc( "Group has no such member" ));
    }

    #Now that we've checked ACLs and sanity, delete the groupmember
    my $val = $member_obj->delete();

    if ($val) {
        return ( $val, $self->loc("Member deleted") );
    }
    else {
        $RT::Logger->debug("Failed to delete group ".$self->id." member ". $member_id);
        return ( 0, $self->loc("Member not deleted" ));
    }
}

# }}}

# {{{ sub _CleanupInvalidDelegations

=head2 _CleanupInvalidDelegations { InsideTransaction => undef }

Revokes all ACE entries delegated by members of this group which are
inconsistent with their current delegation rights.  Does not perform
permission checks.  Should only ever be called from inside the RT
library.

If called from inside a transaction, specify a true value for the
InsideTransaction parameter.

Returns a true value if the deletion succeeded; returns a false value
and logs an internal error if the deletion fails (should not happen).

=cut

# XXX Currently there is a _CleanupInvalidDelegations method in both
# RT::Model::User and RT::Model::Group.  If the recursive cleanup call for groups is
# ever unrolled and merged, this code will probably want to be
# factored out into RT::Model::Principal.

sub _CleanupInvalidDelegations {
    my $self = shift;
    my %args = ( InsideTransaction => undef,
		  @_ );

    unless ( $self->id ) {
	$RT::Logger->warning("Group not loaded.");
	return (undef);
    }

    my $in_trans = $args{InsideTransaction};

    # TODO: Can this be unrolled such that the number of DB queries is constant rather than linear in exploded group size?
    my $members = $self->DeepMembersObj();
    $members->LimitToUsers();
    Jifty->handle->begin_transaction() unless $in_trans;
    while ( my $member = $members->next()) {
	my $ret = $member->MemberObj->_CleanupInvalidDelegations(InsideTransaction => 1,
								 Object => $args{Object});
	unless ($ret) {
	    Jifty->handle->rollback() unless $in_trans;
	    return (undef);
	}
    }
    Jifty->handle->commit() unless $in_trans;
    return(1);
}

# }}}

# {{{ ACL Related routines

# {{{ sub _set
sub _set {
    my $self = shift;
    my %args = (
        column => undef,
        value => undef,
	TransactionType   => 'Set',
	RecordTransaction => 1,
        @_
    );

	if ($self->Domain eq 'Personal') {
   		if ($self->current_user->PrincipalId == $self->Instance) {
    		unless ( $self->current_user_has_right('AdminOwnPersonalGroups')) {
        		return ( 0, $self->loc('Permission Denied') );
    		}
    	} else {
        	unless ( $self->current_user_has_right('AdminAllPersonalGroups') ) {
   	    		 return ( 0, $self->loc('Permission Denied') );
    		}
    	}
	}
	else {
    	unless ( $self->current_user_has_right('AdminGroup') ) {
        	return ( 0, $self->loc('Permission Denied') );
    	}
	}

    my $Old = $self->SUPER::_value("$args{'Field'}");
    
    my ($ret, $msg) = $self->SUPER::_set( column => $args{'Field'},
					  value => $args{'Value'} );
    
    #If we can't actually set the field to the value, don't record
    # a transaction. instead, get out of here.
    if ( $ret == 0 ) { return ( 0, $msg ); }

    if ( $args{'RecordTransaction'} == 1 ) {

        my ( $Trans, $Msg, $TransObj ) = $self->_NewTransaction(
                                               Type => $args{'TransactionType'},
                                               Field     => $args{'Field'},
                                               NewValue  => $args{'Value'},
                                               OldValue  => $Old,
                                               TimeTaken => $args{'TimeTaken'},
        );
        return ( $Trans, scalar $TransObj->Description );
    }
    else {
        return ( $ret, $msg );
    }
}

# }}}




=head2 current_user_has_right RIGHTNAME

Returns true if the current user has the specified right for this group.


    TODO: we don't deal with membership visibility yet

=cut


sub current_user_has_right {
    my $self = shift;
    my $right = shift;



    if ($self->id && 
		$self->current_user->has_right( Object => $self,
										   Right => $right )) {
        return(1);
   }
    elsif ( $self->current_user->has_right(Object => RT->System, Right =>  $right )) {
		return (1);
    } else {
        return(undef);
    }

}

# }}}




# {{{ Principal related routines

=head2 PrincipalObj

Returns the principal object for this user. returns an empty RT::Model::Principal
if there's no principal object matching this user. 
The response is cached. PrincipalObj should never ever change.


=cut


sub PrincipalObj {
    my $self = shift;
    unless ($self->{'PrincipalObj'} &&
            ($self->{'PrincipalObj'}->ObjectId == $self->id) &&
            ($self->{'PrincipalObj'}->PrincipalType eq 'Group')) {

            $self->{'PrincipalObj'} = RT::Model::Principal->new($self->current_user);
            $self->{'PrincipalObj'}->load_by_cols('ObjectId' => $self->id,
                                                'PrincipalType' => 'Group') ;
            }
    return($self->{'PrincipalObj'});
}


=head2 PrincipalId  

Returns this user's PrincipalId

=cut

sub PrincipalId {
    my $self = shift;
    return $self->id;
}

# }}}

sub BasicColumns {
    (
	[ Name => 'Name' ],
	[ Description => 'Description' ],
    );
}

1;

=head1 AUTHOR

Jesse Vincent, jesse@bestpractical.com

=head1 SEE ALSO

RT


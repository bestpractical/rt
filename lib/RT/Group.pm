
# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2017 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
#
# (Except where explicitly superseded by other copyright notices)
#
#
# LICENSE:
#
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
#
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
#
#
# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
#
# END BPS TAGGED BLOCK }}}

# Released under the terms of version 2 of the GNU Public License

=head1 NAME

  RT::Group - RT's group object

=head1 SYNOPSIS

use RT::Group;
my $group = RT::Group->new($CurrentUser);

=head1 DESCRIPTION

An RT group object.

=head1 METHODS





=cut


package RT::Group;


use strict;
use warnings;

use base 'RT::Record';

sub Table {'Groups'}



use RT::Users;
use RT::GroupMembers;
use RT::Principals;
use RT::ACL;

use vars qw/$RIGHTS $RIGHT_CATEGORIES/;

$RIGHTS = {
    AdminGroup              => 'Modify group metadata or delete group',     # loc_pair
    AdminGroupMembership    => 'Modify group membership roster',            # loc_pair
    ModifyOwnMembership     => 'Join or leave group',                       # loc_pair
    EditSavedSearches       => 'Create, modify and delete saved searches',  # loc_pair
    ShowSavedSearches       => 'View saved searches',                       # loc_pair
    SeeGroup                => 'View group',                                # loc_pair
    SeeGroupDashboard       => 'View group dashboards',                     # loc_pair
    CreateGroupDashboard    => 'Create group dashboards',                   # loc_pair
    ModifyGroupDashboard    => 'Modify group dashboards',                   # loc_pair
    DeleteGroupDashboard    => 'Delete group dashboards',                   # loc_pair
};

$RIGHT_CATEGORIES = {
    AdminGroup              => 'Admin',
    AdminGroupMembership    => 'Admin',
    ModifyOwnMembership     => 'Staff',
    EditSavedSearches       => 'Admin',
    ShowSavedSearches       => 'Staff',
    SeeGroup                => 'Staff',
    SeeGroupDashboard       => 'Staff',
    CreateGroupDashboard    => 'Admin',
    ModifyGroupDashboard    => 'Admin',
    DeleteGroupDashboard    => 'Admin',
};

# Tell RT::ACE that this sort of object can get acls granted
$RT::ACE::OBJECT_TYPES{'RT::Group'} = 1;


#

# TODO: This should be refactored out into an RT::ACLedObject or something
# stuff the rights into a hash of rights that can exist.

__PACKAGE__->AddRights(%$RIGHTS);
__PACKAGE__->AddRightCategories(%$RIGHT_CATEGORIES);

=head2 AddRights C<RIGHT>, C<DESCRIPTION> [, ...]

Adds the given rights to the list of possible rights.  This method
should be called during server startup, not at runtime.

=cut

sub AddRights {
    my $self = shift;
    my %new = @_;
    $RIGHTS = { %$RIGHTS, %new };
    %RT::ACE::LOWERCASERIGHTNAMES = ( %RT::ACE::LOWERCASERIGHTNAMES,
                                      map { lc($_) => $_ } keys %new);
}

=head2 AvailableRights

Returns a hash of available rights for this object. The keys are the right names and the values are a description of what the rights do

=cut

sub AvailableRights {
    my $self = shift;
    return($RIGHTS);
}

=head2 RightCategories

Returns a hashref where the keys are rights for this type of object and the
values are the category (General, Staff, Admin) the right falls into.

=cut

sub RightCategories {
    return $RIGHT_CATEGORIES;
}

=head2 AddRightCategories C<RIGHT>, C<CATEGORY> [, ...]

Adds the given right and category pairs to the list of right categories.  This
method should be called during server startup, not at runtime.

=cut

sub AddRightCategories {
    my $self = shift if ref $_[0] or $_[0] eq __PACKAGE__;
    my %new = @_;
    $RIGHT_CATEGORIES = { %$RIGHT_CATEGORIES, %new };
}



=head2 SelfDescription

Returns a user-readable description of what this group is for and what it's named.

=cut

sub SelfDescription {
	my $self = shift;
	if ($self->Domain eq 'ACLEquivalence') {
		my $user = RT::Principal->new($self->CurrentUser);
		$user->Load($self->Instance);
		return $self->loc("user [_1]",$user->Object->Name);
	}
	elsif ($self->Domain eq 'UserDefined') {
		return $self->loc("group '[_1]'",$self->Name);
	}
	elsif ($self->Domain eq 'RT::System-Role') {
		return $self->loc("system [_1]",$self->Type);
	}
	elsif ($self->Domain eq 'RT::Queue-Role') {
		my $queue = RT::Queue->new($self->CurrentUser);
		$queue->Load($self->Instance);
		return $self->loc("queue [_1] [_2]",$queue->Name, $self->Type);
	}
	elsif ($self->Domain eq 'RT::Ticket-Role') {
		return $self->loc("ticket #[_1] [_2]",$self->Instance, $self->Type);
	}
	elsif ($self->Domain eq 'SystemInternal') {
		return $self->loc("system group '[_1]'",$self->Type);
	}
	else {
		return $self->loc("undescribed group [_1]",$self->Id);
	}
}



=head2 Load ID

Load a group object from the database. Takes a single argument.
If the argument is numerical, load by the column 'id'. Otherwise, 
complain and return.

=cut

sub Load {
    my $self       = shift;
    my $identifier = shift || return undef;

    if ( $identifier !~ /\D/ ) {
        $self->SUPER::LoadById($identifier);
    }
    else {
        $RT::Logger->crit("Group -> Load called with a bogus argument");
        return undef;
    }
}



=head2 LoadUserDefinedGroup NAME

Loads a system group from the database. The only argument is
the group's name.


=cut

sub LoadUserDefinedGroup {
    my $self       = shift;
    my $identifier = shift;

    if ( $identifier =~ /^\d+$/ ) {
        return $self->LoadByCols(
            Domain => 'UserDefined',
            id     => $identifier,
        );
    } else {
        return $self->LoadByCols(
            Domain => 'UserDefined',
            Name   => $identifier,
        );
    }
}



=head2 LoadACLEquivalenceGroup PRINCIPAL

Loads a user's acl equivalence group. Takes a principal object or its ID.
ACL equivalnce groups are used to simplify the acl system. Each user
has one group that only he is a member of. Rights granted to the user
are actually granted to that group. This greatly simplifies ACL checks.
While this results in a somewhat more complex setup when creating users
and granting ACLs, it _greatly_ simplifies acl checks.

=cut

sub LoadACLEquivalenceGroup {
    my $self = shift;
    my $principal = shift;
    $principal = $principal->id if ref $principal;

    return $self->LoadByCols(
        Domain   => 'ACLEquivalence',
        Type     => 'UserEquiv',
        Instance => $principal,
    );
}




=head2 LoadSystemInternalGroup NAME

Loads a Pseudo group from the database. The only argument is
the group's name.


=cut

sub LoadSystemInternalGroup {
    my $self       = shift;
    my $identifier = shift;

    return $self->LoadByCols(
        Domain => 'SystemInternal',
        Type   => $identifier,
    );
}



=head2 LoadTicketRoleGroup  { Ticket => TICKET_ID, Type => TYPE }

Loads a ticket group from the database. 

Takes a param hash with 2 parameters:

    Ticket is the TicketId we're curious about
    Type is the type of Group we're trying to load: 
        Requestor, Cc, AdminCc, Owner

=cut

sub LoadTicketRoleGroup {
    my $self       = shift;
    my %args = (Ticket => '0',
                Type => undef,
                @_);
        $self->LoadByCols( Domain => 'RT::Ticket-Role',
                           Instance =>$args{'Ticket'}, 
                           Type => $args{'Type'}
                           );
}



=head2 LoadQueueRoleGroup  { Queue => Queue_ID, Type => TYPE }

Loads a Queue group from the database. 

Takes a param hash with 2 parameters:

    Queue is the QueueId we're curious about
    Type is the type of Group we're trying to load: 
        Requestor, Cc, AdminCc, Owner

=cut

sub LoadQueueRoleGroup {
    my $self       = shift;
    my %args = (Queue => undef,
                Type => undef,
                @_);
        $self->LoadByCols( Domain => 'RT::Queue-Role',
                           Instance =>$args{'Queue'}, 
                           Type => $args{'Type'}
                           );
}



=head2 LoadSystemRoleGroup  Type

Loads a System group from the database. 

Takes a single param: Type

    Type is the type of Group we're trying to load: 
        Requestor, Cc, AdminCc, Owner

=cut

sub LoadSystemRoleGroup {
    my $self       = shift;
    my $type = shift;
        $self->LoadByCols( Domain => 'RT::System-Role',
                           Type => $type
                           );
}



=head2 Create

You need to specify what sort of group you're creating by calling one of the other
Create_____ routines.

=cut

sub Create {
    my $self = shift;
    $RT::Logger->crit("Someone called RT::Group->Create. this method does not exist. someone's being evil");
    return(0,$self->loc('Permission Denied'));
}



=head2 _Create

Takes a paramhash with named arguments: Name, Description.

Returns a tuple of (Id, Message).  If id is 0, the create failed

=cut

sub _Create {
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

    # Enforce uniqueness on user defined group names
    if ($args{'Domain'} and $args{'Domain'} eq 'UserDefined') {
        my ($ok, $msg) = $self->_ValidateUserDefinedName($args{'Name'});
        return ($ok, $msg) if not $ok;
    }

    $RT::Handle->BeginTransaction() unless ($args{'InsideTransaction'});
    # Groups deal with principal ids, rather than user ids.
    # When creating this group, set up a principal Id for it.
    my $principal    = RT::Principal->new( $self->CurrentUser );
    my $principal_id = $principal->Create(
        PrincipalType => 'Group',
        ObjectId      => '0'
    );
    $principal->__Set(Field => 'ObjectId', Value => $principal_id);

    $self->SUPER::Create(
        id          => $principal_id,
        Name        => $args{'Name'},
        Description => $args{'Description'},
        Type        => $args{'Type'},
        Domain      => $args{'Domain'},
        Instance    => ($args{'Instance'} || '0')
    );
    my $id = $self->Id;
    unless ($id) {
        $RT::Handle->Rollback() unless ($args{'InsideTransaction'});
        return ( 0, $self->loc('Could not create group') );
    }

    # If we couldn't create a principal Id, get the fuck out.
    unless ($principal_id) {
        $RT::Handle->Rollback() unless ($args{'InsideTransaction'});
        $RT::Logger->crit( "Couldn't create a Principal on new user create. Strange things are afoot at the circle K" );
        return ( 0, $self->loc('Could not create group') );
    }

    # Now we make the group a member of itself as a cached group member
    # this needs to exist so that group ACL checks don't fall over.
    # you're checking CachedGroupMembers to see if the principal in question
    # is a member of the principal the rights have been granted too

    # in the ordinary case, this would fail badly because it would recurse and add all the members of this group as 
    # cached members. thankfully, we're creating the group now...so it has no members.
    my $cgm = RT::CachedGroupMember->new($self->CurrentUser);
    $cgm->Create(Group =>$self->PrincipalObj, Member => $self->PrincipalObj, ImmediateParent => $self->PrincipalObj);


    if ( $args{'_RecordTransaction'} ) {
        $self->_NewTransaction( Type => "Create" );
    }

    $RT::Handle->Commit() unless ($args{'InsideTransaction'});

    return ( $id, $self->loc("Group created") );
}



=head2 CreateUserDefinedGroup { Name => "name", Description => "Description"}

A helper subroutine which creates a system group 

Returns a tuple of (Id, Message).  If id is 0, the create failed

=cut

sub CreateUserDefinedGroup {
    my $self = shift;

    unless ( $self->CurrentUserHasRight('AdminGroup') ) {
        $RT::Logger->warning( $self->CurrentUser->Name
              . " Tried to create a group without permission." );
        return ( 0, $self->loc('Permission Denied') );
    }

    return($self->_Create( Domain => 'UserDefined', Type => '', Instance => '', @_));
}

=head2 ValidateName VALUE

Enforces unique user defined group names when updating

=cut

sub ValidateName {
    my ($self, $value) = @_;

    if ($self->Domain and $self->Domain eq 'UserDefined') {
        my ($ok, $msg) = $self->_ValidateUserDefinedName($value);
        # It's really too bad we can't pass along the actual error
        return 0 if not $ok;
    }
    return $self->SUPER::ValidateName($value);
}

=head2 _ValidateUserDefinedName VALUE

Returns true if the user defined group name isn't in use, false otherwise.

=cut

sub _ValidateUserDefinedName {
    my ($self, $value) = @_;

    return (0, 'Name is required') unless length $value;

    my $dupcheck = RT::Group->new(RT->SystemUser);
    $dupcheck->LoadUserDefinedGroup($value);
    if ( $dupcheck->id && ( !$self->id || $self->id != $dupcheck->id ) ) {
        return ( 0, $self->loc( "Group name '[_1]' is already in use", $value ) );
    }
    return 1;
}

=head2 _CreateACLEquivalenceGroup { Principal }

A helper subroutine which creates a group containing only 
an individual user. This gets used by the ACL system to check rights.
Yes, it denormalizes the data, but that's ok, as we totally win on performance.

Returns a tuple of (Id, Message).  If id is 0, the create failed

=cut

sub _CreateACLEquivalenceGroup { 
    my $self = shift;
    my $princ = shift;
 
      my $id = $self->_Create( Domain => 'ACLEquivalence', 
                           Type => 'UserEquiv',
                           Name => 'User '. $princ->Object->Id,
                           Description => 'ACL equiv. for user '.$princ->Object->Id,
                           Instance => $princ->Id,
                           InsideTransaction => 1,
                           _RecordTransaction => 0 );
      unless ($id) {
        $RT::Logger->crit("Couldn't create ACL equivalence group");
        return undef;
      }
    
       # We use stashuser so we don't get transactions inside transactions
       # and so we bypass all sorts of cruft we don't need
       my $aclstash = RT::GroupMember->new($self->CurrentUser);
       my ($stash_id, $add_msg) = $aclstash->_StashUser(Group => $self->PrincipalObj,
                                             Member => $princ);

      unless ($stash_id) {
        $RT::Logger->crit("Couldn't add the user to his own acl equivalence group:".$add_msg);
        # We call super delete so we don't get acl checked.
        $self->SUPER::Delete();
        return(undef);
      }
    return ($id);
}




=head2 CreateRoleGroup { Domain => DOMAIN, Type =>  TYPE, Instance => ID }

A helper subroutine which creates a  ticket group. (What RT 2.0 called Ticket watchers)
Type is one of ( "Requestor" || "Cc" || "AdminCc" || "Owner") 
Domain is one of (RT::Ticket-Role || RT::Queue-Role || RT::System-Role)
Instance is the id of the ticket or queue in question

This routine expects to be called from {Ticket||Queue}->CreateTicketGroups _inside of a transaction_

Returns a tuple of (Id, Message).  If id is 0, the create failed

=cut

sub CreateRoleGroup {
    my $self = shift;
    my %args = ( Instance => undef,
                 Type     => undef,
                 Domain   => undef,
                 @_ );

    unless (RT::Queue->IsRoleGroupType($args{Type})) {
        return ( 0, $self->loc("Invalid Group Type") );
    }


    return ( $self->_Create( Domain            => $args{'Domain'},
                             Instance          => $args{'Instance'},
                             Type              => $args{'Type'},
                             InsideTransaction => 1 ) );
}



=head2 Delete

Delete this object

=cut

sub Delete {
    my $self = shift;

    unless ( $self->CurrentUserHasRight('AdminGroup') ) {
        return ( 0, 'Permission Denied' );
    }

    $RT::Logger->crit("Deleting groups violates referential integrity until we go through and fix this");
    # TODO XXX 
   
    # Remove the principal object
    # Remove this group from anything it's a member of.
    # Remove all cached members of this group
    # Remove any rights granted to this group
    # remove any rights delegated by way of this group

    return ( $self->SUPER::Delete(@_) );
}


=head2 SetDisabled BOOL

If passed a positive value, this group will be disabled. No rights it commutes or grants will be honored.
It will not appear in most group listings.

This routine finds all the cached group members that are members of this group  (recursively) and disables them.

=cut 

 # }}}

 sub SetDisabled {
     my $self = shift;
     my $val = shift;
     unless ( $self->CurrentUserHasRight('AdminGroup') ) {
        return (0, $self->loc('Permission Denied'));
    }
    $RT::Handle->BeginTransaction();
    $self->PrincipalObj->SetDisabled($val);




    # Find all occurrences of this member as a member of this group
    # in the cache and nuke them, recursively.

    # The following code will delete all Cached Group members
    # where this member's group is _not_ the primary group 
    # (Ie if we're deleting C as a member of B, and B happens to be 
    # a member of A, will delete C as a member of A without touching
    # C as a member of B

    my $cached_submembers = RT::CachedGroupMembers->new( $self->CurrentUser );

    $cached_submembers->Limit( FIELD    => 'ImmediateParentId', OPERATOR => '=', VALUE    => $self->Id);

    #Clear the key cache. TODO someday we may want to just clear a little bit of the keycache space. 
    # TODO what about the groups key cache?
    RT::Principal->InvalidateACLCache();



    while ( my $item = $cached_submembers->Next() ) {
        my $del_err = $item->SetDisabled($val);
        unless ($del_err) {
            $RT::Handle->Rollback();
            $RT::Logger->warning("Couldn't disable cached group submember ".$item->Id);
            return (undef);
        }
    }

    $self->_NewTransaction( Type => ($val == 1) ? "Disabled" : "Enabled" );

    $RT::Handle->Commit();
    if ( $val == 1 ) {
        return (1, $self->loc("Group disabled"));
    } else {
        return (1, $self->loc("Group enabled"));
    }

}




sub Disabled {
    my $self = shift;
    $self->PrincipalObj->Disabled(@_);
}



=head2 DeepMembersObj

Returns an RT::CachedGroupMembers object of this group's members,
including all members of subgroups.

=cut

sub DeepMembersObj {
    my $self = shift;
    my $members_obj = RT::CachedGroupMembers->new( $self->CurrentUser );

    #If we don't have rights, don't include any results
    # TODO XXX  WHY IS THERE NO ACL CHECK HERE?
    $members_obj->LimitToMembersOfGroup( $self->PrincipalId );

    return ( $members_obj );

}



=head2 MembersObj

Returns an RT::GroupMembers object of this group's direct members.

=cut

sub MembersObj {
    my $self = shift;
    my $members_obj = RT::GroupMembers->new( $self->CurrentUser );

    #If we don't have rights, don't include any results
    # TODO XXX  WHY IS THERE NO ACL CHECK HERE?
    $members_obj->LimitToMembersOfGroup( $self->PrincipalId );

    return ( $members_obj );

}



=head2 GroupMembersObj [Recursively => 1]

Returns an L<RT::Groups> object of this group's members.
By default returns groups including all subgroups, but
could be changed with C<Recursively> named argument.

B<Note> that groups are not filtered by type and result
may contain as well system groups and others.

=cut

sub GroupMembersObj {
    my $self = shift;
    my %args = ( Recursively => 1, @_ );

    my $groups = RT::Groups->new( $self->CurrentUser );
    my $members_table = $args{'Recursively'}?
        'CachedGroupMembers': 'GroupMembers';

    my $members_alias = $groups->NewAlias( $members_table );
    $groups->Join(
        ALIAS1 => $members_alias,           FIELD1 => 'MemberId',
        ALIAS2 => $groups->PrincipalsAlias, FIELD2 => 'id',
    );
    $groups->Limit(
        ALIAS    => $members_alias,
        FIELD    => 'GroupId',
        VALUE    => $self->PrincipalId,
    );
    $groups->Limit(
        ALIAS => $members_alias,
        FIELD => 'Disabled',
        VALUE => 0,
    ) if $args{'Recursively'};

    return $groups;
}



=head2 UserMembersObj

Returns an L<RT::Users> object of this group's members, by default
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

    my $users = RT::Users->new($self->CurrentUser);
    my $members_alias = $users->NewAlias( $members_table );
    $users->Join(
        ALIAS1 => $members_alias,           FIELD1 => 'MemberId',
        ALIAS2 => $users->PrincipalsAlias, FIELD2 => 'id',
    );
    $users->Limit(
        ALIAS => $members_alias,
        FIELD => 'GroupId',
        VALUE => $self->PrincipalId,
    );
    $users->Limit(
        ALIAS => $members_alias,
        FIELD => 'Disabled',
        VALUE => 0,
    ) if $args{'Recursively'};

    return ( $users);
}



=head2 MemberEmailAddresses

Returns an array of the email addresses of all of this group's members


=cut

sub MemberEmailAddresses {
    my $self = shift;
    return sort grep defined && length,
        map $_->EmailAddress,
        @{ $self->UserMembersObj->ItemsArrayRef };
}



=head2 MemberEmailAddressesAsString

Returns a comma delimited string of the email addresses of all users 
who are members of this group.

=cut


sub MemberEmailAddressesAsString {
    my $self = shift;
    return (join(', ', $self->MemberEmailAddresses));
}



=head2 AddMember PRINCIPAL_ID

AddMember adds a principal to this group.  It takes a single principal id.
Returns a two value array. the first value is true on successful 
addition or 0 on failure.  The second value is a textual status msg.

=cut

sub AddMember {
    my $self       = shift;
    my $new_member = shift;



    # We should only allow membership changes if the user has the right 
    # to modify group membership or the user is the principal in question
    # and the user has the right to modify his own membership
    unless ( ($new_member == $self->CurrentUser->PrincipalId &&
	      $self->CurrentUserHasRight('ModifyOwnMembership') ) ||
	      $self->CurrentUserHasRight('AdminGroupMembership') ) {
        #User has no permission to be doing this
        return ( 0, $self->loc("Permission Denied") );
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

    unless ($self->Id) {
        $RT::Logger->crit("Attempting to add a member to a group which wasn't loaded. 'oops'");
        return(0, $self->loc("Group not found"));
    }

    unless ($new_member =~ /^\d+$/) {
        $RT::Logger->crit("_AddMember called with a parameter that's not an integer.");
    }


    my $new_member_obj = RT::Principal->new( $self->CurrentUser );
    $new_member_obj->Load($new_member);


    unless ( $new_member_obj->Id ) {
        $RT::Logger->debug("Couldn't find that principal");
        return ( 0, $self->loc("Couldn't find that principal") );
    }

    if ( $self->HasMember( $new_member_obj ) ) {

        #User is already a member of this group. no need to add it
        return ( 0, $self->loc("Group already has member: [_1]", $new_member_obj->Object->Name) );
    }
    if ( $new_member_obj->IsGroup &&
         $new_member_obj->Object->HasMemberRecursively($self->PrincipalObj) ) {

        #This group can't be made to be a member of itself
        return ( 0, $self->loc("Groups can't be members of their members"));
    }


    my $member_object = RT::GroupMember->new( $self->CurrentUser );
    my $id = $member_object->Create(
        Member => $new_member_obj,
        Group => $self->PrincipalObj,
        InsideTransaction => $args{'InsideTransaction'}
    );
    if ($id) {
        return ( 1, $self->loc("Member added: [_1]", $new_member_obj->Object->Name) );
    }
    else {
        return(0, $self->loc("Couldn't add member to group"));
    }
}


=head2 HasMember RT::Principal|id

Takes an L<RT::Principal> object or its id returns a GroupMember Id if that user is a 
member of this group.
Returns undef if the user isn't a member of the group or if the current
user doesn't have permission to find out. Arguably, it should differentiate
between ACL failure and non membership.

=cut

sub HasMember {
    my $self    = shift;
    my $principal = shift;

    my $id;
    if ( UNIVERSAL::isa($principal,'RT::Principal') ) {
        $id = $principal->id;
    } elsif ( $principal =~ /^\d+$/ ) {
        $id = $principal;
    } else {
        $RT::Logger->error("Group::HasMember was called with an argument that".
                          " isn't an RT::Principal or id. It's ".($principal||'(undefined)'));
        return(undef);
    }
    return undef unless $id;

    my $member_obj = RT::GroupMember->new( $self->CurrentUser );
    $member_obj->LoadByCols(
        MemberId => $id, 
        GroupId  => $self->PrincipalId
    );

    if ( my $member_id = $member_obj->id ) {
        return $member_id;
    }
    else {
        return (undef);
    }
}



=head2 HasMemberRecursively RT::Principal|id

Takes an L<RT::Principal> object or its id and returns true if that user is a member of 
this group.
Returns undef if the user isn't a member of the group or if the current
user doesn't have permission to find out. Arguably, it should differentiate
between ACL failure and non membership.

=cut

sub HasMemberRecursively {
    my $self    = shift;
    my $principal = shift;

    my $id;
    if ( UNIVERSAL::isa($principal,'RT::Principal') ) {
        $id = $principal->id;
    } elsif ( $principal =~ /^\d+$/ ) {
        $id = $principal;
    } else {
        $RT::Logger->error("Group::HasMemberRecursively was called with an argument that".
                          " isn't an RT::Principal or id. It's $principal");
        return(undef);
    }
    return undef unless $id;

    my $member_obj = RT::CachedGroupMember->new( $self->CurrentUser );
    $member_obj->LoadByCols(
        MemberId => $id, 
        GroupId  => $self->PrincipalId
    );

    if ( my $member_id = $member_obj->id ) {
        return $member_id;
    }
    else {
        return (undef);
    }
}



=head2 DeleteMember PRINCIPAL_ID

Takes the principal id of a current user or group.
If the current user has apropriate rights,
removes that GroupMember from this group.
Returns a two value array. the first value is true on successful 
addition or 0 on failure.  The second value is a textual status msg.

=cut

sub DeleteMember {
    my $self   = shift;
    my $member_id = shift;


    # We should only allow membership changes if the user has the right 
    # to modify group membership or the user is the principal in question
    # and the user has the right to modify his own membership

    unless ( (($member_id == $self->CurrentUser->PrincipalId) &&
	      $self->CurrentUserHasRight('ModifyOwnMembership') ) ||
	      $self->CurrentUserHasRight('AdminGroupMembership') ) {
        #User has no permission to be doing this
        return ( 0, $self->loc("Permission Denied") );
    }
    $self->_DeleteMember($member_id);
}

# A helper subroutine for DeleteMember that bypasses the ACL checks
# this should _ONLY_ ever be called from Ticket/Queue  DeleteWatcher
# when we want to deal with groups according to queue rights
# In the dim future, this will all get factored out and life
# will get better	

sub _DeleteMember {
    my $self = shift;
    my $member_id = shift;

    my $member_obj =  RT::GroupMember->new( $self->CurrentUser );
    
    $member_obj->LoadByCols( MemberId  => $member_id,
                             GroupId => $self->PrincipalId);


    #If we couldn't load it, return undef.
    unless ( $member_obj->Id() ) {
        $RT::Logger->debug("Group has no member with that id");
        return ( 0,$self->loc( "Group has no such member" ));
    }

    #Now that we've checked ACLs and sanity, delete the groupmember
    my $val = $member_obj->Delete();

    if ($val) {
        return ( $val, $self->loc("Member deleted") );
    }
    else {
        $RT::Logger->debug("Failed to delete group ".$self->Id." member ". $member_id);
        return ( 0, $self->loc("Member not deleted" ));
    }
}



sub _Set {
    my $self = shift;
    my %args = (
        Field => undef,
        Value => undef,
	TransactionType   => 'Set',
	RecordTransaction => 1,
        @_
    );

    unless ( $self->CurrentUserHasRight('AdminGroup') ) {
      	return ( 0, $self->loc('Permission Denied') );
	}

    my $Old = $self->SUPER::_Value("$args{'Field'}");
    
    my ($ret, $msg) = $self->SUPER::_Set( Field => $args{'Field'},
					  Value => $args{'Value'} );
    
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





=head2 CurrentUserHasRight RIGHTNAME

Returns true if the current user has the specified right for this group.


    TODO: we don't deal with membership visibility yet

=cut


sub CurrentUserHasRight {
    my $self = shift;
    my $right = shift;



    if ($self->Id && 
		$self->CurrentUser->HasRight( Object => $self,
										   Right => $right )) {
        return(1);
   }
    elsif ( $self->CurrentUser->HasRight(Object => $RT::System, Right =>  $right )) {
		return (1);
    } else {
        return(undef);
    }

}


=head2 CurrentUserCanSee

Always returns 1; unfortunately, for historical reasons, users have
always been able to examine groups they have indirect access to, even if
they do not have SeeGroup explicitly.

=cut

sub CurrentUserCanSee {
    my $self = shift;
    return 1;
}


=head2 PrincipalObj

Returns the principal object for this user. returns an empty RT::Principal
if there's no principal object matching this user. 
The response is cached. PrincipalObj should never ever change.


=cut


sub PrincipalObj {
    my $self = shift;
    unless ( defined $self->{'PrincipalObj'} &&
             defined $self->{'PrincipalObj'}->ObjectId &&
            ($self->{'PrincipalObj'}->ObjectId == $self->Id) &&
            (defined $self->{'PrincipalObj'}->PrincipalType && 
                $self->{'PrincipalObj'}->PrincipalType eq 'Group')) {

            $self->{'PrincipalObj'} = RT::Principal->new($self->CurrentUser);
            $self->{'PrincipalObj'}->LoadByCols('ObjectId' => $self->Id,
                                                'PrincipalType' => 'Group') ;
            }
    return($self->{'PrincipalObj'});
}


=head2 PrincipalId  

Returns this user's PrincipalId

=cut

sub PrincipalId {
    my $self = shift;
    return $self->Id;
}


sub BasicColumns {
    (
	[ Name => 'Name' ],
	[ Description => 'Description' ],
    );
}


=head1 AUTHOR

Jesse Vincent, jesse@bestpractical.com

=head1 SEE ALSO

RT

=cut





=head2 id

Returns the current value of id.
(In the database, id is stored as int(11).)


=cut


=head2 Name

Returns the current value of Name.
(In the database, Name is stored as varchar(200).)



=head2 SetName VALUE


Set Name to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Name will be stored as a varchar(200).)


=cut


=head2 Description

Returns the current value of Description.
(In the database, Description is stored as varchar(255).)



=head2 SetDescription VALUE


Set Description to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Description will be stored as a varchar(255).)


=cut


=head2 Domain

Returns the current value of Domain.
(In the database, Domain is stored as varchar(64).)



=head2 SetDomain VALUE


Set Domain to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Domain will be stored as a varchar(64).)


=cut


=head2 Type

Returns the current value of Type.
(In the database, Type is stored as varchar(64).)



=head2 SetType VALUE


Set Type to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Type will be stored as a varchar(64).)


=cut


=head2 Instance

Returns the current value of Instance.
(In the database, Instance is stored as int(11).)



=head2 SetInstance VALUE


Set Instance to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Instance will be stored as a int(11).)


=cut


=head2 Creator

Returns the current value of Creator.
(In the database, Creator is stored as int(11).)


=cut


=head2 Created

Returns the current value of Created.
(In the database, Created is stored as datetime.)


=cut


=head2 LastUpdatedBy

Returns the current value of LastUpdatedBy.
(In the database, LastUpdatedBy is stored as int(11).)


=cut


=head2 LastUpdated

Returns the current value of LastUpdated.
(In the database, LastUpdated is stored as datetime.)


=cut



sub _CoreAccessible {
    {

        id =>
		{read => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        Name =>
		{read => 1, write => 1, sql_type => 12, length => 200,  is_blob => 0,  is_numeric => 0,  type => 'varchar(200)', default => ''},
        Description =>
		{read => 1, write => 1, sql_type => 12, length => 255,  is_blob => 0,  is_numeric => 0,  type => 'varchar(255)', default => ''},
        Domain =>
		{read => 1, write => 1, sql_type => 12, length => 64,  is_blob => 0,  is_numeric => 0,  type => 'varchar(64)', default => ''},
        Type =>
		{read => 1, write => 1, sql_type => 12, length => 64,  is_blob => 0,  is_numeric => 0,  type => 'varchar(64)', default => ''},
        Instance =>
		{read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        Creator =>
		{read => 1, auto => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        Created =>
		{read => 1, auto => 1, sql_type => 11, length => 0,  is_blob => 0,  is_numeric => 0,  type => 'datetime', default => ''},
        LastUpdatedBy =>
		{read => 1, auto => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        LastUpdated =>
		{read => 1, auto => 1, sql_type => 11, length => 0,  is_blob => 0,  is_numeric => 0,  type => 'datetime', default => ''},

 }
};

RT::Base->_ImportOverlays();

1;

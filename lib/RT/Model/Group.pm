use warnings;
use strict;

package RT::Model::Group;

=head1 name

  RT::Model::Group - RT\'s group object

=head1 SYNOPSIS

use RT::Model::Group;
my $group = RT::Model::Group->new($CurrentUser);

=head1 description

An RT group object.

=head1 METHODS


=cut

use Jifty::DBI::Schema;
use base qw/RT::Record/;

use Jifty::DBI::Record schema {
    column name        => type is 'varchar(200)';
    column description => type is 'text';
    column domain      => type is 'varchar(64)';
    column type        => type is 'varchar(64)';
    column instance    => type is 'integer';

};

sub table {'Groups'}

use RT::Model::UserCollection;
use RT::Model::GroupMemberCollection;
use RT::Model::PrincipalCollection;
use RT::Model::ACECollection;

use vars qw/$RIGHTS/;

$RIGHTS = {
    AdminGroup => 'Modify group metadata or delete group',    # loc_pair
    AdminGroupMembership =>
        'Modify membership roster for this group',            # loc_pair
    DelegateRights =>
        "Delegate specific rights which have been granted to you.", # loc_pair
    ModifyOwnMembership => 'join or leave this group',              # loc_pair
    EditSavedSearches   => 'Edit saved searches for this group',    # loc_pair
    ShowSavedSearches   => 'Display saved searches for this group', # loc_pair
    SeeGroup            => 'Make this group visible to user',       # loc_pair
};

# Tell RT::Model::ACE that this sort of object can get acls granted
$RT::Model::ACE::OBJECT_TYPES{'RT::Model::Group'} = 1;

#

# TODO: This should be refactored out into an RT::Model::ACECollectionedobject or something
# stuff the rights into a hash of rights that can exist.

foreach my $right ( keys %{$RIGHTS} ) {
    $RT::Model::ACE::LOWERCASERIGHTNAMES{ lc $right } = $right;
}

=head2 available_rights

Returns a hash of available rights for this object. The keys are the right names and the values are a description of what the rights do

=cut

sub available_rights {
    my $self = shift;
    return ($RIGHTS);
}

# {{{ sub self_description

=head2 self_description

Returns a user-readable description of what this group is for and what it's named.

=cut

sub self_description {
    my $self = shift;
    if ( $self->domain eq 'ACLEquivalence' ) {
        my $user = RT::Model::Principal->new;
        $user->load( $self->instance );
        return _( "user %1", $user->object->name );
    } elsif ( $self->domain eq 'UserDefined' ) {
        return _( "group '%1'", $self->name );
    } elsif ( $self->domain eq 'Personal' ) {
        my $user = RT::Model::User->new;
        $user->load( $self->instance );
        return _( "personal group '%1' for user '%2'", $self->name,
            $user->name );
    } elsif ( $self->domain eq 'RT::System-Role' ) {
        return _( "system %1", $self->type );
    } elsif ( $self->domain eq 'RT::Model::Queue-Role' ) {
        my $queue = RT::Model::Queue->new;
        $queue->load( $self->instance );
        return _( "queue %1 %2", $queue->name, $self->type );
    } elsif ( $self->domain eq 'RT::Model::Ticket-Role' ) {
        return _( "ticket #%1 %2", $self->instance, $self->type );
    } elsif ( $self->domain eq 'SystemInternal' ) {
        return _( "system group '%1'", $self->type );
    } else {
        return _( "undescribed group %1", $self->id );
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
    my $self = shift;
    my $identifier = shift || return undef;

    #if it's an int, load by id. otherwise, load by name.
    if ( $identifier !~ /\D/ ) {
        $self->SUPER::load_by_id($identifier);
    } else {
        Jifty->log->fatal("Group -> Load called with a bogus argument: $identifier");
        return undef;
    }
}

# }}}

# {{{ sub loadUserDefinedGroup

=head2 LoadUserDefinedGroup name

Loads a system group from the database. The only argument is
the group's name.


=cut

sub load_user_defined_group {
    my $self       = shift;
    my $identifier = shift;

    if ( $identifier =~ /^\d+$/ ) {
        return $self->load_by_cols(
            domain => 'UserDefined',
            id     => $identifier,
        );
    } else {
        return $self->load_by_cols(
            domain => 'UserDefined',
            name   => $identifier,
        );
    }
}

# }}}

# {{{ sub load_acl_equivalence_group

=head2 load_acl_equivalence_group  PRINCIPAL

Loads a user's acl equivalence group. Takes a principal object.
ACL equivalnce groups are used to simplify the acl system. Each user
has one group that only he is a member of. rights granted to the user
are actually granted to that group. This greatly simplifies ACL checks.
While this results in a somewhat more complex setup when creating users
and granting ACLs, it _greatly_ simplifies acl checks.



=cut

sub load_acl_equivalence_group {
    my $self  = shift;
    my $princ = shift;

    $self->load_by_cols(
        "domain"   => 'ACLEquivalence',
        "type"     => 'UserEquiv',
        "instance" => $princ->id
    );
}

# }}}

# {{{ sub loadPersonalGroup

=head2 LoadPersonalGroup {name => name, User => USERID}

Loads a personal group from the database. 

=cut

sub load_personal_group {
    my $self = shift;
    my %args = (
        name => undef,
        user => undef,
        @_
    );

    $self->load_by_cols(
        "domain"   => 'Personal',
        "instance" => $args{'user'},
        "type"     => '',
        "name"     => $args{'name'}
    );
}

# }}}

# {{{ sub load_system_internal_group

=head2 load_system_internal_group name

Loads a Pseudo group from the database. The only argument is
the group's name.


=cut

sub load_system_internal_group {
    my $self       = shift;
    my $identifier = shift;

    $self->load_by_cols(
        "domain" => 'SystemInternal',
        "type"   => $identifier
    );
}

# }}}

# {{{ sub load_ticket_role_group

=head2 load_ticketRoleGroup  { Ticket => TICKET_ID, type => TYPE }

Loads a ticket group from the database. 

Takes a param hash with 2 parameters:

    Ticket is the TicketId we're curious about
    type is the type of Group we're trying to load: 
        requestor, cc, admin_cc, owner

=cut

sub load_ticket_role_group {
    my $self = shift;
    my %args = (
        ticket => '0',
        type   => undef,
        @_
    );
    $self->load_by_cols(
        domain   => 'RT::Model::Ticket-Role',
        instance => $args{'ticket'},
        type     => $args{'type'}
    );

    Carp::confess("AAA NO ROLE") unless $self->id;
}

# }}}

# {{{ sub loadQueueRoleGroup

=head2 LoadQueueRoleGroup  { queue => Queue_ID, type => TYPE }

Loads a queue group from the database. 

Takes a param hash with 2 parameters:

    queue is the QueueId we're curious about
    type is the type of Group we're trying to load: 
        requestor, cc, admin_cc, owner

=cut

sub load_queue_role_group {
    my $self = shift;
    my %args = (
        queue => undef,
        type  => undef,
        @_
    );
    $self->load_by_cols(
        domain   => 'RT::Model::Queue-Role',
        instance => $args{'queue'},
        type     => $args{'type'}
    );
}

# }}}

# {{{ sub loadSystemRoleGroup

=head2 LoadSystemRoleGroup  type

Loads a System group from the database. 

Takes a single param: type

    type is the type of Group we're trying to load: 
        requestor, cc, admin_cc, owner

=cut

sub load_system_role_group {
    my $self = shift;
    my $type = shift;
    $self->load_by_cols(
        domain => 'RT::System-Role',
        type   => $type
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
    Jifty->log->fatal(
        "Someone called RT::Model::Group->create. this method does not exist. someone's being evil"
    );
    return ( 0, _('Permission Denied') );
}

# }}}

# {{{ sub _create

=head2 _create

Takes a paramhash with named arguments: name, description.

Returns a tuple of (Id, Message).  If id is 0, the create failed

=cut

sub _create {
    my $self = shift;
    my %args = (
        name                => undef,
        description         => undef,
        domain              => undef,
        type                => undef,
        instance            => '0',
        inside_transaction   => undef,
        _record_transaction => 1,
        @_
    );
    Jifty->handle->begin_transaction() unless ( $args{'inside_transaction'} );

    # Groups deal with principal ids, rather than user ids.
    # When creating this group, set up a principal id for it.
    my $principal = RT::Model::Principal->new;
    my ( $principal_id, $msg ) = $principal->create(
        principal_type => 'Group',
        object_id      => '0'
    );
    $principal->__set( column => 'object_id', value => $principal_id );

    $self->SUPER::create(
        id          => $principal_id,
        name        => $args{'name'},
        description => $args{'description'},
        type        => $args{'type'},
        domain      => $args{'domain'},
        instance    => ( $args{'instance'} || '0' )
    );
    my $id = $self->id;
    unless ($id) {
        return ( 0, _('Could not create group') );
    }

    # If we couldn't create a principal Id, get the fuck out.
    unless ($principal_id) {
        Jifty->handle->rollback() unless ( $args{'inside_transaction'} );
        Jifty->log->fatal(
            "Couldn't create a Principal on new user create. Strange things are afoot at the circle K"
        );
        return ( 0, _('Could not create group') );
    }

    # Now we make the group a member of itself as a cached group member
    # this needs to exist so that group ACL checks don't fall over.
    # you're checking CachedGroupMembers to see if the principal in question
    # is a member of the principal the rights have been granted too

# in the ordinary case, this would fail badly because it would recurse and add all the members of this group as
# cached members. thankfully, we're creating the group now...so it has no members.
    my $cgm = RT::Model::CachedGroupMember->new;
    $cgm->create(
        group           => $self->principal_object,
        member          => $self->principal_object,
        immediate_parent => $self->principal_object
    );

    if ( $args{'_record_transaction'} ) {
        $self->_new_transaction( type => "Create" );
    }

    Jifty->handle->commit() unless ( $args{'inside_transaction'} );

    return ( $id, _("Group Created") );
}

# }}}

# {{{ create_userDefinedGroup

=head2 create_userDefinedGroup { name => "name", description => "description"}

A helper subroutine which creates a system group 

Returns a tuple of (Id, Message).  If id is 0, the create failed

=cut

sub create_user_defined_group {
    my $self = shift;

    unless ( $self->current_user_has_right('AdminGroup') ) {
        Jifty->log->warn( $self->current_user->name
                . " Tried to create a group without permission." );
        return ( 0, _('Permission Denied') );
    }

    return (
        $self->_create(
            domain   => 'UserDefined',
            type     => '',
            instance => '',
            @_
        )
    );
}

# }}}

# {{{ ccreateacl_equivalence_group

=head2 _createacl_equivalence_group { Principal }

A helper subroutine which creates a group containing only 
an individual user. This gets used by the ACL system to check rights.
Yes, it denormalizes the data, but that's ok, as we totally win on performance.

Returns a tuple of (Id, Message).  If id is 0, the create failed

=cut

sub _createacl_equivalence_group {
    my $self  = shift;
    my $princ = shift;
    my ( $id, $msg ) = $self->_create(
        domain            => 'ACLEquivalence',
        type              => 'UserEquiv',
        name              => 'User ' . $princ->object->id,
        description       => 'ACL equiv. for user ' . $princ->object->id,
        instance          => $princ->id,
        inside_transaction => 1
    );

    unless ($id) {
        Jifty->log->fatal("Couldn't create ACL equivalence group -- $msg");
        return undef;
    }

    # We use stashuser so we don't get transactions inside transactions
    # and so we bypass all sorts of cruft we don't need
    my $aclstash = RT::Model::GroupMember->new;
    my ( $stash_id, $add_msg ) = $aclstash->_stash_user(
        group  => $self->principal_object,
        member => $princ
    );

    unless ($stash_id) {
        Jifty->log->fatal(
            "Couldn't add the user to his own acl equivalence group:"
                . $add_msg );

        # We call super delete so we don't get acl checked.
        $self->SUPER::delete();
        return (undef);
    }
    return ($id);
}

# }}}

# {{{ CreatePersonalGroup

=head2 CreatePersonalGroup { principal_id => PRINCIPAL_ID, name => "name", description => "description"}

A helper subroutine which creates a personal group. Generally,
personal groups are used for ACL delegation and adding to ticket roles
principal_id defaults to the current user's principal id.

Returns a tuple of (Id, Message).  If id is 0, the create failed

=cut

sub create_personal_group {
    my $self = shift;
    my %args = (
        name         => undef,
        description  => undef,
        principal_id => $self->current_user->id,
        @_
    );
    if ( $self->current_user->id == $args{'principal_id'} ) {

        unless ( $self->current_user_has_right('AdminOwnPersonalGroups') ) {
            Jifty->log->warn( $self->current_user->name
                    . " Tried to create a group without permission." );
            return ( 0, _('Permission Denied') );
        }

    } else {
        unless ( $self->current_user_has_right('AdminAllPersonalGroups') ) {
            Jifty->log->warn( $self->current_user->name
                    . " Tried to create a group without permission." );
            return ( 0, _('Permission Denied') );
        }

    }

    return (
        $self->_create(
            domain      => 'Personal',
            type        => '',
            instance    => $args{'principal_id'},
            name        => $args{'name'},
            description => $args{'description'}
        )
    );
}

# }}}

# {{{ CreateRoleGroup

=head2 CreateRoleGroup { domain => DOMAIN, type =>  TYPE, instance => ID }

A helper subroutine which creates a  ticket group. (What RT 2.0 called Ticket watchers)
type is one of ( "requestor" || "cc" || "admin_cc" || "owner") 
domain is one of (RT::Model::Ticket-Role || RT::Model::Queue-Role || RT::System-Role)
instance is the id of the ticket or queue in question

This routine expects to be called from {Ticket||Queue}->create_ticket_groups _inside of a transaction_

Returns a tuple of (Id, Message).  If id is 0, the create failed

=cut

sub create_role_group {
    my $self = shift;
    my %args = (
        instance => undef,
        type     => undef,
        domain   => undef,
        @_
    );
    unless ( $args{'type'} =~ /^(?:cc|admin_cc|requestor|owner)$/ ) {
        return ( 0, _("Invalid Group type") );
    }

    return (
        $self->_create(
            domain            => $args{'domain'},
            instance          => $args{'instance'},
            type              => $args{'type'},
            inside_transaction => 1
        )
    );
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

    Jifty->log->fatal(
        "Deleting groups violates referential integrity until we go through and fix this"
    );

    # TODO XXX

    # Remove the principal object
    # Remove this group from anything it's a member of.
    # Remove all cached members of this group
    # Remove any rights granted to this group
    # remove any rights delegated by way of this group

    return ( $self->SUPER::delete(@_) );
}

# }}}

=head2 Setdisabled BOOL

If passed a positive value, this group will be disabled. No rights it commutes or grants will be honored.
It will not appear in most group listings.

This routine finds all the cached group members that are members of this group  (recursively) and disables them.

=cut 

# }}}

sub set_disabled {
    my $self = shift;
    my $val  = shift;
    if ( $self->domain eq 'Personal' ) {
        if ( $self->current_user->id == $self->instance ) {
            unless ( $self->current_user_has_right('AdminOwnPersonalGroups') )
            {
                return ( 0, _('Permission Denied') );
            }
        } else {
            unless ( $self->current_user_has_right('AdminAllPersonalGroups') )
            {
                return ( 0, _('Permission Denied') );
            }
        }
    } else {
        unless ( $self->current_user_has_right('AdminGroup') ) {
            return ( 0, _('Permission Denied') );
        }
    }
    Jifty->handle->begin_transaction();
    $self->principal_object->set_disabled($val);

    # Find all occurrences of this member as a member of this group
    # in the cache and nuke them, recursively.

    # The following code will delete all Cached Group members
    # where this member's group is _not_ the primary group
    # (Ie if we're deleting C as a member of B, and B happens to be
    # a member of A, will delete C as a member of A without touching
    # C as a member of B

    my $cached_submembers = RT::Model::CachedGroupMemberCollection->new;

    $cached_submembers->limit(
        column   => 'immediate_parent_id',
        operator => '=',
        value    => $self->id
    );

#Clear the key cache. TODO someday we may want to just clear a little bit of the keycache space.
# TODO what about the groups key cache?
    RT::Model::Principal->invalidate_acl_cache();

    while ( my $item = $cached_submembers->next() ) {
        my $del_err = $item->set_disabled($val);
        unless ($del_err) {
            Jifty->handle->rollback();
            Jifty->log->warn(
                "Couldn't disable cached group submember " . $item->id );
            return (undef);
        }
    }

    Jifty->handle->commit();
    return ( 1, _("Succeeded") );

}

# }}}

sub disabled {
    my $self = shift;
    $self->principal_object->disabled(@_);
}

# {{{ DeepMembersObj

=head2 DeepMembersObj

Returns an RT::Model::CachedGroupMemberCollection object of this group's members,
including all members of subgroups.

=cut

sub deep_members_obj {
    my $self        = shift;
    my $members_obj = RT::Model::CachedGroupMemberCollection->new;

    #If we don't have rights, don't include any results
    # TODO XXX  WHY IS THERE NO ACL CHECK HERE?
    $members_obj->limit_to_members_of_group( $self->id );

    return ($members_obj);

}

# }}}

# {{{ members_obj

=head2 members_obj

Returns an RT::Model::GroupMemberCollection object of this group's direct members.

=cut

sub members_obj {
    my $self        = shift;
    my $members_obj = RT::Model::GroupMemberCollection->new(
        current_user => $self->current_user );

    #If we don't have rights, don't include any results
    # TODO XXX  WHY IS THERE NO ACL CHECK HERE?
    $members_obj->limit_to_members_of_group( $self->id );

    return ($members_obj);

}

# }}}

# {{{ GroupMembersObj

=head2 GroupMembersObj [recursively => 1]

Returns an L<RT::Model::GroupCollection> object of this group's members.
By default returns groups including all subgroups, but
could be changed with C<recursively> named argument.

B<Note> that groups are not filtered by type and result
may contain as well system groups, personal and other.

=cut

sub group_members_obj {
    my $self = shift;
    my %args = ( recursively => 1, @_ );

    my $groups = RT::Model::GroupCollection->new;
    my $members_table
        = $args{'recursively'} ? 'CachedGroupMembers' : 'GroupMembers';

    my $members_alias = $groups->new_alias($members_table);
    $groups->join(
        alias1  => $members_alias,
        column1 => 'member_id',
        alias2  => $groups->principals_alias,
        column2 => 'id',
    );
    $groups->limit(
        alias  => $members_alias,
        column => 'group_id',
        value  => $self->id,
    );
    $groups->limit(
        alias  => $members_alias,
        column => 'disabled',
        value  => 0,
    ) if $args{'recursively'};

    return $groups;
}

# }}}

# {{{ UserMembersObj

=head2 UserMembersObj

Returns an L<RT::Model::UserCollection> object of this group's members, by default
returns users including all members of subgroups, but could be
changed with C<recursively> named argument.

=cut

sub user_members_obj {
    my $self = shift;
    my %args = ( recursively => 1, @_ );

    #If we don't have rights, don't include any results
    # TODO XXX  WHY IS THERE NO ACL CHECK HERE?

    my $members_table
        = $args{'recursively'} ? 'CachedGroupMembers' : 'GroupMembers';

    my $users         = RT::Model::UserCollection->new;
    my $members_alias = $users->new_alias($members_table);
    $users->join(
        alias1  => $members_alias,
        column1 => 'member_id',
        alias2  => $users->principals_alias,
        column2 => 'id',
    );
    $users->limit(
        alias  => $members_alias,
        column => 'group_id',
        value  => $self->id,
    );
    $users->limit(
        alias  => $members_alias,
        column => 'disabled',
        value  => 0,
    ) if $args{'recursively'};

    return ($users);
}

# }}}

# {{{ member_emails

=head2 member_emails

Returns an array of the email addresses of all of this group's members


=cut

sub member_emails {
    my $self = shift;

    my %addresses;
    my $members = $self->user_members_obj();
    while ( my $member = $members->next ) {
        $addresses{ $member->email } = 1;
    }
    return ( sort keys %addresses );
}

# }}}

# {{{ member_emails_as_string

=head2 member_emails_as_string

Returns a comma delimited string of the email addresses of all users 
who are members of this group.

=cut

sub member_emails_as_string {
    my $self = shift;
    return ( join( ', ', $self->member_emails ) );
}

# }}}

# {{{ add_member

=head2 add_member PRINCIPAL_ID

add_member adds a principal to this group.  It takes a single principal id.
Returns a two value array. the first value is true on successful 
addition or 0 on failure.  The second value is a textual status msg.

=cut

sub add_member {
    my $self       = shift;
    my $new_member = shift;

    if ( $self->domain eq 'Personal' ) {
        if ( $self->current_user->id == $self->instance ) {
            unless ( $self->current_user_has_right('AdminOwnPersonalGroups') )
            {
                return ( 0, _('Permission Denied') );
            }
        } else {
            unless ( $self->current_user_has_right('AdminAllPersonalGroups') )
            {
                return ( 0, _('Permission Denied') );
            }
        }
    }

    else {

        # We should only allow membership changes if the user has the right
        # to modify group membership or the user is the principal in question
        # and the user has the right to modify his own membership
        unless (
            (      $new_member == $self->current_user->user_object->id
                && $self->current_user_has_right('ModifyOwnMembership')
            )
            || $self->current_user_has_right('AdminGroupMembership')
            )
        {

            #User has no permission to be doing this
            return ( 0, _("Permission Denied") );
        }

    }
    $self->_add_member( principal_id => $new_member );
}

# A helper subroutine for add_member that bypasses the ACL checks
# this should _ONLY_ ever be called from Ticket/Queue AddWatcher
# when we want to deal with groups according to queue rights
# In the dim future, this will all get factored out and life
# will get better

# takes a paramhash of { principal_id => undef, inside_transaction }

sub _add_member {
    my $self = shift;
    my %args = (
        principal_id      => undef,
        inside_transaction => undef,
        @_
    );
    my $new_member = $args{'principal_id'};
    unless ( $self->id ) {
        Jifty->log->fatal(
            "Attempting to add a member to a group which wasn't loaded. 'oops'"
        );
        return ( 0, _("Group not found") );
    }

    unless ( $new_member =~ /^\d+$/ ) {
        Jifty->log->fatal(
            "_add_member called with a parameter that's not an integer.");
    }

    my $new_member_obj = RT::Model::Principal->new;
    $new_member_obj->load($new_member);

    unless ( $new_member_obj->id ) {
        Jifty->log->debug("Couldn't find that principal");
        return ( 0, _("Couldn't find that principal") );
    }

    if ( $self->has_member($new_member_obj) ) {

        #User is already a member of this group. no need to add it
        return ( 0, _("Group already has member") );
    }
    if ($new_member_obj->is_group
        && $new_member_obj->object->has_member_recursively(
            $self->principal_object
        )
        )
    {

        #This group can't be made to be a member of itself
        return ( 0, _("Groups can't be members of their members") );
    }

    my $member_object = RT::Model::GroupMember->new;
    my $id            = $member_object->create(
        member            => $new_member_obj,
        group             => $self->principal_object,
        inside_transaction => $args{'inside_transaction'}
    );
    if ($id) {
        return ( 1, _("Member added") );
    } else {
        return ( 0, _("Couldn't add member to group") );
    }
}

# }}}

# {{{ has_member

=head2 has_member RT::Model::Principal|id

Takes an L<RT::Model::Principal> object or its id returns a GroupMember id if that user is a 
member of this group.
Returns undef if the user isn't a member of the group or if the current
user doesn't have permission to find out. Arguably, it should differentiate
between ACL failure and non membership.

=cut

sub has_member {
    my $self      = shift;
    my $principal = shift;

    my $id;
    if ( UNIVERSAL::isa( $principal, 'RT::Model::Principal' ) ) {
        $id = $principal->id;
    } elsif ( $principal =~ /^\d+$/ ) {
        $id = $principal;
    } else {
        Carp::cluck;
        Jifty->log->error(
                  "Group::has_member was called with an argument that"
                . " isn't an RT::Model::Principal or id. It's $principal" );
        return (undef);
    }
    return undef unless $id;

    my $member_obj = RT::Model::GroupMember->new;
    $member_obj->load_by_cols(
        member_id => $id,
        group_id  => $self->id
    );

    if ( my $member_id = $member_obj->id ) {
        return $member_id;
    } else {
        return (undef);
    }
}

# }}}

# {{{ has_member_recursively

=head2 has_member_recursively RT::Model::Principal|id

Takes an L<RT::Model::Principal> object or its id and returns true if that user is a member of 
this group.
Returns undef if the user isn't a member of the group or if the current
user doesn't have permission to find out. Arguably, it should differentiate
between ACL failure and non membership.

=cut

sub has_member_recursively {
    my $self = shift;
    my $principal = shift || '';

    my $id;
    if ( UNIVERSAL::isa( $principal, 'RT::Model::Principal' ) ) {
        $id = $principal->id;
    } elsif ( $principal =~ /^\d+$/ ) {
        $id = $principal;
    } else {
        Jifty->log->error(
            "Group::has_member_recursively was called with an argument that"
                . " isn't an RT::Model::Principal or id. It's $principal" );
        return (undef);
    }
    return undef unless $id;

    my $member_obj = RT::Model::CachedGroupMember->new;
    $member_obj->load_by_cols(
        member_id => $id,
        group_id  => $self->id
    );

    if ( my $member_id = $member_obj->id ) {
        return $member_id;
    } else {
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
    my $self      = shift;
    my $member_id = shift;

    # We should only allow membership changes if the user has the right
    # to modify group membership or the user is the principal in question
    # and the user has the right to modify his own membership

    if ( $self->domain eq 'Personal' ) {
        if ( $self->current_user->id == $self->instance ) {
            unless ( $self->current_user_has_right('AdminOwnPersonalGroups') )
            {
                return ( 0, _('Permission Denied') );
            }
        } else {
            unless ( $self->current_user_has_right('AdminAllPersonalGroups') )
            {
                return ( 0, _('Permission Denied') );
            }
        }
    } else {
        unless (
            (   ( $member_id == $self->current_user->id )
                && $self->current_user_has_right('ModifyOwnMembership')
            )
            || $self->current_user_has_right('AdminGroupMembership')
            )
        {

            #User has no permission to be doing this
            return ( 0, _("Permission Denied") );
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
    my $self      = shift;
    my $member_id = shift;

    my $member_obj = RT::Model::GroupMember->new;

    $member_obj->load_by_cols(
        member_id => $member_id,
        group_id  => $self->id
    );

    #If we couldn't load it, return undef.
    unless ( $member_obj->id() ) {
        Jifty->log->debug("Group has no member with that id");
        return ( 0, _("Group has no such member") );
    }

    #Now that we've checked ACLs and sanity, delete the groupmember
    my $val = $member_obj->delete();

    if ($val) {
        return ( $val, _("Member deleted") );
    } else {
        Jifty->log->debug(
            "Failed to delete group " . $self->id . " member " . $member_id );
        return ( 0, _("Member not deleted") );
    }
}

# }}}

# {{{ sub _cleanup_invalid_delegations

=head2 _cleanup_invalid_delegations { inside_transaction => undef }

Revokes all ACE entries delegated by members of this group which are
inconsistent with their current delegation rights.  Does not perform
permission checks.  Should only ever be called from inside the RT
library.

If called from inside a transaction, specify a true value for the
inside_transaction parameter.

Returns a true value if the deletion succeeded; returns a false value
and logs an internal error if the deletion fails (should not happen).

=cut

# XXX Currently there is a _cleanup_invalid_delegations method in both
# RT::Model::User and RT::Model::Group.  If the recursive cleanup call for groups is
# ever unrolled and merged, this code will probably want to be
# factored out into RT::Model::Principal.

sub _cleanup_invalid_delegations {
    my $self = shift;
    my %args = (
        inside_transaction => undef,
        @_
    );

    unless ( $self->id ) {
        Jifty->log->warn("Group not loaded.");
        return (undef);
    }

    my $in_trans = $args{inside_transaction};

# TODO: Can this be unrolled such that the number of DB queries is constant rather than linear in exploded group size?
    my $members = $self->deep_members_obj();
    $members->limit_to_users();
    Jifty->handle->begin_transaction() unless $in_trans;
    while ( my $member = $members->next() ) {
        my $ret = $member->member_obj->_cleanup_invalid_delegations(
            inside_transaction => 1,
            object            => $args{object}
        );
        unless ($ret) {
            Jifty->handle->rollback() unless $in_trans;
            return (undef);
        }
    }
    Jifty->handle->commit() unless $in_trans;
    return (1);
}

# }}}

# {{{ ACL Related routines

# {{{ sub _set
sub _set {
    my $self = shift;
    my %args = (
        column             => undef,
        value              => undef,
        transaction_type    => 'Set',
        record_transaction => 1,
        @_
    );

    if ( $self->domain eq 'Personal' ) {
        if ( $self->current_user->id == $self->instance ) {
            unless ( $self->current_user_has_right('AdminOwnPersonalGroups') )
            {
                return ( 0, _('Permission Denied') );
            }
        } else {
            unless ( $self->current_user_has_right('AdminAllPersonalGroups') )
            {
                return ( 0, _('Permission Denied') );
            }
        }
    } else {
        unless ( $self->current_user_has_right('AdminGroup') ) {
            return ( 0, _('Permission Denied') );
        }
    }

    my $Old = $self->SUPER::_value( $args{'column'} );

    my ( $ret, $msg ) = $self->SUPER::_set(
        column => $args{'column'},
        value  => $args{'value'}
    );

    #If we can't actually set the field to the value, don't record
    # a transaction. instead, get out of here.
    if ( $ret == 0 ) { return ( 0, $msg ); }

    if ( $args{'record_transaction'} == 1 ) {

        my ( $Trans, $Msg, $TransObj ) = $self->_new_transaction(
            type      => $args{'transaction_type'},
            field     => $args{'column'},
            new_value => $args{'value'},
            old_value => $Old,
            time_taken => $args{'time_taken'},
        );
        return ( $Trans, scalar $TransObj->description );
    } else {
        return ( $ret, $msg );
    }
}

# }}}

=head2 current_user_has_right RIGHTNAME

Returns true if the current user has the specified right for this group.


    TODO: we don't deal with membership visibility yet

=cut

sub current_user_has_right {
    my $self  = shift;
    my $right = shift;

    if ($self->id
        && $self->current_user->has_right(
            object => $self,
            right  => $right
        )
        )
    {
        return (1);
    } elsif (
        $self->current_user->has_right(
            object => RT->system,
            right  => $right
        )
        )
    {
        return (1);
    } else {
        return (undef);
    }

}

# }}}

# {{{ Principal related routines

=head2 principal_object

Returns the principal object for this user. returns an empty RT::Model::Principal
if there's no principal object matching this user. 
The response is cached. principal_object should never ever change.


=cut

sub principal_object {
    my $self = shift;
    unless ($self->{'principal_object'} && $self->{'principal_object'}->id) {
        $self->{'principal_object'} = RT::Model::Principal->new;
        $self->{'principal_object'}->load_by_cols(
            id      => $self->id,
            principal_type => 'Group'
        );
    }
    return $self->{'principal_object'};
}

=head2 principal_id  

Returns this user's principal_id

=cut

sub principal_id {
    my $self = shift;
    return $self->id;
}

# }}}

sub basic_columns {
    ( [ name => 'name' ], [ description => 'description' ], );
}

1;

=head1 AUTHOR

Jesse Vincent, jesse@bestpractical.com

=head1 SEE ALSO

RT


# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2007 Best Practical Solutions, LLC
#                                          <jesse@bestpractical.com>
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
# http://www.gnu.org/copyleft/gpl.html.
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
use warnings;
use strict;

package RT::Model::Group;

=head1 name

  RT::Model::Group - RT\'s group object

=head1 SYNOPSIS

use RT::Model::Group;
my $group = RT::Model::Group->new( current_user => $CurrentUser );

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
    AdminGroup           => 'Modify group metadata or delete group',                       # loc_pair
    AdminGroupMembership => 'Modify membership roster for this group',                     # loc_pair
    ModifyOwnMembership  => 'join or leave this group',                                    # loc_pair
    EditSavedSearches    => 'Edit saved searches for this group',                          # loc_pair
    ShowSavedSearches    => 'Display saved searches for this group',                       # loc_pair
    SeeGroup             => 'Make this group visible to user',                             # loc_pair

    SeeGroupDashboard    => 'View dashboards for this group',        #loc_pair
    CreateGroupDashboard => 'Create dashboards for this group',      #loc_pair
    ModifyGroupDashboard => 'Modify dashboards for this group',      #loc_pair
    DeleteGroupDashboard => 'Delete dashboards for this group',      #loc_pair
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
        return _( "personal group '%1' for user '%2'", $self->name, $user->name );
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



=head2 load ID

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



=head2 load_user_defined_group name

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



=head2 load_acl_equivalence_group PRINCIPAL

Loads a user's acl equivalence group. Takes a principal object or its ID.
ACL equivalnce groups are used to simplify the acl system. Each user
has one group that only he is a member of. Rights granted to the user
are actually granted to that group. This greatly simplifies ACL checks.
While this results in a somewhat more complex setup when creating users
and granting ACLs, it _greatly_ simplifies acl checks.

=cut

sub load_acl_equivalence_group {
    my $self      = shift;
    my $principal = shift;
    $principal = $principal->id if ref $principal;

    return $self->load_by_cols(
        domain   => 'ACLEquivalence',
        type     => 'UserEquiv',
        instance => $principal,
    );
}



=head2 load_personal_group {name => name, User => USERID}

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


=head2 load_system_internal_group name

Loads a Pseudo group from the database. The only argument is
the group's name.


=cut

sub load_system_internal_group {
    my $self       = shift;
    my $identifier = shift;

    return $self->load_by_cols(
        domain => 'SystemInternal',
        type   => $identifier,
    );
}


=head2 load_role_group { object => OBJ, domain => DOMAIN, type => TYPE, instance => ID }

Loads a role group of an object (ticket, queue, system or other) from the database. 
Takes the following arguments:

=over 4

=item type - the name of the role, such as "requestor", "cc", "admin_cc", "owner" or other.

=item object - any object that may have roles, used to calculate domain and instance.

=item domain - if object is not provided. Valid values are 'RT::Model::Ticket',
'RT::Model::Queue' or 'RT::System'.

=item instance - if object is not provided. Is the id of the ticket or queue in question.

=back

=cut

sub load_role_group {
    my $self = shift;
    my %args = (
        domain   => undef,
        instance => undef,
        type     => undef,
        @_
    );
    $self->_object_to_domain_instance(\%args);

    $self->load_by_cols(
        domain   => $args{'domain'},
        instance => $args{'instance'},
        type     => $args{'type'},
    );
}

=head2 create

You need to specify what sort of group you're creating by calling one of the other
Create_____ routines.

=cut

sub create {
    my $self = shift;
    Jifty->log->fatal( "Someone called RT::Model::Group->create. this method does not exist. someone's being evil" );
    return ( 0, _('Permission Denied') );
}



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
        _record_transaction => 1,
        @_
    );
    my $inside_transaction = Jifty->handle->transaction_depth;
    Jifty->handle->begin_transaction() unless $inside_transaction;

    # Groups deal with principal ids, rather than user ids.
    # When creating this group, set up a principal id for it.
    my $principal = RT::Model::Principal->new;
    my ( $principal_id, $msg ) = $principal->create(
        type => 'Group',
    );

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
        Jifty->handle->rollback() unless $inside_transaction;
        return ( 0, _('Could not create group') );
    }

    # If we couldn't create a principal Id, get the fuck out.
    unless ($principal_id) {
        Jifty->handle->rollback() unless $inside_transaction;
        Jifty->log->fatal( "Couldn't create a Principal on new user create. Strange things are afoot at the circle K" );
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
        group            => $self->principal,
        member           => $self->principal,
        immediate_parent => $self->principal
    );

    if ( $args{'_record_transaction'} ) {
        $self->_new_transaction( type => "create" );
    }

    Jifty->handle->commit() unless $inside_transaction;

    return ( $id, _("Group Created") );
}



=head2 create_user_defined_group { name => "name", description => "description"}

A helper subroutine which creates a system group 

Returns a tuple of (Id, Message).  If id is 0, the create failed

=cut

sub create_user_defined_group {
    my $self = shift;

    unless ( $self->current_user_has_right('AdminGroup') ) {
        Jifty->log->warn( $self->current_user->name . " Tried to create a group without permission." );
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
        domain             => 'ACLEquivalence',
        type               => 'UserEquiv',
        name               => 'User ' . $princ->object->id,
        description        => 'ACL equiv. for user ' . $princ->object->id,
        instance           => $princ->id,
    );

    unless ($id) {
        Jifty->log->fatal("Couldn't create ACL equivalence group -- $msg");
        return undef;
    }

    # We use stashuser so we don't get transactions inside transactions
    # and so we bypass all sorts of cruft we don't need
    my $aclstash = RT::Model::GroupMember->new;
    my ( $stash_id, $add_msg ) = $aclstash->_stash_user(
        group  => $self->principal,
        member => $princ
    );

    unless ($stash_id) {
        Jifty->log->fatal( "Couldn't add the user to his own acl equivalence group:" . $add_msg );

        # We call super delete so we don't get acl checked.
        $self->SUPER::delete();
        return (undef);
    }
    return ($id);
}



=head2 create_personal_group { principal_id => PRINCIPAL_ID, name => "name", description => "description"}

A helper subroutine which creates a personal group.

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
            Jifty->log->warn( $self->current_user->name . " Tried to create a group without permission." );
            return ( 0, _('Permission Denied') );
        }

    } else {
        unless ( $self->current_user_has_right('AdminAllPersonalGroups') ) {
            Jifty->log->warn( $self->current_user->name . " Tried to create a group without permission." );
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



=head2 create_role_group { object => OBJ, domain => DOMAIN, type => TYPE, instance => ID }

A helper subroutine which creates a role group. Takes the following arguments:

=over 4

=item type - the name of the role, such as "requestor", "cc", "admin_cc", "owner" or other.

=item object - any object that may have roles, used to calculate domain and instance.

=item domain - if object is not provided. Valid values are 'RT::Model::Ticket-Role',
'RT::Model::Queue-Role' or 'RT::System-Role'

=item instance - if object is not provided. Is the id of the ticket or queue in question.

=back

Group created if it doesn't exist, otherwise it's just loaded.

Returns a tuple of (Id, Message).  If id is a false value, the create failed

=cut

sub create_role_group {
    my $self = shift;
    my %args = (
        domain   => undef,
        instance => undef,
        type     => undef,
        @_
    );
    $self->_object_to_domain_instance(\%args);

    $self->load_by_cols(
        domain   => $args{'domain'},
        instance => $args{'instance'},
        type     => $args{'type'},
    );
    if ( my $id = $self->id ) {
        return ($id, "Found existing role group");
    }

    return $self->_create(
        domain   => $args{'domain'},
        instance => $args{'instance'},
        type     => $args{'type'},
    );
}

sub _object_to_domain_instance {
    my $self = shift;
    my $args = shift;
    my $type = shift || '-Role';
    if ( my $obj = delete $args->{'object'} ) {
        $args->{'domain'} = ref( $obj ) . $type;
        $args->{'instance'} = $obj->id;
    }
}



=head2 delete

Delete this object

=cut

sub delete {
    my $self = shift;

    unless ( $self->current_user_has_right('AdminGroup') ) {
        return ( 0, 'Permission Denied' );
    }

    Jifty->log->fatal( "Deleting groups violates referential integrity until we go through and fix this" );

    # TODO XXX

    # Remove the principal object
    # Remove this group from anything it's a member of.
    # Remove all cached members of this group
    # Remove any rights granted to this group

    return ( $self->SUPER::delete(@_) );
}


=head2 setdisabled BOOL

If passed a positive value, this group will be disabled. No rights it commutes or grants will be honored.
It will not appear in most group listings.

This routine finds all the cached group members that are members of this group  (recursively) and disables them.

=cut 


sub set_disabled {
    my $self = shift;
    my $val  = shift;
    if ( $self->domain eq 'Personal' ) {
        if ( $self->current_user->id == $self->instance ) {
            unless ( $self->current_user_has_right('AdminOwnPersonalGroups') ) {
                return ( 0, _('Permission Denied') );
            }
        } else {
            unless ( $self->current_user_has_right('AdminAllPersonalGroups') ) {
                return ( 0, _('Permission Denied') );
            }
        }
    } else {
        unless ( $self->current_user_has_right('AdminGroup') ) {
            return ( 0, _('Permission Denied') );
        }
    }
    Jifty->handle->begin_transaction();
    $self->principal->set_disabled($val);

    # Find all occurrences of this member as a member of this group
    # in the cache and nuke them, recursively.

    # The following code will delete all Cached Group members
    # where this member's group is _not_ the primary group
    # (Ie if we're deleting C as a member of B, and B happens to be
    # a member of A, will delete C as a member of A without touching
    # C as a member of B

    my $cached_submembers = RT::Model::CachedGroupMemberCollection->new;

    $cached_submembers->limit(
        column   => 'immediate_parent',
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
            Jifty->log->warn( "Couldn't disable cached group submember " . $item->id );
            return (undef);
        }
    }

    Jifty->handle->commit();
    if ( $val == 1 ) {
        return ( 1, _("Group disabled") );
    }
    else {
        return ( 1, _("Group enabled") );
    }

}


sub disabled {
    my $self = shift;
    $self->principal->disabled(@_);
}


=head2 members

Returns either an L<RT::Model::GroupMemberCollection> or L<RT::Model::CachedGroupMemberCollection>
object depending on 'recursively' argument of this group's members.

=cut

sub members {
    my $self = shift;
    my %args = ( recursively => 0, @_ );

    my $class = $args{'recursively'}
        ? 'RT::Model::CachedGroupMemberCollection'
        : 'RT::Model::GroupMemberCollection';

    #If we don't have rights, don't include any results
    # TODO XXX  WHY IS THERE NO ACL CHECK HERE?

    my $res = $class->new( current_user => $self->current_user );
    $res->limit_to_members_of_group( $self->id );

    return $res;
}


=head2 group_members [recursively => 1]

Returns an L<RT::Model::GroupCollection> object of this group's members.
By default returns groups including all subgroups, but
could be changed with C<recursively> named argument.

B<Note> that groups are not filtered by type and result
may contain as well system groups, personal and other.

=cut

sub group_members {
    my $self = shift;
    my %args = ( recursively => 1, @_ );

    my $groups = RT::Model::GroupCollection->new;
    my $members_table = $args{'recursively'} ? 'CachedGroupMembers' : 'GroupMembers';

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


=head2 user_members

Returns an L<RT::Model::UserCollection> object of this group's members, by default
returns users including all members of subgroups, but could be
changed with C<recursively> named argument.

=cut

sub user_members {
    my $self = shift;
    my %args = ( recursively => 1, @_ );

    #If we don't have rights, don't include any results
    # TODO XXX  WHY IS THERE NO ACL CHECK HERE?

    my $members_table = $args{'recursively'} ? 'CachedGroupMembers' : 'GroupMembers';

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


=head2 member_emails

Returns an array of the email addresses of all of this group's members

=cut

sub member_emails {
    my $self = shift;

    my %addresses;
    my $members = $self->user_members;
    while ( my $member = $members->next ) {
        $addresses{ $member->email } = 1;
    }
    return ( sort keys %addresses );
}



=head2 member_emails_as_string

Returns a comma delimited string of the email addresses of all users 
who are members of this group.

=cut

sub member_emails_as_string {
    my $self = shift;
    return ( join( ', ', $self->member_emails ) );
}



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
            unless ( $self->current_user_has_right('AdminOwnPersonalGroups') ) {
                return ( 0, _('Permission Denied') );
            }
        } else {
            unless ( $self->current_user_has_right('AdminAllPersonalGroups') ) {
                return ( 0, _('Permission Denied') );
            }
        }
    }

    else {

        # We should only allow membership changes if the user has the right
        # to modify group membership or the user is the principal in question
        # and the user has the right to modify his own membership
        unless ( ( $new_member == $self->current_user->user_object->id && $self->current_user_has_right('ModifyOwnMembership') )
            || $self->current_user_has_right('AdminGroupMembership') )
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

# takes a paramhash of { principal_id => undef }

sub _add_member {
    my $self = shift;
    my %args = (
        principal_id       => undef,
        @_
    );
    my $new_member = $args{'principal_id'};
    unless ( $self->id ) {
        Jifty->log->fatal( "Attempting to add a member to a group which wasn't loaded. 'oops'" );
        return ( 0, _("Group not found") );
    }

    unless ( $new_member =~ /^\d+$/ ) {
        Jifty->log->fatal("_add_member called with a parameter that's not an integer.");
    }

    my $new_member_obj = RT::Model::Principal->new;
    $new_member_obj->load($new_member);

    unless ( $new_member_obj->id ) {
        Jifty->log->debug("Couldn't find that principal");
        return ( 0, _("Couldn't find that principal") );
    }

    if ( $self->has_member($new_member_obj) ) {

        #User is already a member of this group. no need to add it
        return (
            0,
            _(
                "Group already has member: %1",
                $new_member_obj->object->name
            )
        );
    }
    if (   $new_member_obj->is_group
        && $new_member_obj->object->has_member( $self->principal, recursively => 1 ) )
    {

        #This group can't be made to be a member of itself
        return ( 0, _("Groups can't be members of their members") );
    }

    my $member_object = RT::Model::GroupMember->new;
    my $id            = $member_object->create(
        member             => $new_member_obj,
        group              => $self->principal,
    );
    if ($id) {
        return ( 1,
            _( "Member added: %1", $new_member_obj->object->name ) );
    } else {
        return ( 0, _("Couldn't add member to group") );
    }
}


=head2 has_member

Takes an L<RT::Model::Principal> object or its id and optional 'recursively'
argument. Returns id of a GroupMember or CachedGroupMember record if that user
is a member of this group. By default lookup is not recursive.

Returns undef if the user isn't a member of the group or if the current
user doesn't have permission to find out. Arguably, it should differentiate
between ACL failure and non membership.

=cut

sub has_member {
    my $self      = shift;
    my $principal = shift;
    my %args      = (
        recursively => 0,
        @_
    );

    my $id;
    if ( UNIVERSAL::isa( $principal, 'RT::Model::Principal' ) ) {
        $id = $principal->id;
    } elsif ( $principal =~ /^\d+$/ ) {
        $id = $principal;
    } else {
        Jifty->log->error(
            "Group::has_member was called with an argument that"
              . " isn't an RT::Model::Principal or id. It's "
              . ( $principal || '(undefined)' )
        );
        return (undef);
    }
    return undef unless $id;

    my $class = $args{'recursively'}
        ? 'RT::Model::CachedGroupMember'
        : 'RT::Model::GroupMember';

    my $member_obj = new $class;
    $member_obj->load_by_cols(
        member_id => $id,
        group_id  => $self->id,
    );

    if ( my $member_id = $member_obj->id ) {
        return $member_id;
    } else {
        return (undef);
    }
}


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
            unless ( $self->current_user_has_right('AdminOwnPersonalGroups') ) {
                return ( 0, _('Permission Denied') );
            }
        } else {
            unless ( $self->current_user_has_right('AdminAllPersonalGroups') ) {
                return ( 0, _('Permission Denied') );
            }
        }
    } else {
        unless ( ( ( $member_id == $self->current_user->id ) && $self->current_user_has_right('ModifyOwnMembership') )
            || $self->current_user_has_right('AdminGroupMembership') )
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
        Jifty->log->debug( "Failed to delete group " . $self->id . " member " . $member_id );
        return ( 0, _("Member not deleted") );
    }
}





sub _set {
    my $self = shift;
    my %args = (
        column             => undef,
        value              => undef,
        transaction_type   => 'set',
        record_transaction => 1,
        @_
    );

    if ( $self->domain eq 'Personal' ) {
        if ( $self->current_user->id == $self->instance ) {
            unless ( $self->current_user_has_right('AdminOwnPersonalGroups') ) {
                return ( 0, _('Permission Denied') );
            }
        } else {
            unless ( $self->current_user_has_right('AdminAllPersonalGroups') ) {
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
            type       => $args{'transaction_type'},
            field      => $args{'column'},
            new_value  => $args{'value'},
            old_value  => $Old,
            time_taken => $args{'time_taken'},
        );
        return ( $Trans, scalar $TransObj->description );
    } else {
        return ( $ret, $msg );
    }
}


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



=head2 principal

Returns the principal object for this user. returns an empty RT::Model::Principal
if there's no principal object matching this user. 
The response is cached. principal should never ever change.


=cut

sub principal {
    my $self = shift;
    unless ( $self->{'principal'} && $self->{'principal'}->id ) {
        $self->{'principal'} = RT::Model::Principal->new;
        $self->{'principal'}->load_by_cols(
            id             => $self->id,
            type => 'Group'
        );
    }
    return $self->{'principal'};
}

=head2 principal_id  

Returns this user's principal_id

=cut

sub principal_id {
    my $self = shift;
    return $self->id;
}


sub basic_columns {
    ( [ name => 'name' ], [ description => 'description' ], );
}

1;

=head1 AUTHOR

Jesse Vincent, jesse@bestpractical.com

=head1 SEE ALSO

RT

=cut

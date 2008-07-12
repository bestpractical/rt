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

=head1 name

  RT::Model::GroupMember - a member of an RT Group

=head1 SYNOPSIS

RT::Model::GroupMember should never be called directly. It should ONLY
only be accessed through the helper functions in RT::Model::Group;

If you're operating on an RT::Model::GroupMember object yourself, you B<ARE>
doing something wrong.

=head1 description




=head1 METHODS




=cut

package RT::Model::GroupMember;

use strict;
no warnings qw(redefine);
use RT::Model::CachedGroupMemberCollection;

use base qw/RT::Record/;

sub table {'GroupMembers'}

use Jifty::DBI::Schema;
use Jifty::DBI::Record schema {
    column group_id  => references RT::Model::Group;
    column member_id => references RT::Model::Principal;

};

# {{{ sub create

=head2 create { Group => undef, Member => undef }

Add a Principal to the group Group.
if the Principal is a group, automatically inserts all
members of the principal into the cached members table recursively down.

Both Group and Member are expected to be RT::Model::Principal objects

=cut

sub create {
    my $self = shift;
    my %args = (
        group              => undef,
        member             => undef,
        inside_transaction => undef,
        @_
    );

    unless ( $args{'group'}
        && UNIVERSAL::isa( $args{'group'}, 'RT::Model::Principal' )
        && $args{'group'}->id )
    {
        Carp::cluck();
        Jifty->log->warn( "GroupMember::Create called with a bogus group arg: " . $args{'group'} );
        return (undef);
    }

    unless ( $args{'group'}->is_group ) {
        Jifty->log->warn("Someone tried to add a member to a user instead of a group");
        return (undef);
    }

    unless ( $args{'member'}
        && UNIVERSAL::isa( $args{'member'}, 'RT::Model::Principal' )
        && $args{'member'}->id )
    {
        Jifty->log->warn("GroupMember::Create called with a bogus Principal arg");
        return (undef);
    }

    #Clear the key cache. TODO someday we may want to just clear a little bit of the keycache space.
    # TODO what about the groups key cache?
    RT::Model::Principal->invalidate_acl_cache();

    Jifty->handle->begin_transaction() unless ( $args{'inside_transaction'} );

    # We really need to make sure we don't add any members to this group
    # that contain the group itself. that would, um, suck.
    # (and recurse infinitely)  Later, we can add code to check this in the
    # cache and bail so we can support cycling directed graphs

    if ( $args{'member'}->is_group ) {
        my $member_object = $args{'member'}->object;
        if ( $member_object->has_member_recursively( $args{'group'} ) ) {
            Jifty->log->debug("Adding that group would create a loop");
            Jifty->handle->rollback() unless ( $args{'inside_transaction'} );
            return (undef);
        } elsif ( $args{'member'}->id == $args{'group'}->id ) {
            Jifty->log->debug("Can't add a group to itself");
            Jifty->handle->rollback() unless ( $args{'inside_transaction'} );
            return (undef);
        }
    }

    my $id = $self->SUPER::create(
        group_id  => $args{'group'}->id,
        member_id => $args{'member'}->id
    );

    unless ($id) {
        Jifty->handle->rollback() unless ( $args{'inside_transaction'} );
        return (undef);
    }

    my $cached_member = RT::Model::CachedGroupMember->new;
    my $cached_id     = $cached_member->create(
        member           => $args{'member'},
        group            => $args{'group'},
        immediate_parent => $args{'group'},
        via              => '0'
    );

    #and popuplate the CachedGroupMembers of all the groups that group is part of .

    my $cgm = RT::Model::CachedGroupMemberCollection->new;

    #When adding a member to a group, we need to go back
    # find things which have the current group as a member.
    # $group is an RT::Model::Principal for the group.
    $cgm->limit_to_groups_with_member( $args{'group'}->id );

    while ( my $parent_member = $cgm->next ) {
        my $parent_id = $parent_member->member_id;
        my $via       = $parent_member->id;
        my $group_id  = $parent_member->group_id;

        my $other_cached_member = RT::Model::CachedGroupMember->new;
        my $other_cached_id     = $other_cached_member->create(
            member           => $args{'member'},
            group            => $parent_member->group_obj,
            immediate_parent => $parent_member->member_obj,
            via              => $parent_member->id
        );
        unless ($other_cached_id) {
            Jifty->log->err( "Couldn't add " . $args{'member'} . " as a submember of a supergroup" );
            Jifty->handle->rollback() unless ( $args{'inside_transaction'} );
            return (undef);
        }
    }

    unless ($cached_id) {
        Jifty->handle->rollback() unless ( $args{'inside_transaction'} );
        return (undef);
    }

    Jifty->handle->commit() unless ( $args{'inside_transaction'} );

    return ($id);
}

# }}}

# {{{ sub _stash_user

=head2 _stash_user PRINCIPAL

Create { Group => undef, Member => undef }

Creates an entry in the groupmembers table, which lists a user
as a member of himself. This makes ACL checks a whole bunch easier.
This happens once on user create and never ever gets yanked out.

PRINCIPAL is expected to be an RT::Model::Principal object for a user

This routine expects to be called inside a transaction by RT::Model::User->create

=cut

sub _stash_user {
    my $self = shift;
    my %args = (
        group  => undef,
        member => undef,
        @_
    );

    #Clear the key cache. TODO someday we may want to just clear a little bit of the keycache space.
    # TODO what about the groups key cache?
    RT::Model::Principal->invalidate_acl_cache();

    # We really need to make sure we don't add any members to this group
    # that contain the group itself. that would, um, suck.
    # (and recurse infinitely)  Later, we can add code to check this in the
    # cache and bail so we can support cycling directed graphs

    my $id = $self->SUPER::create(
        group_id  => $args{'group'}->id,
        member_id => $args{'member'}->id,
    );

    unless ($id) {
        return (undef);
    }

    my $cached_member = RT::Model::CachedGroupMember->new;
    my $cached_id     = $cached_member->create(
        member           => $args{'member'},
        group            => $args{'group'},
        immediate_parent => $args{'group'},
        via              => '0'
    );

    unless ($cached_id) {
        return (undef);
    }

    return ($id);
}

# }}}

# {{{ sub delete

=head2 delete

Takes no arguments. deletes the currently loaded member from the 
group in question.

Expects to be called _outside_ a transaction

=cut

sub delete {
    my $self = shift;

    Jifty->handle->begin_transaction();

    # Find all occurrences of this member as a member of this group
    # in the cache and nuke them, recursively.

    # The following code will delete all Cached Group members
    # where this member's group is _not_ the primary group
    # (Ie if we're deleting C as a member of B, and B happens to be
    # a member of A, will delete C as a member of A without touching
    # C as a member of B

    my $cached_submembers = RT::Model::CachedGroupMemberCollection->new;

    $cached_submembers->limit(
        column   => 'member_id',
        operator => '=',
        value    => $self->member_obj->id
    );

    $cached_submembers->limit(
        column   => 'immediate_parent_id',
        operator => '=',
        value    => $self->group_obj->id
    );

    while ( my $item_to_del = $cached_submembers->next() ) {
        my ( $del_err, $del_msg ) = $item_to_del->delete();
        unless ($del_err) {
            Jifty->handle->rollback();
            Jifty->log->warn( "Couldn't delete cached group submember " . $item_to_del->id );
            return (undef);
        }
    }

    my ( $err, $msg ) = $self->SUPER::delete();
    unless ($err) {
        Jifty->log->warn( "Couldn't delete cached group submember " . $self->id );
        Jifty->handle->rollback();
        return (undef);
    }

    # Since this deletion may have changed the former member's
    # delegation rights, we need to ensure that no invalid delegations
    # remain.
    ( $err, $msg ) = $self->member_obj->_cleanup_invalid_delegations( inside_transaction => 1 );
    unless ($err) {
        Jifty->log->warn( "Unable to revoke delegated rights for principal " . $self->id );
        Jifty->handle->rollback();
        return (undef);
    }

    #Clear the key cache. TODO someday we may want to just clear a little bit of the keycache space.
    # TODO what about the groups key cache?
    RT::Model::Principal->invalidate_acl_cache();

    Jifty->handle->commit();
    return ($err);

}

# }}}

# {{{ sub member_obj

=head2 member_obj

Returns an RT::Model::Principal object for the Principal specified by $self->principal_id

=cut

sub member_obj {
    my $self = shift;
    unless ( defined( $self->{'Member_obj'} ) ) {
        $self->{'Member_obj'} = RT::Model::Principal->new;
        $self->{'Member_obj'}->load( $self->member_id ) if ( $self->member_id );
    }
    return ( $self->{'Member_obj'} );
}

# }}}

# {{{ sub group_obj

=head2 group_obj

Returns an RT::Model::Principal object for the Group specified in $self->group_id

=cut

sub group_obj {
    my $self = shift;
    unless ( defined( $self->{'Group_obj'} ) ) {
        $self->{'Group_obj'} = RT::Model::Principal->new;
        $self->{'Group_obj'}->load( $self->group_id );
    }
    return ( $self->{'Group_obj'} );
}

# }}}

1;

# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2011 Best Practical Solutions, LLC
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

=head1 NAME

  RT::GroupMember - a member of an RT Group

=head1 SYNOPSIS

RT::GroupMember should never be called directly. It should ONLY
only be accessed through the helper functions in RT::Group;

If you're operating on an RT::GroupMember object yourself, you B<ARE>
doing something wrong.

=head1 DESCRIPTION




=head1 METHODS




=cut


package RT::GroupMember;

use strict;
no warnings qw(redefine);
use RT::CachedGroupMembers;

# {{{ sub Create

=head2 Create { Group => undef, Member => undef }

Add a Principal to the group Group.
if the Principal is a group, automatically inserts all
members of the principal into the cached members table recursively down.

Both Group and Member are expected to be RT::Principal objects

=cut

sub Create {
    my $self = shift;
    my %args = (
        Group  => undef,
        Member => undef,
        InsideTransaction => undef,
        @_
    );

    unless ($args{'Group'} &&
            UNIVERSAL::isa($args{'Group'}, 'RT::Principal') &&
            $args{'Group'}->Id ) {

        $RT::Logger->warning("GroupMember::Create called with a bogus Group arg");
        return (undef);
    }

    unless($args{'Group'}->IsGroup) {
        $RT::Logger->warning("Someone tried to add a member to a user instead of a group");
        return (undef);
    }

    unless ($args{'Member'} && 
            UNIVERSAL::isa($args{'Member'}, 'RT::Principal') &&
            $args{'Member'}->Id) {
        $RT::Logger->warning("GroupMember::Create called with a bogus Principal arg");
        return (undef);
    }


    #Clear the key cache. TODO someday we may want to just clear a little bit of the keycache space. 
    # TODO what about the groups key cache?
    RT::Principal->InvalidateACLCache();

    $RT::Handle->BeginTransaction() unless ($args{'InsideTransaction'});

    # We really need to make sure we don't add any members to this group
    # that contain the group itself. that would, um, suck. 
    # (and recurse infinitely)  Later, we can add code to check this in the 
    # cache and bail so we can support cycling directed graphs

    if ($args{'Member'}->IsGroup) {
        my $member_object = $args{'Member'}->Object;
        if ($member_object->HasMemberRecursively($args{'Group'})) {
            $RT::Logger->debug("Adding that group would create a loop");
            $RT::Handle->Rollback() unless ($args{'InsideTransaction'});
            return(undef);
        }
        elsif ( $args{'Member'}->Id == $args{'Group'}->Id) {
            $RT::Logger->debug("Can't add a group to itself");
            $RT::Handle->Rollback() unless ($args{'InsideTransaction'});
            return(undef);
        }
    }


    my $id = $self->SUPER::Create(
        GroupId  => $args{'Group'}->Id,
        MemberId => $args{'Member'}->Id
    );

    unless ($id) {
        $RT::Handle->Rollback() unless ($args{'InsideTransaction'});
        return (undef);
    }

    my $cached_member = RT::CachedGroupMember->new( $self->CurrentUser );
    my $cached_id     = $cached_member->Create(
        Member          => $args{'Member'},
        Group           => $args{'Group'},
        ImmediateParent => $args{'Group'},
        Via             => '0'
    );


    #When adding a member to a group, we need to go back
    #and popuplate the CachedGroupMembers of all the groups that group is part of .

    my $cgm = RT::CachedGroupMembers->new( $self->CurrentUser );

    # find things which have the current group as a member. 
    # $group is an RT::Principal for the group.
    $cgm->LimitToGroupsWithMember( $args{'Group'}->Id );
    $cgm->Limit(
        SUBCLAUSE => 'filter', # dont't mess up with prev condition
        FIELD => 'MemberId',
        OPERATOR => '!=',
        VALUE => 'main.GroupId',
        QUOTEVALUE => 0,
        ENTRYAGGREGATOR => 'AND',
    );

    while ( my $parent_member = $cgm->Next ) {
        my $parent_id = $parent_member->MemberId;
        my $via       = $parent_member->Id;
        my $group_id  = $parent_member->GroupId;

          my $other_cached_member =
          RT::CachedGroupMember->new( $self->CurrentUser );
        my $other_cached_id = $other_cached_member->Create(
            Member          => $args{'Member'},
                      Group => $parent_member->GroupObj,
            ImmediateParent => $parent_member->MemberObj,
            Via             => $parent_member->Id
        );
        unless ($other_cached_id) {
            $RT::Logger->err( "Couldn't add " . $args{'Member'}
                  . " as a submember of a supergroup" );
            $RT::Handle->Rollback() unless ($args{'InsideTransaction'});
            return (undef);
        }
    } 

    unless ($cached_id) {
        $RT::Handle->Rollback() unless ($args{'InsideTransaction'});
        return (undef);
    }

    $RT::Handle->Commit() unless ($args{'InsideTransaction'});

    return ($id);
}

# }}}

# {{{ sub _StashUser

=head2 _StashUser PRINCIPAL

Create { Group => undef, Member => undef }

Creates an entry in the groupmembers table, which lists a user
as a member of himself. This makes ACL checks a whole bunch easier.
This happens once on user create and never ever gets yanked out.

PRINCIPAL is expected to be an RT::Principal object for a user

This routine expects to be called inside a transaction by RT::User->Create

=cut

sub _StashUser {
    my $self = shift;
    my %args = (
        Group  => undef,
        Member => undef,
        @_
    );

    #Clear the key cache. TODO someday we may want to just clear a little bit of the keycache space. 
    # TODO what about the groups key cache?
    RT::Principal->InvalidateACLCache();


    # We really need to make sure we don't add any members to this group
    # that contain the group itself. that would, um, suck. 
    # (and recurse infinitely)  Later, we can add code to check this in the 
    # cache and bail so we can support cycling directed graphs

    my $id = $self->SUPER::Create(
        GroupId  => $args{'Group'}->Id,
        MemberId => $args{'Member'}->Id,
    );

    unless ($id) {
        return (undef);
    }

    my $cached_member = RT::CachedGroupMember->new( $self->CurrentUser );
    my $cached_id     = $cached_member->Create(
        Member          => $args{'Member'},
        Group           => $args{'Group'},
        ImmediateParent => $args{'Group'},
        Via             => '0'
    );

    unless ($cached_id) {
        return (undef);
    }

    return ($id);
}

# }}}

# {{{ sub Delete

=head2 Delete

Takes no arguments. deletes the currently loaded member from the 
group in question.

Expects to be called _outside_ a transaction

=cut

sub Delete {
    my $self = shift;


    $RT::Handle->BeginTransaction();

    # Find all occurrences of this member as a member of this group
    # in the cache and nuke them, recursively.

    # The following code will delete all Cached Group members
    # where this member's group is _not_ the primary group 
    # (Ie if we're deleting C as a member of B, and B happens to be 
    # a member of A, will delete C as a member of A without touching
    # C as a member of B

    my $cached_submembers = RT::CachedGroupMembers->new( $self->CurrentUser );

    $cached_submembers->Limit(
        FIELD    => 'MemberId',
        OPERATOR => '=',
        VALUE    => $self->MemberObj->Id
    );

    $cached_submembers->Limit(
        FIELD    => 'ImmediateParentId',
        OPERATOR => '=',
        VALUE    => $self->GroupObj->Id
    );





    while ( my $item_to_del = $cached_submembers->Next() ) {
        my $del_err = $item_to_del->Delete();
        unless ($del_err) {
            $RT::Handle->Rollback();
            $RT::Logger->warning("Couldn't delete cached group submember ".$item_to_del->Id);
            return (undef);
        }
    }

    my ($err, $msg) = $self->SUPER::Delete();
    unless ($err) {
            $RT::Logger->warning("Couldn't delete cached group submember ".$self->Id);
        $RT::Handle->Rollback();
        return (undef);
    }

    # Since this deletion may have changed the former member's
    # delegation rights, we need to ensure that no invalid delegations
    # remain.
    $err = $self->MemberObj->_CleanupInvalidDelegations(InsideTransaction => 1);
    unless ($err) {
	$RT::Logger->warning("Unable to revoke delegated rights for principal ".$self->Id);
	$RT::Handle->Rollback();
	return (undef);
    }

    #Clear the key cache. TODO someday we may want to just clear a little bit of the keycache space. 
    # TODO what about the groups key cache?
    RT::Principal->InvalidateACLCache();

    $RT::Handle->Commit();
    return ($err);

}

# }}}

# {{{ sub MemberObj

=head2 MemberObj

Returns an RT::Principal object for the Principal specified by $self->PrincipalId

=cut

sub MemberObj {
    my $self = shift;
    unless ( defined( $self->{'Member_obj'} ) ) {
        $self->{'Member_obj'} = RT::Principal->new( $self->CurrentUser );
        $self->{'Member_obj'}->Load( $self->MemberId ) if ($self->MemberId);
    }
    return ( $self->{'Member_obj'} );
}

# }}}

# {{{ sub GroupObj

=head2 GroupObj

Returns an RT::Principal object for the Group specified in $self->GroupId

=cut

sub GroupObj {
    my $self = shift;
    unless ( defined( $self->{'Group_obj'} ) ) {
        $self->{'Group_obj'} = RT::Principal->new( $self->CurrentUser );
        $self->{'Group_obj'}->Load( $self->GroupId );
    }
    return ( $self->{'Group_obj'} );
}

# }}}

1;

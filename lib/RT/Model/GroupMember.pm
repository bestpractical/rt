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
use warnings;

use RT::Model::CachedGroupMemberCollection;

use base qw/RT::Record/;

sub table {'GroupMembers'}

use Jifty::DBI::Schema;
use Jifty::DBI::Record schema {
    column group_id  => references RT::Model::Principal;
    column member_id => references RT::Model::Principal;
};

use Scalar::Util qw(blessed);


=head2 create { group => undef, member => undef }

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
        @_
    );

    foreach my $type (qw(group member)) {
        if ( blessed $args{$type} ) {
            unless ( $args{$type}->id ) {
                Jifty->log->error( "GroupMember::Create called with a not loaded $type argument");
                return (undef);
            }
            if ( $args{$type}->isa('RT::Model::Principal') ) {
                $args{$type} = $args{$type}->object;
            } elsif ( !$args{$type}->isa('RT::IsPrincipal') ) {
                Jifty->log->warn( "GroupMember::Create called with a bogus $type arg: " . $args{$type} );
                return (undef);
            }
        } else {
            my $p = RT::Model::Principal->new( $self->current_user );
            $p->load( $args{$type} );
            unless ( $p->id ) {
                $RT::Logger->error("Couldn't find principal '$args{$type}'");
                return (undef);
            }
        }
    }

    unless ( $args{'group'}->isa('RT::IsPrincipal::HasMembers') ) {
        Jifty->log->warn("Someone tried to add a member to a principal that can not has members");
        return (undef);
    }

    #Clear the key cache. TODO someday we may want to just clear a little bit of the keycache space.
    # TODO what about the groups key cache?
    RT::Model::Principal->invalidate_acl_cache();

    my $inside_transaction = Jifty->handle->transaction_depth;
    Jifty->handle->begin_transaction() unless $inside_transaction;

    if ( $args{'member'}->id == $args{'group'}->id ) {
        Jifty->log->debug("Can't add a group to itself");
        Jifty->handle->rollback() unless $inside_transaction;
        return (undef);
    }

    # We really need to make sure we don't add any members to this group
    # that contain the group itself. that would, um, suck.
    # (and recurse infinitely)  Later, we can add code to check this in the
    # cache and bail so we can support cycling directed graphs
    if ( $args{'member'}->has_member( principal => $args{'group'}, recursively => 1 ) ) {
        Jifty->log->debug("Adding that group would create a loop");
        Jifty->handle->rollback() unless $inside_transaction;
        return (undef);
    }

    my $id = $self->SUPER::create(
        group_id  => $args{'group'}->id,
        member_id => $args{'member'}->id
    );

    unless ($id) {
        Jifty->handle->rollback() unless $inside_transaction;
        return (undef);
    }

    my $cached_member = RT::Model::CachedGroupMember->new( current_user => $self->current_user );
    my $cached_id     = $cached_member->create(
        member           => $args{'member'}->principal,
        group            => $args{'group'}->principal,
        immediate_parent => $args{'group'}->principal,
        via              => '0'
    );

    #and popuplate the CachedGroupMembers of all the groups that group is part of .

    my $cgm = RT::Model::CachedGroupMemberCollection->new( current_user => $self->current_user );

    #When adding a member to a group, we need to go back
    # find things which have the current group as a member.
    # $group is an RT::Model::Principal for the group.
    $cgm->limit_to_groups_with_member( $args{'group'}->id );

    while ( my $parent_member = $cgm->next ) {
        my $other_cached_member = RT::Model::CachedGroupMember->new( current_user => $self->current_user );
        my $other_cached_id     = $other_cached_member->create(
            member           => $args{'member'}->principal,
            group            => $parent_member->group,
            immediate_parent => $parent_member->member,
            via              => $parent_member->id
        );
        unless ($other_cached_id) {
            Jifty->log->err( "Couldn't add " . $args{'member'} . " as a submember of a supergroup" );
            Jifty->handle->rollback() unless $inside_transaction;
            return (undef);
        }
    }

    unless ($cached_id) {
        Jifty->handle->rollback() unless $inside_transaction;
        return (undef);
    }

    Jifty->handle->commit() unless $inside_transaction;

    return ($id);
}



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

    my $cached_member = RT::Model::CachedGroupMember->new( current_user => $self->current_user );
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

    my $cached_submembers = RT::Model::CachedGroupMemberCollection->new(
        current_user => $self->current_user
    );
    $cached_submembers->limit(
        column   => 'member_id',
        operator => '=',
        value    => $self->member->id
    );
    $cached_submembers->limit(
        column   => 'immediate_parent',
        operator => '=',
        value    => $self->group->id
    );

    while ( my $item_to_del = $cached_submembers->next ) {
        my ( $del_err, $del_msg ) = $item_to_del->delete;
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

    #Clear the key cache. TODO someday we may want to just clear a little bit of the keycache space.
    # TODO what about the groups key cache?
    RT::Model::Principal->invalidate_acl_cache();

    Jifty->handle->commit();
    return ($err);

}

1;

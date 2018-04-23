# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2018 Best Practical Solutions, LLC
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
use warnings;


use base 'RT::Record';

sub Table {'GroupMembers'}


use RT::CachedGroupMembers;


=head2 Create { Group => undef, Member => undef }

Add a Principal to the group Group.
if the Principal is a group, automatically inserts all
members of the principal into the cached members table recursively down.

Both Group and Member are expected to be RT::Principal objects

=cut

sub _InsertCGM {
    my $self = shift;

    my $cached_member = RT::CachedGroupMember->new( $self->CurrentUser );
    my $cached_id     = $cached_member->Create(
        Member          => $self->MemberObj,
        Group           => $self->GroupObj,
        ImmediateParent => $self->GroupObj,
        Via             => '0'
    );


    #When adding a member to a group, we need to go back
    #and popuplate the CachedGroupMembers of all the groups that group is part of .

    my $cgm = RT::CachedGroupMembers->new( $self->CurrentUser );

    # find things which have the current group as a member. 
    # $group is an RT::Principal for the group.
    $cgm->LimitToGroupsWithMember( $self->GroupId );
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
            Member          => $self->MemberObj,
                      Group => $parent_member->GroupObj,
            ImmediateParent => $parent_member->MemberObj,
            Via             => $parent_member->Id
        );
        unless ($other_cached_id) {
            $RT::Logger->err( "Couldn't add " . $self->MemberId
                  . " as a submember of a supergroup" );
            return;
        }
    }

    return $cached_id;
}

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

    my $clone = RT::GroupMember->new( $self->CurrentUser );
    $clone->Load( $id );
    my $cached_id = $clone->_InsertCGM;

    unless ($cached_id) {
        $RT::Handle->Rollback() unless ($args{'InsideTransaction'});
        return (undef);
    }

    $RT::Handle->Commit() unless ($args{'InsideTransaction'});

    return ($id);
}



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



=head2 Delete

Takes no arguments. deletes the currently loaded member from the 
group in question.

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
        my ($ok, $msg) = $item_to_del->Delete();
        unless ($ok) {
            $RT::Handle->Rollback();
            return ($ok, $msg);
        }
    }

    my ($ok, $msg) = $self->SUPER::Delete();
    unless ($ok) {
        $RT::Logger->error("Couldn't delete GroupMember ".$self->Id);
        $RT::Handle->Rollback();
        return ($ok, $msg);
    }

    #Clear the key cache. TODO someday we may want to just clear a little bit of the keycache space. 
    # TODO what about the groups key cache?
    RT::Principal->InvalidateACLCache();

    $RT::Handle->Commit();
    return ($ok, $msg);

}



=head2 MemberObj

Returns an RT::Principal object for the Principal specified by $self->MemberId

=cut

sub MemberObj {
    my $self = shift;
    unless ( defined( $self->{'Member_obj'} ) ) {
        $self->{'Member_obj'} = RT::Principal->new( $self->CurrentUser );
        $self->{'Member_obj'}->Load( $self->MemberId ) if ($self->MemberId);
    }
    return ( $self->{'Member_obj'} );
}



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






=head2 id

Returns the current value of id.
(In the database, id is stored as int(11).)


=cut


=head2 GroupId

Returns the current value of GroupId.
(In the database, GroupId is stored as int(11).)



=head2 SetGroupId VALUE


Set GroupId to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, GroupId will be stored as a int(11).)


=cut


=head2 MemberId

Returns the current value of MemberId.
(In the database, MemberId is stored as int(11).)



=head2 SetMemberId VALUE


Set MemberId to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, MemberId will be stored as a int(11).)


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
        GroupId =>
                {read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        MemberId =>
                {read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
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

sub FindDependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::FindDependencies($walker, $deps);

    $deps->Add( out => $self->GroupObj->Object );
    $deps->Add( out => $self->MemberObj->Object );
}

sub __DependsOn {
    my $self = shift;
    my %args = (
        Shredder => undef,
        Dependencies => undef,
        @_,
    );
    my $deps = $args{'Dependencies'};
    my $list = [];

    my $objs = RT::CachedGroupMembers->new( $self->CurrentUser );
    $objs->Limit( FIELD => 'MemberId', VALUE => $self->MemberId );
    $objs->Limit( FIELD => 'ImmediateParentId', VALUE => $self->GroupId );
    push( @$list, $objs );

    $deps->_PushDependencies(
        BaseObject => $self,
        Flags => RT::Shredder::Constants::DEPENDS_ON,
        TargetObjects => $list,
        Shredder => $args{'Shredder'}
    );

    my $group = $self->GroupObj->Object;
    # XXX: If we delete member of the ticket owner role group then we should also
    # fix ticket object, but only if we don't plan to delete group itself!
    unless( ($group->Name || '') eq 'Owner' &&
        ($group->Domain || '') eq 'RT::Ticket-Role' ) {
        return $self->SUPER::__DependsOn( %args );
    }

    # we don't delete group, so we have to fix Ticket and Group
    $deps->_PushDependencies(
        BaseObject => $self,
        Flags => RT::Shredder::Constants::DEPENDS_ON | RT::Shredder::Constants::VARIABLE,
        TargetObjects => $group,
        Shredder => $args{'Shredder'}
    );
    $args{'Shredder'}->PutResolver(
        BaseClass => ref $self,
        TargetClass => ref $group,
        Code => sub {
            my %args = (@_);
            my $group = $args{'TargetObject'};
            return if $args{'Shredder'}->GetState( Object => $group )
                & (RT::Shredder::Constants::WIPED|RT::Shredder::Constants::IN_WIPING);
            return unless ($group->Name || '') eq 'Owner';
            return unless ($group->Domain || '') eq 'RT::Ticket-Role';

            return if $group->MembersObj->Count > 1;

            my $group_member = $args{'BaseObject'};

            if( $group_member->MemberObj->id == RT->Nobody->id ) {
                RT::Shredder::Exception->throw( "Couldn't delete Nobody from owners role group" );
            }

            my( $status, $msg ) = $group->AddMember( RT->Nobody->id );

            RT::Shredder::Exception->throw( $msg ) unless $status;

            return;
        },
    );

    return $self->SUPER::__DependsOn( %args );
}

sub PreInflate {
    my $class = shift;
    my ($importer, $uid, $data) = @_;

    $class->SUPER::PreInflate( $importer, $uid, $data );

    my $obj = RT::GroupMember->new( RT->SystemUser );
    $obj->LoadByCols(
        GroupId  => $data->{GroupId},
        MemberId => $data->{MemberId},
    );
    if ($obj->id) {
        $importer->Resolve( $uid => ref($obj) => $obj->Id );
        return;
    }

    return 1;
}

sub PostInflate {
    my $self = shift;

    $self->_InsertCGM;
}

RT::Base->_ImportOverlays();

1;

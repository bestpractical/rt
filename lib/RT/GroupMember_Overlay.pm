# $Header: /raid/cvsroot/rt/lib/RT/GroupMember.pm,v 1.3 2001/12/14 19:03:08 jesse Exp $
# Copyright 1996-2002 Jesse Vincent <jesse@bestpractical.com>
# Released under the terms of the GNU Public License

=head1 NAME

  RT::GroupMember - a member of an RT Group

=head1 SYNOPSIS

RT::GroupMember should never be called directly. It should generally
only be accessed through the helper functions in RT::Group;
This class does no authentication itself

=head1 DESCRIPTION




=head1 METHODS


=begin testing

ok (require RT::GroupMember);

=end testing


=cut

no warnings qw(redefine);
use RT::CachedGroupMembers;

# {{{ sub _ClassAccessible 

sub _ClassAccessible {
    {

        id => { read => 1, type => 'int(11)', default => '' },
          GroupId =>
          { read => 1, write => 1, type => 'int(11)', default => '' },
          MemberId =>
          { read => 1, write => 1, type => 'int(11)', default => '' },

    }
};

# }}}

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
        @_
    );

    unless ($args{'Group'} &&
            UNIVERSAL::isa($args{'Group'}, 'RT::Principal') &&
            $args{'Group'}->Id
            
            ) {

        $RT::Logger->warning("GroupMember::Create called with a bogus Group arg");
        return (undef);
    }

    unless($args{'Group'}->IsGroup) {
        $RT::Logger->warning("Someone tried to add a member to a user instead of a group");
        return (undef);
    }

    unless ($args{'Member'} && 
            UNIVERSAL::isa($args{'Member'}, 'RT::Principal') &&
            $args{'Member'}->Id
            ) {
        $RT::Logger->warning("GroupMember::Create called with a bogus Principal arg");
        return (undef);
    }
    $RT::Handle->BeginTransaction();

    # We really need to make sure we don't add any members to this group
    # that contain the group itself. that would, um, suck. 
    # (and recurse infinitely)  Later, we can add code to check this in the 
    # cache and bail so we can support cycling directed graphs

    if ($args{'Member'}->IsGroup) {
        my $member_object = $args{'Member'}->Object;
        if ($member_object->HasMemberRecursively($args{'Group'})) {
            $RT::Logger->debug("Adding that group would create a loop");
            return(undef);
        }
        elsif ( $args{'Member'}->Id == $args{'Group'}->Id) {
            $RT::Logger->debug("Can't add a group to itself");
            return(undef);
        }
    }


    my $id = $self->SUPER::Create(
        GroupId  => $args{'Group'}->Id,
        MemberId => $args{'Member'}->Id
    );

    unless ($id) {
        $RT::Handle->Rollback();
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
        $RT::Handle->Rollback();
        return (undef);
    }

    $RT::Handle->Commit();

    return ($id);
}

# }}}

# {{{ sub Add

=head2 Add

Takes a paramhash of UserId and GroupId.  makes that user a memeber
of that group

=cut

sub Add {
    my $self = shift;
    return ( $self->Create(@_) );
}

# }}}

# {{{ sub Delete

=head2 Delete

Takes no arguments. deletes the currently loaded member from the 
group in question.

=cut

sub Delete {
    my $self = shift;


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
        #$RT::Logger->debug("About to delete a submember ".$item_to_del->MemberId);
        my $del_err = $item_to_del->Delete();
        unless ($del_err) {
            $RT::Handle->Rollback();
            $RT::Logger->warning("Couldn't delete cached group submember ".$item_to_del->Id);
            return (undef);
        }
    }

    my $err = $self->SUPER::Delete();
    unless ($err) {
            $RT::Logger->warning("Couldn't delete cached group submember ".$self->Id);
        $RT::Handle->Rollback();
        return (undef);
    }
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
        $self->{'Member_obj'}->Load( $self->MemberId );
    }
    return ( $self->{'Member_obj'} );
}

# }}


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

# }}

1;

1;

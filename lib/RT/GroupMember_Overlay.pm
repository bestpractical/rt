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

This routine expects a Group object and a Principal object

=cut

sub Create {
    my $self = shift;
    my %args = (
        Group  => undef,
        Member => undef,
        @_
    );

    $RT::Handle->BeginTransaction();

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
    unless ( $self->CurrentUser->HasSystemRight('AdminGroups') ) {
        return ( 0, $self->loc('Permission Denied') );
    }

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
        VALUE    => $self->PrincipalId
    );

    $cached_submembers->Limit(
        FIELD    => 'ImmediateParentId',
        OPERATOR => '=',
        VALUE    => $self->GroupObj->PrincipalId
    );

    while ( my $item_to_del = $cached_submembers->Next() ) {
        my $del_err = $item_to_del->Delete();
        unless ($del_err) {
            $RT::Handle->Rollback();
            return (undef);
        }
    }

    my $err = $self->SUPER::Delete();
    unless ($err) {
        $RT::Handle->Rollback();
        return (undef);
    }
    $RT::Handle->Commit();
    return ($err);

}

# }}}

# {{{ sub PrincipalObj

=head2 PrincipalObj

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

1;

# $Header: /raid/cvsroot/rt/lib/RT/GroupMember.pm,v 1.3 2001/12/14 19:03:08 jesse Exp $
# Copyright 2000 Jesse Vincent <jesse@fsck.com>
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


# {{{ sub _ClassAccessible 

sub _ClassAccessible {
    {
     
        id =>
                {read => 1, type => 'int(11)', default => ''},
        GroupId => 
                {read => 1, write => 1, type => 'int(11)', default => ''},
        MemberId => 
                {read => 1, write => 1, type => 'int(11)', default => ''},

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
    my %args = ( Group=> undef,
		 Member => undef,
		 @_
	       );
    

    my $id = $self->SUPER::Create(GroupId => $args{'Group'}->Id, MemberId => $args{'Member'}->Id);

    unless ($id) {
        return (undef);
    }

    my $cached_member = RT::CachedGroupMember->new($self->CurrentUser);
    my $cached_id = $cached_member->Create(MemberId => $args{'Member'}->Id,
                                            GroupId => $args{'Group'}->Id,
                                            Via => '0');

    my $group  = $args{'Group'}->Id;

    if ($args{'Member'}->IsGroup) {
        my $group = $args{'Member'}->GroupObj();
        while (my $member =  $group->Next()) {
            my $submember = RT::CachedGroupMemmber->new($self->CurrentUser);
            $submember->Create(MemberId => $member->PrincipalId,
                               GroupId => $group,
                                Via => $cached_id);

        }

    }



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
    return ($self->Create(@_));
}
# }}}

# {{{ sub Delete

=head2 Delete

Takes no arguments. deletes the currently loaded member from the 
group in question.

=cut

sub Delete {
    my $self = shift;
    unless ($self->CurrentUser->HasSystemRight('AdminGroups')) {
	return (0, 'Permission Denied');
    }
    return($self->SUPER::Delete(@_));
}

# }}}

# {{{ sub PrincipalObj

=head2 PrincipalObj

Returns an RT::Principal object for the Principal specified by $self->PrincipalId

=cut

sub MemberObj {
    my $self = shift;
    unless (defined ($self->{'Member_obj'})) {
        $self->{'Member_obj'} = RT::Principal->new($self->CurrentUser);
        $self->{'Member_obj'}->Load($self->MemberId);
    }
    return($self->{'Member_obj'});
}

# }}


1;

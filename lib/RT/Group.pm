# $Header$
# Copyright 2000 Jesse Vincent <jesse@fsck.com>
# Released under the terms of the GNU Public License
#
#

=head1 NAME

  RT::Group - RT's group object

=head1 SYNOPSIS

  use RT::Group;
my $group = new RT::Group($CurrentUser);

=head1 DESCRIPTION

An RT group object.

=head1 AUTHOR

Jesse Vincent, jesse@fsck.com

=head1 SEE ALSO

RT

=head1 METHODS

=cut


package RT::Group;
use RT::Record;
use RT::GroupMember;
use vars qw|@ISA|;
@ISA= qw(RT::Record);


# {{{ sub _Init
sub _Init  {
  my $self = shift; 
  $self->{'table'} = "Groups";
  return ($self->SUPER::_Init(@_));
}
# }}}

# {{{ sub _Accessible 
sub _Accessible  {
    my $self = shift;
    my %Cols = (
		Name => 'read/write',
		Description => 'read/write',
		Pseudo => 'read'
	       );
    return $self->SUPER::_Accessible(@_, %Cols);
}
# }}}

# {{{ sub Create

=head2 Create

Takes a paramhash with three named arguments: Name, Description and Pseudo.
Pseudo is used internally by RT for certain special ACL decisions.

=cut

sub Create {
    my $self = shift;
    my %args = ( Name => undef,
		 Description => undef,
		 Pseudo => 0,
		 @_);
    
    unless ($self->CurrentUser->HasSystemRight('AdminGroups')) {
	$RT::Logger->warning($self->CurrentUser->UserId ." Tried to create a group without permission.");
	return(undef);
    }
    
    my $retval = $self->SUPER::Create(Name => $args{'Name'},
				      Description => $args{'Description'},
				      Pseudo => $args{'Pseudo'});


    return ($retval);
}
# }}}

# {{{ MembersObj

=head2 MembersObj

Returns an RT::GroupMembers object of this group's members.

=cut

sub MembersObj {
    my $self = shift;
    unless (defined $self->{'members_obj'}) {
        $self->{'members_obj'} = new RT::GroupMembers($self->CurrentUser);
        $self->{'members_obj'}->LimitToGroup($self->id);
    }
    return ($self->{'members_obj'});

}

# }}}

# {{{ AddMember

=head2 AddMember

AddMember adds a user to this group.  It takes a user id and 
returns true on successful addition or null on failure.

=cut

sub AddMember {
    my $self = shift;
    my $new_member = shift;

    #TODO --- make sure new_member is an RT::User object


    unless ($self->CurrentUser->HasSystemRight('AdminGroups')) {
        #User has no permission to be doing this
        return(undef);
    }
    if ($self->HasMember($new_member)) {
        #User is already a member of this group. no need to add it
        return(undef);
    }

    my $member_object = new RT::GroupMember($self->CurrentUser);
    $member_object->Create( UserId => $new_member, GroupId => $self->id );

}

# }}}

# {{{ HasMember

=head2 HasMember

Takes a user Id and returns a GroupMember Id if that user is a member of 
this group.
Returns undef if the user isn't a member of the group or if the current
user doesn't have permission to find out. Arguably, it should differentiate
between ACL failure and non membership.

=cut

sub HasMember {
    my $self = shift;
    my $user_id = shift;

    #Try to cons up a member object using "LoadByCols"

    my $member_obj = new RT::GroupMember($self->CurrentUser);
    $member_obj->LoadByCols( UserId => $user_id, GroupId => $self->id);

    #TODO: +++ if Load returns no objects, do we actually have an undef id or 
    # something worse

    #If we have a member object
    if ($member_obj->id) {
        return ($member_obj->id);
    } else {
        return(undef);
    } 
}

# }}}

# {{{ DeleteMember

=head2 DeleteMember

Takes the id of a GroupMember object. If the current user has apropriate rights,
removes that GroupMember from this group.

=cut

sub DeleteMember {
    my $self = shift;
    my $member = shift;


    unless ($self->CurrentUser->HasSystemRight('AdminGroups')) {
        #User has no permission to be doing this
        return(undef);
    }
    my $member_obj = new RT::GroupMember($self->CurrentUser);
    $member_obj->Load($member) ||
        return(undef);  #couldn't load member object
   
    #check ot make sure we're deleting members from the same group.
    if ($member_obj->GroupId != $self->id) {
        $RT::Logger->warn("$self: ".$self->CurrentUser->UserId." tried to delete member $member from the wrong group (".$self->id.").\n");
    }
    #Now that we've checked ACLs and sanity, delete the groupmember

   return ($member_obj->Delete());


}

# }}}

# {{{ ACL Related routines

# {{{ GrantQueueRight

=head2 GrantQueueRight

Grant a queue right to this group.  Takes a paramhash of which the elements
RightAppliesTo and RightName are important.

=cut

sub GrantQueueRight {
    
    my $self = shift;
    my %args = ( RightScope => 'Queue',
		 RightName => undef,
		 RightAppliesTo => undef,
		 PrincipalType => 'Group',
		 PrincipalId => $self->Id,
		 @_);
   
    require RT::ACE;


    #TODO +++ ACL this
    my $ace = new RT::ACE($self->CurrentUser);
    
    return ($ace->Create(%args));
}

# }}}

# {{{ GrantSystemRight

=head2 GrantSystemRight

Grant a system right to this group. 
The only element that's important to set is RightName.

=cut
sub GrantSystemRight {
    
    my $self = shift;
    my %args = ( RightScope => 'System',
		 RightName => undef,
		 RightAppliesTo => 0,
		 PrincipalType => 'Group',
		 PrincipalId => $self->Id,
		 @_);
   
    require RT::ACE;

    my $ace = new RT::ACE($self->CurrentUser);
    
    return ($ace->Create(%args));
}


# }}}


# {{{ sub _Set
sub _Set {
    my $self = shift;
    if ($self->CurrentUser->HasSystemRight('AdminGroups')) {
	
	$self->SUPER::_Set(@_);
    }
    else {
	return (undef);
    }

}
# }}}

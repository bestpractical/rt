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

# {{{ sub Load 

=head2 Load

Load a group object from the database. Takes a single argument.
If the argument is numerical, load by the column 'id'. Otherwise, load by
the "Name" column which is the group's textual name

=cut

sub Load  {
    my $self = shift;
    my $identifier = shift || return undef;
    
    #if it's an int, load by id. otherwise, load by name.
    if ($identifier !~ /\D/) {
	$self->SUPER::LoadById($identifier);
    }
    else {
	$self->LoadByCol("Name",$identifier);
    }
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
	$RT::Logger->warning($self->CurrentUser->Name ." Tried to create a group without permission.");
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
	use RT::GroupMembers;
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

    my $new_member_obj = new RT::User($self->CurrentUser);
    $new_member_obj->Load($new_member);
    
    unless ($new_member_obj->Id) {
	$RT::Logger->debug("Couldn't find user $new_member");
	return(0, "Couldn't find user");
    }	


    unless ($self->CurrentUser->HasSystemRight('AdminGroups')) {
        #User has no permission to be doing this
        return(0, "Permission Denied");
    }
    if ($self->HasMember($new_member_obj->Id)) {
        #User is already a member of this group. no need to add it
        return(0, "Group already has member");
    }
    
    my $member_object = new RT::GroupMember($self->CurrentUser);
    $member_object->Create( UserId => $new_member_obj->Id, 
			    GroupId => $self->id );
    return(1, "Member added");
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

Takes the user id of a member.
If the current user has apropriate rights,
removes that GroupMember from this group.

=cut

sub DeleteMember {
    my $self = shift;
    my $member = shift;

    my $member_user_obj = new RT::User($self->CurrentUser);
    $member_user_obj->Load($member);
    
    unless ($member_user_obj->Id) {
	$RT::Logger->debug("Couldn't find user $member");
	return(0, "User not found");
    }	


    unless ($self->CurrentUser->HasSystemRight('AdminGroups')) {
        #User has no permission to be doing this
        return(0,"Permission denied");
    }
    my $member_obj = new RT::GroupMember($self->CurrentUser);
    $member_obj->LoadByCols ( UserId => $member_user_obj->Id,
			      GroupId => $self->Id ) ||
				return(0, "Couldn't load member");  #couldn't load member object
    
    #If we couldn't load it, return undef.
    unless ($member_obj->Id()) {
	return (0, "Group has no such member");
    }	
    
    #Now that we've checked ACLs and sanity, delete the groupmember
    my $val = $member_obj->Delete();
    if ($val) {
	return ($val, "Member deleted");
    }
    else {
	return (0, "Member not deleted");
    }
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

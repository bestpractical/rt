# $Header: /raid/cvsroot/rt/lib/RT/Group.pm,v 1.3 2001/12/14 19:03:08 jesse Exp $
# Copyright 2000 Jesse Vincent <jesse@fsck.com>
# Released under the terms of the GNU Public License
#
#

=head1 NAME

  RT::Group - RT\'s group object

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


=begin testing

ok (require RT::Group);

ok (my $group = RT::Group->new($RT::SystemUser), "instantiated a group object");
ok (my ($id, $msg) = $group->Create( Name => 'TestGroup', Description => 'A test group',
                    Domain => 'System', Instance => ''), 'Created a new group');
ok ($id != 0, "Group id is $id");
ok ($group->Name eq 'TestGroup', "The group's name is 'TestGroup'");
my $ng = RT::Group->new($RT::SystemUser);

ok($ng->LoadSystemGroup('TestGroup'), "Loaded testgroup");
ok(($ng->id == $group->id), "Loaded the right group");
ok ($ng->AddMember('1' ), "Added a member to the group");
ok ($ng->AddMember('2' ), "Added a member to the group");
ok ($ng->AddMember('3' ), "Added a member to the group");

=end testing



=cut

no warnings qw(redefine);

use RT::GroupMembers;
use RT::Principals;
use RT::ACL;

# {{{ sub Load 

=head2 Load

Load a group object from the database. Takes a single argument.
If the argument is numerical, load by the column 'id'. Otherwise, load by
the "Name" column which is the group's textual name

=cut

sub Load {
    my $self       = shift;
    my $identifier = shift || return undef;

    #if it's an int, load by id. otherwise, load by name.
    if ( $identifier !~ /\D/ ) {
        $self->SUPER::LoadById($identifier);
    }
    else {
        $self->LoadByCol( "Name", $identifier );
    }
}

# }}}

# {{{ sub LoadSystemGroup 

=head2 LoadSystemGroup NAME

Loads a system group from the database. The only argument is
the group's name.


=cut

sub LoadSystemGroup {
    my $self       = shift;
    my $identifier = shift;

        $self->LoadByCols( "Domain" => 'System',
                           "Instance" => '',
                           "Name" => $identifier );
}

# }}}

# {{{ sub Create

=head2 Create

Takes a paramhash with named arguments: Name, Description.

TODO: fill in for 2.2

=cut

sub Create {
    my $self = shift;
    my %args = (
        Name        => undef,
        Description => undef,
        Domain      => undef,
        Instance    => undef,
        @_
    );

    # TODO: set up acls to deal based on what sort of group is being created
    unless ( $self->CurrentUser->HasSystemRight('AdminGroups') ) {
        $RT::Logger->warning( $self->CurrentUser->Name
              . " Tried to create a group without permission." );
        return ( 0, 'Permission Denied' );
    }

    $RT::Handle->BeginTransaction();

    my $id = $self->SUPER::Create(
        Name        => $args{'Name'},
        Description => $args{'Description'},
        Domain      => $args{'Domain'},
        Instance    => $args{'Instance'}
    );

    unless ($id) {
        return ( 0, $self->loc('Could not create group') );
    }

    # Groups deal with principal ids, rather than user ids.
    # When creating this user, set up a principal Id for it.
    my $principal    = RT::Principal->new( $self->CurrentUser );
    my $principal_id = $principal->Create(
        PrincipalType => 'Group',
        ObjectId      => $id
    );

    # If we couldn't create a principal Id, get the fuck out.
    unless ($principal_id) {
        $RT::Handle->Rollback();
        $self->crit(
            "Couldn't create a Principal on new user create. Strange thi
ngs are afoot at the circle K" );
        return ( 0, $self->loc('Could not create group') );
    }

    $RT::Handle->Commit();
    return ( $id, $self->loc("Group created") );
}

# }}}

# {{{ sub Delete

=head2 Delete

Delete this object

=cut

sub Delete {
    my $self = shift;

    unless ( $self->CurrentUser->HasSystemRight('AdminGroups') ) {
        return ( 0, 'Permission Denied' );
    }

    return ( $self->SUPER::Delete(@_) );
}

# }}}

# {{{ MembersObj

=head2 MembersObj

Returns an RT::GroupMembers object of this group's members.

=cut

sub MembersObj {
    my $self = shift;
    unless ( defined $self->{'members_obj'} ) {
        $self->{'members_obj'} = new RT::GroupMembers( $self->CurrentUser );

        #If we don't have rights, don't include any results
        $self->{'members_obj'}->LimitToGroup( $self->id );

    }
    return ( $self->{'members_obj'} );

}

# }}}

# {{{ AddMember

=head2 AddMember PRINCIPAL_ID

AddMember adds a principal to this group.  It takes a single principal id.
Returns a two value array. the first value is true on successful 
addition or 0 on failure.  The second value is a textual status msg.

R


=cut

sub AddMember {
    my $self       = shift;
    my $new_member = shift;

    my $new_member_obj = RT::Principal->new( $self->CurrentUser );
    $new_member_obj->Load($new_member);

    unless ( $self->CurrentUser->HasSystemRight('AdminGroups') ) {

        #User has no permission to be doing this
        return ( 0, $self->loc("Permission Denied") );
    }

    unless ( $new_member_obj->Id ) {
        $RT::Logger->debug("Couldn't find that principal");
        return ( 0, $self->loc("Couldn't find that principal") );
    }

    if ( $self->HasMember( $new_member_obj->Id ) ) {

        #User is already a member of this group. no need to add it
        return ( 0, $self->loc("Group already has member") );
    }

    my $member_object = RT::GroupMember->new( $self->CurrentUser );
    $member_object->Create(
        Member => $new_member_obj,
        Group => $self->PrincipalObj
    );
    return ( 1, "Member added" );
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
    my $self    = shift;
    my $user_id = shift;

    #Try to cons up a member object using "LoadByCols"
    #TODO: port this to use a principal object directly. requires
    # tracking down uses.

    my $user = RT::User->new($RT::SystemUser);
    $user->Load($user_id);
    my $princ_id = $user->PrincipalId;

    my $member_obj = RT::GroupMember->new( $self->CurrentUser );
    $member_obj->LoadByCols( MemberId => $princ_id, GroupId => $self->id );

    #If we have a member object
    if ( defined $member_obj->id ) {
        return ( $member_obj->id );
    }

    #If Load returns no objects, we have an undef id. 
    else {
        return (undef);
    }
}

# }}}

# {{{ DeleteMember

=head2 DeleteMember

Takes the user id of a member.
If the current user has apropriate rights,
removes that GroupMember from this group.
Returns a two value array. the first value is true on successful 
addition or 0 on failure.  The second value is a textual status msg.

=cut

sub DeleteMember {
    my $self   = shift;
    my $member = shift;

    unless ( $self->CurrentUser->HasSystemRight('AdminGroups') ) {

        #User has no permission to be doing this
        return ( 0, "Permission Denied" );
    }

    my $member_user_obj = RT::User->new( $self->CurrentUser );
    $member_user_obj->Load($member);

    unless ( $member_user_obj->Id ) {
        $RT::Logger->debug("Couldn't find user $member");
        return ( 0, "User not found" );
    }

    my $member_obj = new RT::GroupMember( $self->CurrentUser );
    unless (
        $member_obj->LoadByCols(
            MemberId  => $member_user_obj->PrincipalId,
            GroupId => $self->Id
        )
      )
    {
        return ( 0, "Couldn\'t load member" );    #couldn\'t load member object
    }

    #If we couldn't load it, return undef.
    unless ( $member_obj->Id() ) {
        return ( 0, "Group has no such member" );
    }

    #Now that we've checked ACLs and sanity, delete the groupmember
    my $val = $member_obj->Delete();
    if ($val) {
        return ( $val, "Member deleted" );
    }
    else {
        return ( 0, "Member not deleted" );
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
    my %args = (
        RightScope     => 'Queue',
        RightName      => undef,
        RightAppliesTo => undef,
        PrincipalType  => 'Group',
        PrincipalId    => $self->PrincipalId,
        @_
    );

    #ACLs get checked in ACE.pm

    my $ace = new RT::ACE( $self->CurrentUser );

    return ( $ace->Create(%args) );
}

# }}}

# {{{ GrantSystemRight

=head2 GrantSystemRight

Grant a system right to this group. 
The only element that's important to set is RightName.

=cut

sub GrantSystemRight {

    my $self = shift;
    my %args = (
        RightScope     => 'System',
        RightName      => undef,
        RightAppliesTo => 0,
        PrincipalType  => 'Group',
        PrincipalId    => $self->PrincipalId,
        @_
    );

    # ACLS get checked in ACE.pm

    my $ace = new RT::ACE( $self->CurrentUser );
    return ( $ace->Create(%args) );
}

# }}}

# {{{ sub _Set
sub _Set {
    my $self = shift;

    unless ( $self->CurrentUser->HasSystemRight('AdminGroups') ) {
        return ( 0, 'Permission Denied' );
    }

    return ( $self->SUPER::_Set(@_) );

}

# }}}

# }}}

# {{{ Principal related routines

=head2 PrincipalObj 

Returns the principal object for this user. returns an empty RT::Principal
if there's no principal object matching this user. 
The response is cached. PrincipalObj should never ever change.

=begin testing

ok(my $u = RT::Group->new($RT::SystemUser));
ok($u->Load(4), "Loaded the first user");
ok($u->PrincipalObj->ObjectId == 4, "user 4 is the fourth principal");
ok($u->PrincipalObj->PrincipalType eq 'Group' , "Principal 4 is a group");

=end testing

=cut


sub PrincipalObj {
    my $self = shift;
    unless ($self->{'PrincipalObj'} &&
            ($self->{'PrincipalObj'}->ObjectId == $self->Id) &&
            ($self->{'PrincipalObj'}->PrincipalType eq 'Group')) {

            $self->{'PrincipalObj'} = RT::Principal->new($self->CurrentUser);
            $self->{'PrincipalObj'}->LoadByCols('ObjectId' => $self->Id,
                                                'PrincipalType' => 'Group') ;
            }
    return($self->{'PrincipalObj'});
}


=head2 PrincipalId  

Returns this user's PrincipalId

=cut

sub PrincipalId {
    my $self = shift;
    return $self->PrincipalObj->Id;
}

# }}}
1;


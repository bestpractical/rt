# $Header: /raid/cvsroot/rt/lib/RT/Group.pm,v 1.3 2001/12/14 19:03:08 jesse Exp $
# Copyright 1996-2002 Jesse Vincent <jesse@bestpractical.com>
# Released under the terms of version 2 of the GNU Public License

=head1 NAME

  RT::Group - RT\'s group object

=head1 SYNOPSIS

  use RT::Group;
my $group = new RT::Group($CurrentUser);

=head1 DESCRIPTION

An RT group object.

=head1 AUTHOR

Jesse Vincent, jesse@bestpractical.com

=head1 SEE ALSO

RT

=head1 METHODS


=begin testing

# {{{ Tests
ok (require RT::Group);

ok (my $group = RT::Group->new($RT::SystemUser), "instantiated a group object");
ok (my ($id, $msg) = $group->CreateUserDefinedGroup( Name => 'TestGroup', Description => 'A test group',
                    ), 'Created a new group');
ok ($id != 0, "Group id is $id");
ok ($group->Name eq 'TestGroup', "The group's name is 'TestGroup'");
my $ng = RT::Group->new($RT::SystemUser);

ok($ng->LoadUserDefinedGroup('TestGroup'), "Loaded testgroup");
ok(($ng->id == $group->id), "Loaded the right group");
ok ($ng->AddMember('1'), "Added a member to the group");
ok ($ng->AddMember('2' ), "Added a member to the group");
ok ($ng->AddMember('3' ), "Added a member to the group");

# Group 1 now has members 1, 2 ,3

my $group_2 = RT::Group->new($RT::SystemUser);
ok (my ($id_2, $msg_2) = $group_2->CreateUserDefinedGroup( Name => 'TestGroup2', Description => 'A second test group'), , 'Created a new group');
ok ($id_2 != 0, "Created group 2 ok");
ok ($group_2->AddMember($ng->PrincipalId), "Made TestGroup a member of testgroup2");
ok ($group_2->AddMember('1' ), "Added  member RT_System to the group TestGroup2");

# Group 2 how has 1, g1->{1, 2,3}

my $group_3 = RT::Group->new($RT::SystemUser);
ok (($id_3, $msg) = $group_3->CreateUserDefinedGroup( Name => 'TestGroup3', Description => 'A second test group'), 'Created a new group');
ok ($id_3 != 0, "Created group 3 ok - $msg");
ok ($group_3->AddMember($group_2->PrincipalId), "Made TestGroup a member of testgroup2");

# g3 now has g2->{1, g1->{1,2,3}}

my $principal_1 = RT::Principal->new($RT::SystemUser);
$principal_1->Load('1');

my $principal_2 = RT::Principal->new($RT::SystemUser);
$principal_2->Load('2');

ok ($group_3->AddMember('1' ), "Added  member RT_System to the group TestGroup2");

# g3 now has 1, g2->{1, g1->{1,2,3}}

ok($group_3->HasMember($principal_2) == undef, "group 3 doesn't have member 2");
ok($group_3->HasMemberRecursively($principal_2), "group 3 has member 2 recursively");

ok($ng->HasMember($principal_2) , "group ".$ng->Id." has member 2");
my ($delid , $delmsg) =$ng->DeleteMember($principal_2->Id);
ok ($delid !=0, "Sucessfully deleted it-".$delid."-".$delmsg);

#Gotta reload the group objects, since we've been messing with various internals.
# we shouldn't need to do this.
#$ng->LoadUserDefinedGroup('TestGroup');
#$group_2->LoadUserDefinedGroup('TestGroup2');
#$group_3->LoadUserDefinedGroup('TestGroup');

# G1 now has 1, 3
# Group 2 how has 1, g1->{1, 3}
# g3 now has  1, g2->{1, g1->{1, 3}}

ok(!$ng->HasMember($principal_2)  , "group ".$ng->Id." no longer has member 2");
ok($group_3->HasMemberRecursively($principal_2) == undef, "group 3 doesn't have member 2");
ok($group_2->HasMemberRecursively($principal_2) == undef, "group 2 doesn't have member 2");
ok($ng->HasMember($principal_2) == undef, "group 1 doesn't have member 2");;
ok($group_3->HasMemberRecursively($principal_2) == undef, "group 3 has member 2 recursively");

# }}}

=end testing



=cut

no warnings qw(redefine);

use RT::GroupMembers;
use RT::Principals;
use RT::ACL;

# {{{ sub Load 

=head2 Load ID

Load a group object from the database. Takes a single argument.
If the argument is numerical, load by the column 'id'. Otherwise, 
complain and return.

=cut

sub Load {
    my $self       = shift;
    my $identifier = shift || return undef;

    #if it's an int, load by id. otherwise, load by name.
    if ( $identifier !~ /\D/ ) {
        $self->SUPER::LoadById($identifier);
    }
    else {
        $RT::Logger->crit("Group -> Load called with a bogus argument");
        return undef;
    }
}

# }}}

# {{{ sub LoadUserDefinedGroup 

=head2 LoadUserDefinedGroup NAME

Loads a system group from the database. The only argument is
the group's name.


=cut

sub LoadUserDefinedGroup {
    my $self       = shift;
    my $identifier = shift;

        $self->LoadByCols( "Domain" => 'UserDefined',
                           "Name" => $identifier );
}

# }}}

# {{{ sub LoadPersonalGroup 

=head2 LoadPersonalGroup {Name => NAME, User => USERID}

Loads a system group from the database. The only argument is
the group's name.


=cut

sub LoadPersonalGroup {
    my $self       = shift;
    my %args =  (   Name => undef,
                    User => undef,
                    @_);

        $self->LoadByCols( "Domain" => 'Personal',
                           "Instance" => $args{'User'},
                           "Type" => '',
                           "Name" => $args{'Name'} );
}

# }}}

# {{{ sub LoadSystemInternalGroup 

=head2 LoadSystemInternalGroup NAME

Loads a Pseudo group from the database. The only argument is
the group's name.


=cut

sub LoadSystemInternalGroup {
    my $self       = shift;
    my $identifier = shift;

        $self->LoadByCols( "Domain" => 'SystemInternal',
                           "Instance" => '',
                           "Name" => '',
                           "Type" => $identifier );
}

# }}}

# {{{ sub LoadTicketGroup 

=head2 LoadTicketGroup  { Ticket => TICKET_ID, Type => TYPE }

Loads a ticket group from the database. 

Takes a param hash with 2 parameters:

    Ticket is the TicketId we're curious about
    Type is the type of Group we're trying to load: 
        Requestor, Cc, AdminCc, Owner

=cut

sub LoadTicketGroup {
    my $self       = shift;
    my %args = (Ticket => undef,
                Type => undef,
                @_);
        $self->LoadByCols( Domain => 'TicketRole',
                           Instance =>$args{'Ticket'}, 
                           Type => $args{'Type'}
                           );
}

# }}}

# {{{ sub LoadQueueGroup 

=head2 LoadQueueGroup  { Queue => Queue_ID, Type => TYPE }

Loads a Queue group from the database. 

Takes a param hash with 2 parameters:

    Queue is the QueueId we're curious about
    Type is the type of Group we're trying to load: 
        Requestor, Cc, AdminCc, Owner

=cut

sub LoadQueueGroup {
    my $self       = shift;
    my %args = (Queue => undef,
                Type => undef,
                @_);
        $self->LoadByCols( Domain => 'QueueRole',
                           Instance =>$args{'Queue'}, 
                           Type => $args{'Type'}
                           );
}

# }}}

# {{{ sub Create
=head2 Create

You need to specify what sort of group you're creating by calling one of the other
Create_____ routines.

=cut

sub Create {
    my $self = shift;
    $RT::Logger->crit("Someone called RT::Group->Create. this method does not exist. someone's being evil");
    return(0,$self->loc('Permission Denied'));
}

# }}}

# {{{ sub _Create

=head2 _Create

Takes a paramhash with named arguments: Name, Description.

TODO: fill in for 2.2

=cut

sub _Create {
    my $self = shift;
    my %args = (
        Name        => undef,
        Description => undef,
        Domain      => undef,
        Type        => undef,
        Instance    => undef,
        @_
    );

    $RT::Handle->BeginTransaction();

    my $id = $self->SUPER::Create(
        Name        => $args{'Name'},
        Description => $args{'Description'},
        Type        => $args{'Type'},
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

# {{{ CreateUserDefinedGroup

=head2 CreateUserDefinedGroup { Name => "name", Description => "Description"}

A helper subroutine which creates a system group 

=cut

sub CreateUserDefinedGroup {
    my $self = shift;

    unless ( $self->CurrentUser->HasSystemRight('AdminGroups') ) {
        $RT::Logger->warning( $self->CurrentUser->Name
              . " Tried to create a group without permission." );
        return ( 0, $self->loc('Permission Denied') );
    }

    return($self->_Create( Domain => 'UserDefined', Type => '', Instance => '', @_));
}

# }}}

# {{{ CreatePersonalGroup

=head2 CreatePersonalGroup { Name => "name", Description => "Description"}

A helper subroutine which creates a personal group. Generally,
personal groups are used for ACL delegation and adding to ticket roles


=cut

sub CreatePersonalGroup {
    my $self = shift;

    unless ( $self->CurrentUser->HasSystemRight('AdminGroups') ) {
        $RT::Logger->warning( $self->CurrentUser->Name
              . " Tried to create a group without permission." );
        return ( 0, $self->loc('Permission Denied') );
    }
    return($self->_Create( Domain => 'Personal', Type => '', Instance => '', @_));
}

# }}}

# {{{ CreateRoleGroup 

=head2 CreateRoleGroup { Domain => DOMAIN, Type =>  TYPE, Instance => ID }

A helper subroutine which creates a  ticket group. (What RT 2.0 called Ticket watchers)
Type is one of ( "Requestor" || "Cc" || "AdminCc" || "Owner") 
Domain is one of (Ticket || Queue)
Instance is the id of the ticket or queue in question

This routine expects to be called from {Ticket||Queue}->CreateTicketGroups _inside of a transaction_

=cut

sub CreateRoleGroup {
    my $self = shift;
    my %args = ( Instance => undef,
                 Type => undef,
                 Domain => undef,
                 @_);
    unless ($args{'Type'} =~ /^(?:Cc|AdminCc|Requestor|Owner)$/) {
        return  (0, $self->loc("Invalid Group Type"));
    }

    return($self->_Create( Domain => $args{'Domain'}, Instance => $args{'Instance'} , Type => $args{'Type'}));
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

# {{{ DeepMembersObj

=head2 DeepMembersObj

Returns an RT::CachedGroupMembers object of this group's members.

=cut

sub DeepMembersObj {
    my $self = shift;
    my $members_obj = RT::CachedGroupMembers->new( $self->CurrentUser );

    #If we don't have rights, don't include any results
    # TODO XXX  WHY IS THERE NO ACL CHECK HERE?
    $members_obj->LimitToMembersOfGroup( $self->PrincipalId );

    return ( $members_obj );

}

# }}}

# {{{ UserMembersObj

=head2 UserMembersObj

Returns an RT::Users object of this group's members, including
all members of subgroups

=cut

sub UserMembersObj {
    my $self = shift;

    my $users = RT::Users->new($self->CurrentUser);

    #If we don't have rights, don't include any results
    # TODO XXX  WHY IS THERE NO ACL CHECK HERE?

    my $principals = $users->NewAlias('Principals');

    $users->Join(ALIAS1 => 'main', FIELD1 => 'id',
                 ALIAS2 => $principals, FIELD2 => 'ObjectId');
    $users->Limit(ALIAS =>$principals,
                  FIELD => 'PrincipalType', OPERATOR => '=', VALUE => 'User');

    my $cached_members = $users->NewAlias('CachedGroupMembers');
    $users->Join(ALIAS1 => $cached_members, FIELD1 => 'MemberId',
                 ALIAS2 => $principals, FIELD2 => 'id');
    $users->Limit(ALIAS => $cached_members, 
                  FIELD => 'GroupId',
                  OPERATOR => '=',
                  VALUE => $self->PrincipalId);


    return ( $users);

}

# }}}

# {{{ MembersObj

=head2 MembersObj

Returns an RT::CachedGroupMembers object of this group's members.

=cut

sub MembersObj {
    my $self = shift;
    my $members_obj = RT::GroupMembers->new( $self->CurrentUser );

    #If we don't have rights, don't include any results
    # TODO XXX  WHY IS THERE NO ACL CHECK HERE?
    $members_obj->LimitToMembersOfGroup( $self->PrincipalId );

    return ( $members_obj );

}

# }}}

# {{{ MemberEmailAddresses

=head2 MemberEmailAddresses

Returns an array of the email addresses of all of this group's members


=cut

sub MemberEmailAddresses {
    my $self = shift;

    my %addresses;
    my $members = $self->UserMembersObj();
    while (my $member = $members->Next) {
        $addresses{$member->EmailAddress} = 1;
    }
    return(sort keys %addresses);
}

# }}}

# {{{ MemberEmailAddressesAsString

=head2 MemberEmailAddressesAsString

Returns a comma delimited string of the email addresses of all users 
who are members of this group.

=cut


sub MemberEmailAddressesAsString {
    my $self = shift;
    return (join(', ', $self->MemberEmailAddresses));
}

# }}}

# {{{ AddMember

=head2 AddMember PRINCIPAL_ID

AddMember adds a principal to this group.  It takes a single principal id.
Returns a two value array. the first value is true on successful 
addition or 0 on failure.  The second value is a textual status msg.

=cut

sub AddMember {
    my $self       = shift;
    my $new_member = shift;


    unless ($self->Id) {
        $RT::Logger->err("Attempting to add a member to a group which wasn't loaded. 'oops'");
        return(0, $self->loc("Group not found"));
    }

    $RT::Logger->debug("About to add $new_member to group".$self->id);

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

    if ( $self->HasMember( $new_member_obj ) ) {

        #User is already a member of this group. no need to add it
        return ( 0, $self->loc("Group already has member") );
    }
    if ( $new_member_obj->IsGroup &&
         $new_member_obj->Object->HasMemberRecursively($self->PrincipalObj) ) {

        #This group can't be made to be a member of itself
        return ( 0, $self->loc("Groups can't be members of their members"));
    }


    my $member_object = RT::GroupMember->new( $self->CurrentUser );
    my $id = $member_object->Create(
        Member => $new_member_obj,
        Group => $self->PrincipalObj
    );
    if ($id) {
        return ( 1, $self->loc("Member added") );
    }
    else {
        return(0, $self->loc("Couldn't add member to group"));
    }
}
# }}}

# {{{ HasMember

=head2 HasMember RT::Principal

Takes an RT::Principal object returns a GroupMember Id if that user is a 
member of this group.
Returns undef if the user isn't a member of the group or if the current
user doesn't have permission to find out. Arguably, it should differentiate
between ACL failure and non membership.

=cut

sub HasMember {
    my $self    = shift;
    my $principal = shift;


    unless (UNIVERSAL::isa($principal,'RT::Principal')) {
        $RT::Logger->crit("Group::HasMember was called with an argument that".
                          "isn't an RT::Principal. It's $principal");
        return(undef);
    }

    my $member_obj = RT::GroupMember->new( $self->CurrentUser );
    $member_obj->LoadByCols( MemberId => $principal->id, 
                             GroupId => $self->PrincipalId );

    #If we have a member object
    if ( defined $member_obj->id ) {
        return ( $member_obj->id );
    }

    #If Load returns no objects, we have an undef id. 
    else {
        #$RT::Logger->debug($self." does not contain principal ".$principal->id);
        return (undef);
    }
}

# }}}

# {{{ HasMemberRecursively

=head2 HasMemberRecursively RT::Principal

Takes an RT::Principal object and returns true if that user is a member of 
this group.
Returns undef if the user isn't a member of the group or if the current
user doesn't have permission to find out. Arguably, it should differentiate
between ACL failure and non membership.

=cut

sub HasMemberRecursively {
    my $self    = shift;
    my $principal = shift;

    unless (UNIVERSAL::isa($principal,'RT::Principal')) {
        $RT::Logger->crit("Group::HasMemberRecursively was called with an argument that".
                          "isn't an RT::Principal. It's $principal");
        return(undef);
    }

    my $member_obj = RT::CachedGroupMember->new( $self->CurrentUser );
    $member_obj->LoadByCols( MemberId => $principal->Id,
                             GroupId => $self->PrincipalId );

    #If we have a member object
    if ( defined $member_obj->id ) {
        return ( 1);
    }

    #If Load returns no objects, we have an undef id. 
    else {
        return (undef);
    }
}

# }}}

# {{{ DeleteMember

=head2 DeleteMember PRINCIPAL_ID

Takes the user id of a member.
If the current user has apropriate rights,
removes that GroupMember from this group.
Returns a two value array. the first value is true on successful 
addition or 0 on failure.  The second value is a textual status msg.

=cut

sub DeleteMember {
    my $self   = shift;
    my $member_id = shift;

    #$RT::Logger->debug("About to try to delete principal $member_id  as a".  "member of group ".$self->Id);

    unless ( $self->CurrentUser->HasSystemRight('AdminGroups') ) {
        return ( 0, $self->loc("Permission Denied"));
    }

    my $member_obj =  RT::GroupMember->new( $self->CurrentUser );
    
    $member_obj->LoadByCols( MemberId  => $member_id,
                             GroupId => $self->PrincipalId);

    #$RT::Logger->debug("Loaded the RT::GroupMember object ".$member_obj->id);

    #If we couldn't load it, return undef.
    unless ( $member_obj->Id() ) {
        $RT::Logger->debug("Group has no member with that id");
        return ( 0,$self->loc( "Group has no such member" ));
    }

    #Now that we've checked ACLs and sanity, delete the groupmember
    my $val = $member_obj->Delete();

    if ($val) {
        $RT::Logger->debug("Deleted group ".$self->Id." member ". $member_id);
     
        return ( $val, $self->loc("Member deleted") );
    }
    else {
        $RT::Logger->debug("Failed to delete group ".$self->Id." member ". $member_id);
        return ( 0, $self->loc("Member not deleted" ));
    }
}

# }}}

# {{{ ACL Related routines

# {{{ sub _Set
sub _Set {
    my $self = shift;

    unless ( $self->CurrentUser->HasSystemRight('AdminGroups') ) {
        return ( 0, 'Permission Denied' );
    }

    return ( $self->SUPER::_Set(@_) );

}

# }}}


=item CurrentUserHasRight RIGHTNAME

Returns true if the current user has the specified right for this group

Per-Group rights are:
    AdminGroup
    AdminGroupMembership
    ModifyOwnMembership 
   
System rights is all per-group rights and:
    CreatePersonalGroup
    CreateUserDefinedGroup

    TODO: we don't deal with membership visibility yet

=cut


sub CurrentUserHasRight {
    my $self = shift;
    my $right = shift;

    if ($self->CurrentUser->HasGroupRight( Group => $self->Id,
                                           Right => $right )) {

        return(1);
   }
    else {
        return(undef);
    }

}

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


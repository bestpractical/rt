
use strict;
use warnings;
use RT::Test; use Test::More; 
plan tests => 38;
use RT;



{

# {{{ Tests
ok (require RT::Model::Group);

ok (my $group = RT::Model::Group->new(RT->SystemUser), "instantiated a group object");
ok (my ($id, $msg) = $group->create_userDefinedGroup( Name => 'TestGroup', Description => 'A test group',
                    ), 'Created a new group');
isnt ($id , 0, "Group id is $id");
is ($group->Name , 'TestGroup', "The group's name is 'TestGroup'");
my $ng = RT::Model::Group->new(RT->SystemUser);

ok($ng->loadUserDefinedGroup('TestGroup'), "Loaded testgroup");
is($ng->id , $group->id, "Loaded the right group");


ok (($id,$msg) = $ng->AddMember('1'), "Added a member to the group");
ok($id, $msg);
ok (($id,$msg) = $ng->AddMember('2' ), "Added a member to the group");
ok($id, $msg);
ok (($id,$msg) = $ng->AddMember('3' ), "Added a member to the group");
ok($id, $msg);

# Group 1 now has members 1, 2 ,3

my $group_2 = RT::Model::Group->new(RT->SystemUser);
ok (my ($id_2, $msg_2) = $group_2->create_userDefinedGroup( Name => 'TestGroup2', Description => 'A second test group'), , 'Created a new group');
isnt ($id_2 , 0, "Created group 2 ok- $msg_2 ");
ok (($id,$msg) = $group_2->AddMember($ng->PrincipalId), "Made TestGroup a member of testgroup2");
ok($id, $msg);
ok (($id,$msg) = $group_2->AddMember('1' ), "Added  member RT_System to the group TestGroup2");
ok($id, $msg);

# Group 2 how has 1, g1->{1, 2,3}

my $group_3 = RT::Model::Group->new(RT->SystemUser);
ok (my ($id_3, $msg_3) = $group_3->create_userDefinedGroup( Name => 'TestGroup3', Description => 'A second test group'), 'Created a new group');
isnt ($id_3 , 0, "Created group 3 ok - $msg_3");
ok (($id,$msg) =$group_3->AddMember($group_2->PrincipalId), "Made TestGroup a member of testgroup2");
ok($id, $msg);

# g3 now has g2->{1, g1->{1,2,3}}

my $principal_1 = RT::Model::Principal->new(RT->SystemUser);
$principal_1->load('1');

my $principal_2 = RT::Model::Principal->new(RT->SystemUser);
$principal_2->load('2');

ok (($id,$msg) = $group_3->AddMember('1' ), "Added  member RT_System to the group TestGroup2");
ok($id, $msg);

# g3 now has 1, g2->{1, g1->{1,2,3}}

is($group_3->has_member($principal_2), undef, "group 3 doesn't have member 2");
ok($group_3->has_member_recursively($principal_2), "group 3 has member 2 recursively");
ok($ng->has_member($principal_2) , "group ".$ng->id." has member 2");
my ($delid , $delmsg) =$ng->delete_member($principal_2->id);
isnt ($delid ,0, "Sucessfully deleted it-".$delid."-".$delmsg);

#Gotta reload the group objects, since we've been messing with various internals.
# we shouldn't need to do this.
#$ng->loadUserDefinedGroup('TestGroup');
#$group_2->loadUserDefinedGroup('TestGroup2');
#$group_3->loadUserDefinedGroup('TestGroup');

# G1 now has 1, 3
# Group 2 how has 1, g1->{1, 3}
# g3 now has  1, g2->{1, g1->{1, 3}}

ok(!$ng->has_member($principal_2)  , "group ".$ng->id." no longer has member 2");
is($group_3->has_member_recursively($principal_2), undef, "group 3 doesn't have member 2");
is($group_2->has_member_recursively($principal_2), undef, "group 2 doesn't have member 2");
is($ng->has_member($principal_2), undef, "group 1 doesn't have member 2");;
is($group_3->has_member_recursively($principal_2), undef, "group 3 has member 2 recursively");

# }}}


}

{

ok(my $u = RT::Model::Group->new(RT->SystemUser));
ok($u->load(4), "Loaded the first user");
is($u->PrincipalObj->ObjectId , 4, "user 4 is the fourth principal");
is($u->PrincipalObj->PrincipalType , 'Group' , "Principal 4 is a group");


}

1;

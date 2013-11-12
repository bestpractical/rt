
use strict;
use warnings;
use RT;
use RT::Test nodata => 1, tests => undef;


{

ok (require RT::Group);

ok (my $group = RT::Group->new(RT->SystemUser), "instantiated a group object");
ok (my ($id, $msg) = $group->CreateUserDefinedGroup( Name => 'TestGroup', Description => 'A test group',
                    ), 'Created a new group');
isnt ($id , 0, "Group id is $id");
is ($group->Name , 'TestGroup', "The group's name is 'TestGroup'");
my $ng = RT::Group->new(RT->SystemUser);

ok($ng->LoadUserDefinedGroup('TestGroup'), "Loaded testgroup");
is($ng->id , $group->id, "Loaded the right group");


my @users = (undef);
for my $number (1..3) {
    my $user = RT::User->new(RT->SystemUser);
    $user->Create( Name => "User $number" );
    push @users, $user->id;
}


ok (($id,$msg) = $ng->AddMember( $users[1] ), "Added a member to the group");
ok($id, $msg);
ok (($id,$msg) = $ng->AddMember( $users[2] ), "Added a member to the group");
ok($id, $msg);
ok (($id,$msg) = $ng->AddMember( $users[3] ), "Added a member to the group");
ok($id, $msg);

# Group 1 now has members 1, 2 ,3

my $group_2 = RT::Group->new(RT->SystemUser);
ok (my ($id_2, $msg_2) = $group_2->CreateUserDefinedGroup( Name => 'TestGroup2', Description => 'A second test group'), , 'Created a new group');
isnt ($id_2 , 0, "Created group 2 ok- $msg_2 ");
ok (($id,$msg) = $group_2->AddMember($ng->PrincipalId), "Made TestGroup a member of testgroup2");
ok($id, $msg);
ok (($id,$msg) = $group_2->AddMember( $users[1] ), "Added  member User 1 to the group TestGroup2");
ok($id, $msg);

# Group 2 how has 1, g1->{1, 2,3}

my $group_3 = RT::Group->new(RT->SystemUser);
ok (my ($id_3, $msg_3) = $group_3->CreateUserDefinedGroup( Name => 'TestGroup3', Description => 'A second test group'), 'Created a new group');
isnt ($id_3 , 0, "Created group 3 ok - $msg_3");
ok (($id,$msg) =$group_3->AddMember($group_2->PrincipalId), "Made TestGroup a member of testgroup2");
ok($id, $msg);

# g3 now has g2->{1, g1->{1,2,3}}

my $principal_1 = RT::Principal->new(RT->SystemUser);
$principal_1->Load( $users[1] );

my $principal_2 = RT::Principal->new(RT->SystemUser);
$principal_2->Load( $users[2] );

ok (($id,$msg) = $group_3->AddMember( $users[1] ), "Added  member User 1 to the group TestGroup2");
ok($id, $msg);

# g3 now has 1, g2->{1, g1->{1,2,3}}

is($group_3->HasMember($principal_2), undef, "group 3 doesn't have member 2");
ok($group_3->HasMemberRecursively($principal_2), "group 3 has member 2 recursively");
ok($ng->HasMember($principal_2) , "group ".$ng->Id." has member 2");
my ($delid , $delmsg) =$ng->DeleteMember($principal_2->Id);
isnt ($delid ,0, "Sucessfully deleted it-".$delid."-".$delmsg);

#Gotta reload the group objects, since we've been messing with various internals.
# we shouldn't need to do this.
#$ng->LoadUserDefinedGroup('TestGroup');
#$group_2->LoadUserDefinedGroup('TestGroup2');
#$group_3->LoadUserDefinedGroup('TestGroup');

# G1 now has 1, 3
# Group 2 how has 1, g1->{1, 3}
# g3 now has  1, g2->{1, g1->{1, 3}}

ok(!$ng->HasMember($principal_2)  , "group ".$ng->Id." no longer has member 2");
is($group_3->HasMemberRecursively($principal_2), undef, "group 3 doesn't have member 2");
is($group_2->HasMemberRecursively($principal_2), undef, "group 2 doesn't have member 2");
is($ng->HasMember($principal_2), undef, "group 1 doesn't have member 2");
is($group_3->HasMemberRecursively($principal_2), undef, "group 3 has member 2 recursively");



}

{

ok(my $u = RT::Group->new(RT->SystemUser));
ok($u->Load(4), "Loaded the first user");
is($u->PrincipalObj->id , 4, "user 4 is the fourth principal");
is($u->PrincipalObj->PrincipalType , 'Group' , "Principal 4 is a group");


}

{
    my $u = RT::Group->new(RT->SystemUser);
    $u->LoadUserDefinedGroup('TestGroup');
    ok( $u->id, 'loaded TestGroup' );
    ok( $u->SetName('testgroup'), 'rename to lower cased version: testgroup' );
    ok( $u->SetName('TestGroup'), 'rename back' );

    my $u2 = RT::Group->new( RT->SystemUser );
    my ( $id, $msg ) = $u2->CreateUserDefinedGroup( Name => 'TestGroup' );
    ok( !$id, "can't create duplicated group: $msg" );
    ( $id, $msg ) = $u2->CreateUserDefinedGroup( Name => 'testgroup' );
    ok( !$id, "can't create duplicated group even case is different: $msg" );
}

done_testing;

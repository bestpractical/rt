
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

    my $group = RT::Group->new( RT->SystemUser );
    ( $id, $msg ) = $group->CreateUserDefinedGroup( Name => ' Engineers ' );
    ok( $group->id, 'loaded Engineers' );
    is( $group->Name, 'Engineers', 'leading/trailing spaces are removed on create' );
    ( my $ret, $msg ) = $group->SetName(' Engineers ');
    ok( !$ret, "Can't update to the same name but with leading/trailing spaces" );
    ( $ret, $msg ) = $group->SetName(' Coders ');
    ok( $ret, "Update to the a new name" );
    is( $group->Name, 'Coders', 'leading/trailing spaces are removed on update' );

    $group = RT::Group->new( RT->SystemUser );
    ( $id, $msg ) = $group->CreateUserDefinedGroup( Name => ' QA Engineers ' );
    ok( $group->id, 'loaded QA Engineers' );
    is( $group->Name, 'QA Engineers', 'leading/trailing spaces are removed on create with multiple word name' );
    ( $ret, $msg ) = $group->SetName(' QA Engineers ');
    ok( !$ret, "Can't update to the same name but with leading/trailing spaces" );
    ( $ret, $msg ) = $group->SetName(' Coders and Testers ');
    ok( $ret, "Update to the a new name" );
    is( $group->Name, 'Coders and Testers', 'leading/trailing spaces are removed on update with multiple word name' );
}

diag "Ticket role group members";
{
    RT::Test->load_or_create_queue( Name => 'General' );
    my $ticket    = RT::Test->create_ticket( Queue => 'General', Subject => 'test ticket role group' );
    my $admincc   = $ticket->RoleGroup('AdminCc');
    my $delegates = RT::Test->load_or_create_group('delegates');
    my $core      = RT::Test->load_or_create_group('core team');
    my $alice     = RT::Test->load_or_create_user( Name => 'alice' );
    my $bob       = RT::Test->load_or_create_user( Name => 'bob' );

    ok( $admincc->AddMember( $delegates->PrincipalId ), 'Add delegates to AdminCc' );
    ok( $delegates->AddMember( $core->PrincipalId ),    'Add core team to delegates' );
    ok( $delegates->AddMember( $bob->PrincipalId ),     'Add bob to delegates' );
    ok( $core->AddMember( $alice->PrincipalId ),        'Add alice to core team' );

    ok( $admincc->HasMember( $delegates->PrincipalId ),        'AdminCc has direct member of delegates' );
    ok( !$admincc->HasMember( $core->PrincipalId ),            "AdminCc doesn't have member of core" );
    ok( !$admincc->HasMember( $bob->PrincipalId ),             "AdminCc doesn't have member of bob" );
    ok( !$admincc->HasMember( $alice->PrincipalId ),           "AdminCc doesn't have member of bob" );
    ok( $admincc->HasMemberRecursively( $core->PrincipalId ),  "AdminCc recursively has member of core" );
    ok( $admincc->HasMemberRecursively( $bob->PrincipalId ),   "AdminCc recursively has member of bob" );
    ok( $admincc->HasMemberRecursively( $alice->PrincipalId ), "AdminCc recursively has member of alice" );

    my $CGM = RT::CachedGroupMember->new( RT->SystemUser );
    $CGM->LoadByCols( GroupId => $admincc->PrincipalId, MemberId => $delegates->PrincipalId );
    ok( $CGM->id, 'CGM record for admincc <-> delegates' );

    $CGM->LoadByCols( GroupId => $delegates->PrincipalId, MemberId => $core->PrincipalId );
    ok( $CGM->id, 'CGM record for delegates <-> core' );

    $CGM->LoadByCols( GroupId => $core->PrincipalId, MemberId => $alice->PrincipalId );
    ok( $CGM->id, 'CGM record for core <-> alice' );

    $CGM->LoadByCols( GroupId => $delegates->PrincipalId, MemberId => $alice->PrincipalId );
    ok( $CGM->id, 'CGM record for delegates <-> alice' );

    $CGM->LoadByCols( GroupId => $admincc->PrincipalId, MemberId => $core->PrincipalId );
    ok( !$CGM->id, 'No CGM record for admincc <-> core' );

    $CGM->LoadByCols( GroupId => $admincc->PrincipalId, MemberId => $alice->PrincipalId );
    ok( !$CGM->id, 'No CGM record for admincc <-> alice' );

    $CGM->LoadByCols( GroupId => $admincc->PrincipalId, MemberId => $bob->PrincipalId );
    ok( !$CGM->id, 'No CGM record for admincc <-> bob' );

    ok( $admincc->DeleteMember( $delegates->PrincipalId ), 'Delete delegates from AdminCc' );

    $CGM->LoadByCols( GroupId => $admincc->PrincipalId, MemberId => $delegates->PrincipalId );
    ok( !$CGM->id, 'No CGM record for admincc <-> delegates' );

    ok( $admincc->AddMember( $delegates->PrincipalId ), 'Add delegates to AdminCc again' );

    $CGM->LoadByCols( GroupId => $admincc->PrincipalId, MemberId => $delegates->PrincipalId );
    ok( $CGM->id, 'CGM record for admincc <-> delegates again' );

    $CGM->LoadByCols( GroupId => $admincc->PrincipalId, MemberId => $core->PrincipalId );
    ok( !$CGM->id, 'No CGM record for admincc <-> corei still' );

    $CGM->LoadByCols( GroupId => $admincc->PrincipalId, MemberId => $alice->PrincipalId );
    ok( !$CGM->id, 'No CGM record for admincc <-> alice still' );

    $CGM->LoadByCols( GroupId => $admincc->PrincipalId, MemberId => $bob->PrincipalId );
    ok( !$CGM->id, 'No CGM record for admincc <-> bob still' );
}


diag "Cascade delete cached group members";
{
    my $test1 = RT::Test->load_or_create_group('cascade test 1');
    my $test2 = RT::Test->load_or_create_group('cascade test 2');
    my $test3 = RT::Test->load_or_create_group('cascade test 3');
    my $user  = RT::Test->load_or_create_user( Name => 'User 1' );

    ok( $test3->AddMember( $user->PrincipalId ),  'Add User 1 to test 3' );
    ok( $test2->AddMember( $test3->PrincipalId ), 'Add test 3 to test 2' );
    ok( $test1->AddMember( $test2->PrincipalId ),  'Add test 2 to test 1' );

    ok( $test1->HasMemberRecursively( $test2->PrincipalId ), "Group test 1 has test 2 recursively" );
    ok( $test1->HasMemberRecursively( $test3->PrincipalId ), "Group test 1 has test 3 recursively" );
    ok( $test1->HasMemberRecursively( $user->PrincipalId ),  "Group test 1 has User 1 recursively" );

    my $cgms = RT::CachedGroupMembers->new( RT->SystemUser );
    $cgms->Limit( FIELD => 'GroupId', VALUE => $test1->Id );
    is( $cgms->Count, 4, 'Group test has 4 CachedGroupMembers rows' );

    ok( $test1->DeleteMember( $test2->PrincipalId ), 'Delete test 2 from test' );
    $cgms->RedoSearch;
    is( $cgms->Count, 1, 'Group test has 1 CachedGroupMembers row' );

    ok( !$test1->HasMemberRecursively( $test2->PrincipalId ), "Group test 1 does not have test 2 recursively" );
    ok( !$test1->HasMemberRecursively( $test3->PrincipalId ), "Group test 1 does not have test 3 recursively" );
    ok( !$test1->HasMemberRecursively( $user->PrincipalId ),  "Group test 1 does not have User 1 recursively" );
}

diag 'New group has no password policy';
{
    my $group = RT::Test->load_or_create_group( 'PolicyTestGroup' );

    is( $group->PasswordPolicy, undef, 'New group has no policy' );
}

diag 'SetPasswordPolicy stores all fields';
{
    my $group = RT::Group->new( RT->SystemUser );
    $group->LoadUserDefinedGroup('PolicyTestGroup');

    my ( $ok, $msg ) = $group->SetPasswordPolicy(
        MinLength     => 10,
        RequireUpper  => 1,
        RequireLower  => 1,
        RequireDigit  => 1,
        RequireSymbol => 0,
        NoUsername    => 1,
    );
    ok( $ok, "SetPasswordPolicy succeeded: $msg" );

    my $policy = $group->PasswordPolicy;
    is( ref $policy,              'HASH', 'PasswordPolicy returns a hashref' );
    is( $policy->{MinLength},     10,     'MinLength stored correctly' );
    is( $policy->{RequireUpper},  1,      'RequireUpper stored correctly' );
    is( $policy->{RequireLower},  1,      'RequireLower stored correctly' );
    is( $policy->{RequireDigit},  1,      'RequireDigit stored correctly' );
    is( $policy->{RequireSymbol}, 0,      'RequireSymbol stored correctly' );
    is( $policy->{NoUsername},    1,      'NoUsername stored correctly' );
}

diag 'ResetPasswordPolicy removes the policy attribute';
{
    my $group = RT::Group->new( RT->SystemUser );
    $group->LoadUserDefinedGroup('PolicyTestGroup');

    my ( $ok, $msg ) = $group->ResetPasswordPolicy;
    ok( $ok, "ResetPasswordPolicy succeeded: $msg" );
    like( $msg, qr/reset/i, 'Message mentions reset' );
    is( $group->PasswordPolicy, undef, 'Policy attribute removed after reset' );
}

diag 'SetPasswordPolicy is a no-op when nothing changed and records transactions otherwise';
{
    my $group = RT::Test->load_or_create_group('PolicyTxnGroup');

    my $count_txns = sub {
        my $txns = $group->Transactions;
        $txns->Limit( FIELD => 'Type',  VALUE => 'Set' );
        $txns->Limit( FIELD => 'Field', VALUE => 'PasswordPolicy' );
        return $txns->Count;
    };

    is( $count_txns->(), 0, 'No PasswordPolicy transactions yet' );

    my ( $ok, $msg ) = $group->SetPasswordPolicy( MinLength => 8, RequireUpper => 1 );
    ok( $ok, "First SetPasswordPolicy succeeded: $msg" );
    like( $msg, qr/updated/i, 'Message mentions updated on first set' );
    is( $count_txns->(), 1, 'One transaction recorded after first set' );

    ( $ok, $msg ) = $group->SetPasswordPolicy( MinLength => 8, RequireUpper => 1 );
    ok( $ok, "Repeated SetPasswordPolicy with same values returned ok" );
    like( $msg, qr/Nothing changed/i, 'Message says Nothing changed when no diff' );
    is( $count_txns->(), 1, 'No new transaction when nothing changed' );

    ( $ok, $msg ) = $group->SetPasswordPolicy( MinLength => 12, RequireUpper => 1 );
    ok( $ok, "Changed SetPasswordPolicy succeeded: $msg" );
    is( $count_txns->(), 2, 'New transaction recorded on actual change' );

    ( $ok, $msg ) = $group->ResetPasswordPolicy;
    ok( $ok, "ResetPasswordPolicy succeeded: $msg" );
    like( $msg, qr/reset/i, 'Message mentions reset' );
    is( $count_txns->(), 3, 'Transaction recorded on reset' );

    ( $ok, $msg ) = $group->ResetPasswordPolicy;
    ok( $ok, "ResetPasswordPolicy on no-policy returned ok" );
    like( $msg, qr/Nothing changed/i, 'Message says Nothing changed when no policy to reset' );
    is( $count_txns->(), 3, 'No new transaction on redundant reset' );
}

diag 'SetPasswordPolicy requires AdminGroup right';
{
    my $group = RT::Group->new( RT->SystemUser );
    $group->LoadUserDefinedGroup('PolicyTestGroup');

    my $unprivileged = RT::Test->load_or_create_user( Name => 'no_rights_user' );

    my $group_as_noperm = RT::Group->new( RT::CurrentUser->new($unprivileged) );
    $group_as_noperm->LoadUserDefinedGroup('PolicyTestGroup');

    my ( $ok, $msg ) = $group_as_noperm->SetPasswordPolicy( MinLength => 8 );
    is( $ok, 0, 'SetPasswordPolicy denied without AdminGroup right' );
    like( $msg, qr/Permission Denied/i, 'Error message says Permission Denied' );
}

diag 'User in no groups uses global PasswordPolicy config';
{
    RT->Config->Set( 'PasswordPolicy', { Default => { MinLength => 8 } } );

    my $user = RT::Test->load_or_create_user( Name => 'policy_no_groups' );

    my $policy = $user->EffectivePasswordPolicy;
    is( $policy->{MinLength}, 8, 'No groups: returns global config MinLength' );

    RT->Config->Set( 'PasswordPolicy', { Default => { MinLength => 5 } } );
}

diag 'User in one group uses that group policy';
{
    my $group = RT::Test->load_or_create_group( 'SingleGroup' );
    $group->SetPasswordPolicy( MinLength => 12, RequireDigit => 1 );

    my $user = RT::Test->load_or_create_user( Name => 'policy_one_group' );
    $group->AddMember( $user->PrincipalId );

    my $policy = $user->EffectivePasswordPolicy;
    is( $policy->{MinLength},    12, 'One group: MinLength = 12' );
    is( $policy->{RequireDigit}, 1,  'One group: RequireDigit = 1' );
}

diag 'User in multiple groups gets most restrictive merge';
{
    my $g1 = RT::Test->load_or_create_group( 'PolicyGroupA' );
    $g1->SetPasswordPolicy( MinLength => 8, RequireUpper => 1 );

    my $g2 = RT::Test->load_or_create_group( 'PolicyGroupB' );
    $g2->SetPasswordPolicy( MinLength => 12, RequireLower => 1 );

    my $user = RT::Test->load_or_create_user( Name => 'policy_multi_group' );
    $g1->AddMember( $user->PrincipalId );
    $g2->AddMember( $user->PrincipalId );

    my $policy = $user->EffectivePasswordPolicy;
    is( $policy->{MinLength},    12, 'Multi-group: takes max MinLength' );
    is( $policy->{RequireUpper}, 1,  'Multi-group: OR RequireUpper' );
    is( $policy->{RequireLower}, 1,  'Multi-group: OR RequireLower' );

    # Disable g2; only g1's policy should remain.
    $g2->SetDisabled(1);
    $policy = $user->EffectivePasswordPolicy;
    is( $policy->{MinLength},    8,     'Disabled group policy is excluded from merge' );
    is( $policy->{RequireUpper}, 1,     'Remaining group still contributes RequireUpper' );
    ok( !$policy->{RequireLower},       'Disabled group does not contribute RequireLower' );
    $g2->SetDisabled(0);
}

diag 'ValidatePassword enforces all policy fields';
{
    my $vgroup = RT::Test->load_or_create_group( 'ValidateGroup' );
    $vgroup->SetPasswordPolicy(
        MinLength     => 10,
        RequireUpper  => 1,
        RequireLower  => 1,
        RequireDigit  => 1,
        RequireSymbol => 1,
        NoUsername    => 1,
    );

    my $user = RT::Test->load_or_create_user( Name => 'validateuser' );
    $vgroup->AddMember( $user->PrincipalId );

    my ( $ok, $msg );

    ( $ok, $msg ) = $user->ValidatePassword('Ab1!');
    is( $ok, 0, 'Too-short password rejected' );
    like( $msg, qr/10/, 'Error message mentions required length' );

    ( $ok, $msg ) = $user->ValidatePassword('abcdef123!x');
    is( $ok, 0, 'Missing uppercase rejected' );
    like( $msg, qr/uppercase/i, 'Error mentions uppercase' );

    ( $ok, $msg ) = $user->ValidatePassword('ABCDEF123!X');
    is( $ok, 0, 'Missing lowercase rejected' );
    like( $msg, qr/lowercase/i, 'Error mentions lowercase' );

    ( $ok, $msg ) = $user->ValidatePassword('Abcdefghij!');
    is( $ok, 0, 'Missing digit rejected' );
    like( $msg, qr/digit/i, 'Error mentions digit' );

    ( $ok, $msg ) = $user->ValidatePassword('Abcdef12345');
    is( $ok, 0, 'Missing symbol rejected' );
    like( $msg, qr/symbol/i, 'Error mentions symbol' );

    ( $ok, $msg ) = $user->ValidatePassword('Validateuser1!');
    is( $ok, 0, 'Password containing username rejected' );
    like( $msg, qr/username/i, 'Error mentions username' );

    ( $ok, $msg ) = $user->ValidatePassword('Correct#1Horse');
    is( $ok, 1, 'Valid password accepted' );
}

diag 'ValidatePassword called from Create path';
{
    RT->Config->Set( 'PasswordPolicy', { Default => { MinLength => 20 } } );

    my $user = RT::User->new( RT->SystemUser );
    my ( $ok, $msg ) = $user->Create( Name => 'create_fail_user', Password => 'tooshort' );
    is( $ok, 0, 'Create fails when password violates global policy' );
    like( $msg, qr/20/, 'Error from Create mentions required length' );

    RT->Config->Set( 'PasswordPolicy', { Default => { MinLength => 5 } } );
}

diag 'ValidatePassword called from SetPassword path';
{
    RT->Config->Set( 'PasswordPolicy', { Default => { MinLength => 15 } } );

    my $user = RT::Test->load_or_create_user( Name => 'setpw_fail_user' );
    my ( $ok, $msg ) = $user->SetPassword('tooshort');
    is( $ok, 0, 'SetPassword rejects policy-violating password' );
    like( $msg, qr/15/, 'Error from SetPassword mentions required length' );

    RT->Config->Set( 'PasswordPolicy', { Default => { MinLength => 5 } } );
}

diag 'Default-only config works for all users';
{
    RT->Config->Set( 'PasswordPolicy', { Default => { MinLength => 12 } } );

    my $priv_user = RT::Test->load_or_create_user( Name => 'default_priv', Privileged => 1 );

    my $unpriv_user = RT::Test->load_or_create_user( Name => 'default_unpriv', Privileged => 0 );

    my $policy = $priv_user->EffectivePasswordPolicy;
    is( $policy->{MinLength}, 12, 'Privileged user gets Default MinLength when no Privileged key' );

    $policy = $unpriv_user->EffectivePasswordPolicy;
    is( $policy->{MinLength}, 12, 'Unprivileged user gets Default MinLength when no Unprivileged key' );

    RT->Config->Set( 'PasswordPolicy', { Default => { MinLength => 5 } } );
}

diag 'Privileged config key applied to privileged user';
{
    RT->Config->Set(
        'PasswordPolicy',
        {   Default    => { MinLength => 5 },
            Privileged => { MinLength => 10, RequireUpper => 1 },
        }
    );

    my $user = RT::Test->load_or_create_user( Name => 'priv_policy_user', Privileged => 1 );

    my $policy = $user->EffectivePasswordPolicy;
    is( $policy->{MinLength},    10, 'Privileged user gets Privileged MinLength' );
    is( $policy->{RequireUpper}, 1,  'Privileged user gets Privileged RequireUpper' );

    RT->Config->Set( 'PasswordPolicy', { Default => { MinLength => 5 } } );
}

diag 'Unprivileged config key applied to unprivileged user';
{
    RT->Config->Set(
        'PasswordPolicy',
        {   Default      => { MinLength => 5 },
            Unprivileged => { MinLength => 8, RequireDigit => 1 },
        }
    );

    my $user = RT::Test->load_or_create_user( Name => 'unpriv_policy_user', Privileged => 0 );

    my $policy = $user->EffectivePasswordPolicy;
    is( $policy->{MinLength},    8, 'Unprivileged user gets Unprivileged MinLength' );
    is( $policy->{RequireDigit}, 1, 'Unprivileged user gets Unprivileged RequireDigit' );

    RT->Config->Set( 'PasswordPolicy', { Default => { MinLength => 5 } } );
}

diag 'Privileged user falls back to Default when Privileged key absent';
{
    RT->Config->Set(
        'PasswordPolicy',
        {   Default      => { MinLength => 7 },
            Unprivileged => { MinLength => 3 },
        }
    );

    my $user = RT::Test->load_or_create_user( Name => 'priv_fallback_user', Privileged => 1 );

    my $policy = $user->EffectivePasswordPolicy;
    is( $policy->{MinLength}, 7, 'Privileged user falls back to Default when no Privileged key' );

    RT->Config->Set( 'PasswordPolicy', { Default => { MinLength => 5 } } );
}

diag 'Hardcoded fallback when no matching key and no Default';
{
    RT->Config->Set( 'PasswordPolicy', { Unprivileged => { MinLength => 20 }, } );

    my $user = RT::Test->load_or_create_user( Name => 'no_default_user', Privileged => 1 );

    my $policy = $user->EffectivePasswordPolicy;
    is( $policy->{MinLength}, 5, 'Falls back to hardcoded MinLength => 5 when no matching key and no Default' );

    RT->Config->Set( 'PasswordPolicy', { Default => { MinLength => 5 } } );
}

diag 'Group policy takes precedence over Privileged config';
{
    RT->Config->Set(
        'PasswordPolicy',
        {   Default    => { MinLength => 5 },
            Privileged => { MinLength => 10 },
        }
    );

    my $group = RT::Test->load_or_create_group( 'OverrideGroup' );
    $group->SetPasswordPolicy( MinLength => 15 );

    my $user = RT::Test->load_or_create_user( Name => 'group_override_user', Privileged => 1 );
    $group->AddMember( $user->PrincipalId );

    my $policy = $user->EffectivePasswordPolicy;
    is( $policy->{MinLength}, 15, 'Group policy overrides Privileged config key' );

    RT->Config->Set( 'PasswordPolicy', { Default => { MinLength => 5 } } );
}

done_testing;

use strict;
use warnings;
use RT::Test nodata => 1, tests => 27;

RT::Group->AddRight( General =>
    'RTxGroupRight' => 'Just a right for testing rights',
);

{
    my $g = RT::Group->new(RT->SystemUser);
    my ($id, $msg) = $g->CreateUserDefinedGroup(Name => 'GroupsNotEqualTest');
    ok ($id, "created group #". $g->id) or diag("error: $msg");

    my $groups = RT::Groups->new(RT->SystemUser);
    $groups->Limit( FIELD => 'id', OPERATOR => '!=', VALUE => $g->id );
    $groups->LimitToUserDefinedGroups();
    my $bug = grep $_->id == $g->id, @{$groups->ItemsArrayRef};
    ok (!$bug, "didn't find group");
}


{
    my $u = RT::User->new(RT->SystemUser);
    my ($id, $msg) = $u->Create( Name => 'Membertests'. $$ );
    ok ($id, 'created user') or diag "error: $msg";

    my $g = RT::Group->new(RT->SystemUser);
    ($id, $msg) = $g->CreateUserDefinedGroup(Name => 'Membertests');
    ok ($id, $msg);

    my ($aid, $amsg) =$g->AddMember($u->id);
    ok ($aid, $amsg);
    ok($g->HasMember($u->PrincipalObj),"G has member u");

    my $groups = RT::Groups->new(RT->SystemUser);
    $groups->LimitToUserDefinedGroups();
    $groups->WithMember(PrincipalId => $u->id);
    is ($groups->Count , 1,"found the 1 group - " . $groups->Count);
    is ($groups->First->Id , $g->Id, "it's the right one");
}

no warnings qw/redefine once/;

my $q = RT::Queue->new(RT->SystemUser);
my ($id, $msg) =$q->Create( Name => 'GlobalACLTest');
ok ($id, $msg);

my $testuser = RT::User->new(RT->SystemUser);
($id,$msg) = $testuser->Create(Name => 'JustAnAdminCc');
ok ($id,$msg);

my $global_admin_cc = RT->System->RoleGroup( 'AdminCc' );
ok($global_admin_cc->id, "Found the global admincc group");
my $groups = RT::Groups->new(RT->SystemUser);
$groups->WithRight(Right => 'OwnTicket', Object => $q);
is($groups->Count, 1);
($id, $msg) = $global_admin_cc->PrincipalObj->GrantRight(Right =>'OwnTicket', Object=> RT->System);
ok ($id,$msg);
ok (!$testuser->HasRight(Object => $q, Right => 'OwnTicket') , "The test user does not have the right to own tickets in the test queue");
($id, $msg) = $q->AddWatcher(Type => 'AdminCc', PrincipalId => $testuser->id);
ok($id,$msg);
ok ($testuser->HasRight(Object => $q, Right => 'OwnTicket') , "The test user does have the right to own tickets now. thank god.");

$groups = RT::Groups->new(RT->SystemUser);
$groups->WithRight(Right => 'OwnTicket', Object => $q);
ok ($id,$msg);
is($groups->Count, 3);

my $RTxGroup = RT::Group->new(RT->SystemUser);
($id, $msg) = $RTxGroup->CreateUserDefinedGroup( Name => 'RTxGroup', Description => "RTx extension group");
ok ($id,$msg);
is ($RTxGroup->id, $id, "group loaded");

my $RTxSysObj = {};
bless $RTxSysObj, 'RTx::System';
*RTx::System::Id = sub { 1; };
*RTx::System::id = *RTx::System::Id;
my $ace = RT::Record->new(RT->SystemUser);
$ace->Table('ACL');
$ace->_BuildTableAttributes unless ($RT::Record::_TABLE_ATTR->{ref($ace)});
($id, $msg) = $ace->Create( PrincipalId => $RTxGroup->id, PrincipalType => 'Group', RightName => 'RTxGroupRight', ObjectType => 'RTx::System', ObjectId  => 1);
ok ($id, "ACL for RTxSysObj created");

my $RTxObj = {};
bless $RTxObj, 'RTx::System::Record';
*RTx::System::Record::Id = sub { 4; };
*RTx::System::Record::id = *RTx::System::Record::Id;

$groups = RT::Groups->new(RT->SystemUser);
$groups->WithRight(Right => 'RTxGroupRight', Object => $RTxSysObj);
is($groups->Count, 1, "RTxGroupRight found for RTxSysObj");

$groups = RT::Groups->new(RT->SystemUser);
$groups->WithRight(Right => 'RTxGroupRight', Object => $RTxObj);
is($groups->Count, 0, "RTxGroupRight not found for RTxObj");

$groups = RT::Groups->new(RT->SystemUser);
$groups->WithRight(Right => 'RTxGroupRight', Object => $RTxObj, EquivObjects => [ $RTxSysObj ]);
is($groups->Count, 1, "RTxGroupRight found for RTxObj using EquivObjects");

$ace = RT::Record->new(RT->SystemUser);
$ace->Table('ACL');
$ace->_BuildTableAttributes unless ($RT::Record::_TABLE_ATTR->{ref($ace)});
($id, $msg) = $ace->Create( PrincipalId => $RTxGroup->id, PrincipalType => 'Group', RightName => 'RTxGroupRight', ObjectType => 'RTx::System::Record', ObjectId  => 5 );
ok ($id, "ACL for RTxObj created");

my $RTxObj2 = {};
bless $RTxObj2, 'RTx::System::Record';
*RTx::System::Record::Id = sub { 5; };

$groups = RT::Groups->new(RT->SystemUser);
$groups->WithRight(Right => 'RTxGroupRight', Object => $RTxObj2);
is($groups->Count, 1, "RTxGroupRight found for RTxObj2");

$groups = RT::Groups->new(RT->SystemUser);
$groups->WithRight(Right => 'RTxGroupRight', Object => $RTxObj2, EquivObjects => [ $RTxSysObj ]);
is($groups->Count, 1, "RTxGroupRight found for RTxObj2");


use strict;
use warnings;
use RT::Test; use Test::More; 
plan tests => 28;



{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

ok (require RT::Model::GroupCollection);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

# next had bugs
# Groups->limit( column => 'id', operator => '!=', value => xx );
my $g = RT::Model::Group->new($RT::SystemUser);
my ($id, $msg) = $g->create_userDefinedGroup(Name => 'GroupsNotEqualTest');
ok ($id, "Created group #". $g->id) or diag("error: $msg");

my $groups = RT::Model::GroupCollection->new($RT::SystemUser);
$groups->limit( column => 'id', operator => '!=', value => $g->id );
$groups->LimitToUserDefinedGroups();
my $bug = grep $_->id == $g->id, @{$groups->items_array_ref};
ok (!$bug, "didn't find group");


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

my $u = RT::Model::User->new($RT::SystemUser);
my ($id, $msg) = $u->create( Name => 'Membertests'. $$ );
ok ($id, 'Created user') or diag "error: $msg";

my $g = RT::Model::Group->new($RT::SystemUser);
($id, $msg) = $g->create_userDefinedGroup(Name => 'Membertests');
ok ($id, $msg);

my ($aid, $amsg) =$g->AddMember($u->id);
ok ($aid, $amsg);
ok($g->has_member($u->PrincipalObj),"G has member u");

my $groups = RT::Model::GroupCollection->new($RT::SystemUser);
$groups->LimitToUserDefinedGroups();
$groups->WithMember(PrincipalId => $u->id);
is ($groups->count , 1,"found the 1 group - " . $groups->count);
is ($groups->first->id , $g->id, "it's the right one");


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
    no warnings qw/redefine once/;

my $q = RT::Model::Queue->new($RT::SystemUser);
my ($id, $msg) =$q->create( Name => 'GlobalACLTest');
ok ($id, $msg);

my $testuser = RT::Model::User->new($RT::SystemUser);
($id,$msg) = $testuser->create(Name => 'JustAnAdminCc');
ok ($id,$msg);

my $global_admin_cc = RT::Model::Group->new($RT::SystemUser);
$global_admin_cc->loadSystemRoleGroup('AdminCc');
ok($global_admin_cc->id, "Found the global admincc group");
my $groups = RT::Model::GroupCollection->new($RT::SystemUser);
$groups->WithRight(Right => 'OwnTicket', Object => $q);
is($groups->count, 1);
($id, $msg) = $global_admin_cc->PrincipalObj->GrantRight(Right =>'OwnTicket', Object=> $RT::System);
ok ($id,$msg);
ok (!$testuser->has_right(Object => $q, Right => 'OwnTicket') , "The test user does not have the right to own tickets in the test queue");
($id, $msg) = $q->AddWatcher(Type => 'AdminCc', PrincipalId => $testuser->id);
ok($id,$msg);
ok ($testuser->has_right(Object => $q, Right => 'OwnTicket') , "The test user does have the right to own tickets now. thank god.");

$groups = RT::Model::GroupCollection->new($RT::SystemUser);
$groups->WithRight(Right => 'OwnTicket', Object => $q);
ok ($id,$msg);
is($groups->count, 3);

my $RTxGroup = RT::Model::Group->new($RT::SystemUser);
($id, $msg) = $RTxGroup->create_userDefinedGroup( Name => 'RTxGroup', Description => "RTx extension group");
ok ($id,$msg);
is ($RTxGroup->id, $id, "group loaded");

my $RTxSysObj = {};
bless $RTxSysObj, 'RTx::System';
*RTx::System::Id = sub { 1; };
*RTx::System::id = *RTx::System::Id;
my $ace = RT::Model::ACE->new($RT::SystemUser);
($id, $msg) = $ace->RT::Record::create( PrincipalId => $RTxGroup->id, PrincipalType => 'Group', RightName => 'RTxGroupRight', ObjectType => 'RTx::System', ObjectId  => 1);
ok ($id, "ACL for RTxSysObj Created");

my $RTxObj = {};
bless $RTxObj, 'RTx::System::Record';
*RTx::System::Record::Id = sub { 4; };
*RTx::System::Record::id = *RTx::System::Record::Id;

$groups = RT::Model::GroupCollection->new($RT::SystemUser);
$groups->WithRight(Right => 'RTxGroupRight', Object => $RTxSysObj);
is($groups->count, 1, "RTxGroupRight found for RTxSysObj");

$groups = RT::Model::GroupCollection->new($RT::SystemUser);
$groups->WithRight(Right => 'RTxGroupRight', Object => $RTxObj);
is($groups->count, 0, "RTxGroupRight not found for RTxObj");

$groups = RT::Model::GroupCollection->new($RT::SystemUser);
$groups->WithRight(Right => 'RTxGroupRight', Object => $RTxObj, EquivObjects => [ $RTxSysObj ]);
is($groups->count, 1, "RTxGroupRight found for RTxObj using EquivObjects");

use RT::Model::ACE;
$ace = RT::Model::ACE->new($RT::SystemUser);
($id, $msg) = $ace->RT::Record::create( PrincipalId => $RTxGroup->id, PrincipalType => 'Group', RightName => 'RTxGroupRight', ObjectType => 'RTx::System::Record', ObjectId  => 5 );
ok ($id, "ACL for RTxObj Created");

my $RTxObj2 = {};
bless $RTxObj2, 'RTx::System::Record';
*RTx::System::Record::Id = sub { 5; };

$groups = RT::Model::GroupCollection->new($RT::SystemUser);
$groups->WithRight(Right => 'RTxGroupRight', Object => $RTxObj2);
is($groups->count, 1, "RTxGroupRight found for RTxObj2");

$groups = RT::Model::GroupCollection->new($RT::SystemUser);
$groups->WithRight(Right => 'RTxGroupRight', Object => $RTxObj2, EquivObjects => [ $RTxSysObj ]);
is($groups->count, 1, "RTxGroupRight found for RTxObj2");




    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

1;

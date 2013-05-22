use strict;
use warnings;
use RT::Test tests => 10;

RT::System->AddRight( General =>
    'RTxUserRight' => 'Just a right for testing rights',
);

{
    no warnings qw(redefine once);

ok(my $users = RT::Users->new(RT->SystemUser));
$users->WhoHaveRight(Object => RT->System, Right =>'SuperUser');
is($users->Count , 1, "There is one privileged superuser - Found ". $users->Count );
# TODO: this wants more testing

my $RTxUser = RT::User->new(RT->SystemUser);
my ($id, $msg) = $RTxUser->Create( Name => 'RTxUser', Comments => "RTx extension user", Privileged => 1);
ok ($id,$msg);

my $group = RT::Group->new(RT->SystemUser);
$group->LoadACLEquivalenceGroup($RTxUser->PrincipalObj);

my $RTxSysObj = {};
bless $RTxSysObj, 'RTx::System';
*RTx::System::Id = sub { 1; };
*RTx::System::id = *RTx::System::Id;
my $ace = RT::Record->new(RT->SystemUser);
$ace->Table('ACL');
$ace->_BuildTableAttributes unless ($RT::Record::_TABLE_ATTR->{ref($ace)});
($id, $msg) = $ace->Create( PrincipalId => $group->id, PrincipalType => 'Group', RightName => 'RTxUserRight', ObjectType => 'RTx::System', ObjectId  => 1 );
ok ($id, "ACL for RTxSysObj created");

my $RTxObj = {};
bless $RTxObj, 'RTx::System::Record';
*RTx::System::Record::Id = sub { 4; };
*RTx::System::Record::id = *RTx::System::Record::Id;

$users = RT::Users->new(RT->SystemUser);
$users->WhoHaveRight(Right => 'RTxUserRight', Object => $RTxSysObj);
is($users->Count, 1, "RTxUserRight found for RTxSysObj");

$users = RT::Users->new(RT->SystemUser);
$users->WhoHaveRight(Right => 'RTxUserRight', Object => $RTxObj);
is($users->Count, 0, "RTxUserRight not found for RTxObj");

$users = RT::Users->new(RT->SystemUser);
$users->WhoHaveRight(Right => 'RTxUserRight', Object => $RTxObj, EquivObjects => [ $RTxSysObj ]);
is($users->Count, 1, "RTxUserRight found for RTxObj using EquivObjects");

$ace = RT::Record->new(RT->SystemUser);
$ace->Table('ACL');
$ace->_BuildTableAttributes unless ($RT::Record::_TABLE_ATTR->{ref($ace)});
($id, $msg) = $ace->Create( PrincipalId => $group->id, PrincipalType => 'Group', RightName => 'RTxUserRight', ObjectType => 'RTx::System::Record', ObjectId => 5 );
ok ($id, "ACL for RTxObj created");

my $RTxObj2 = {};
bless $RTxObj2, 'RTx::System::Record';
*RTx::System::Record::Id = sub { 5; };
*RTx::System::Record::id = sub { 5; };

$users = RT::Users->new(RT->SystemUser);
$users->WhoHaveRight(Right => 'RTxUserRight', Object => $RTxObj2);
is($users->Count, 1, "RTxUserRight found for RTxObj2");

$users = RT::Users->new(RT->SystemUser);
$users->WhoHaveRight(Right => 'RTxUserRight', Object => $RTxObj2, EquivObjects => [ $RTxSysObj ]);
is($users->Count, 1, "RTxUserRight found for RTxObj2");



}


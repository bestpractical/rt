
use strict;
use warnings;
use RT::Test; use Test::More; 
plan tests => 11;
use RT;
no warnings qw/redefine once/;


use_ok('RT::Model::UserCollection');

ok(my $users = RT::Model::UserCollection->new(RT->SystemUser));
$users->WhoHaveRight(Object =>RT->System, Right =>'SuperUser');
is($users->count , 1, "There is one privileged superuser - Found ". $users->count );
# TODO: this wants more testing

my $RTxUser = RT::Model::User->new(RT->SystemUser);
my ($id, $msg) = $RTxUser->create( Name => 'RTxUser', Comments => "RTx extension user", Privileged => 1);
ok ($id,$msg);

my $group = RT::Model::Group->new(RT->SystemUser);
$group->load_acl_equivalence_group($RTxUser->PrincipalObj);
my $RTxSysObj = {};
bless $RTxSysObj, 'RTx::System';
*RTx::System::Id = sub { 1; };
*RTx::System::id = *RTx::System::Id;
my $ace = RT::Model::ACE->new(RT->SystemUser);
($id, $msg) = $ace->RT::Record::create( PrincipalId => $group->id, PrincipalType => 'Group', RightName => 'RTxUserRight', ObjectType => 'RTx::System', ObjectId  => 1 );
ok ($id, "ACL for RTxSysObj Created");

my $RTxObj = {};
bless $RTxObj, 'RTx::System::Record';
*RTx::System::Record::Id = sub { 4; };
*RTx::System::Record::id = *RTx::System::Record::Id;

$users = RT::Model::UserCollection->new(RT->SystemUser);
$users->WhoHaveRight(Right => 'RTxUserRight', Object => $RTxSysObj);
is($users->count, 1, "RTxUserRight found for RTxSysObj");

$users = RT::Model::UserCollection->new(RT->SystemUser);
$users->WhoHaveRight(Right => 'RTxUserRight', Object => $RTxObj);
is($users->count, 0, "RTxUserRight not found for RTxObj");

$users = RT::Model::UserCollection->new(RT->SystemUser);
$users->WhoHaveRight(Right => 'RTxUserRight', Object => $RTxObj, EquivObjects => [ $RTxSysObj ]);
is($users->count, 1, "RTxUserRight found for RTxObj using EquivObjects");

$ace = RT::Model::ACE->new(RT->SystemUser);
($id, $msg) = $ace->RT::Record::create( PrincipalId => $group->id, PrincipalType => 'Group', RightName => 'RTxUserRight', ObjectType => 'RTx::System::Record', ObjectId => 5 );
ok ($id, "ACL for RTxObj Created");

my $RTxObj2 = {};
bless $RTxObj2, 'RTx::System::Record';
*RTx::System::Record::Id = sub { 5; };
*RTx::System::Record::id = sub { 5; };

$users = RT::Model::UserCollection->new(RT->SystemUser);
$users->WhoHaveRight(Right => 'RTxUserRight', Object => $RTxObj2);
is($users->count, 1, "RTxUserRight found for RTxObj2");

$users = RT::Model::UserCollection->new(RT->SystemUser);
$users->WhoHaveRight(Right => 'RTxUserRight', Object => $RTxObj2, EquivObjects => [ $RTxSysObj ]);
is($users->count, 1, "RTxUserRight found for RTxObj2");



1;

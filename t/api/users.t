
use strict;
use warnings;
use RT::Test; use Test::More; 
plan tests => 11;
use RT;
no warnings qw/redefine once/;


use_ok('RT::Model::UserCollection');

ok(my $users = RT::Model::UserCollection->new(current_user => RT->system_user));
$users->who_have_right(Object =>RT->system, Right =>'SuperUser');
is($users->count , 1, "There is one privileged superuser - Found ". $users->count );


# TODO: this wants more testing

my $RTxUser = RT::Model::User->new(current_user => RT->system_user);
my ($id, $msg) = $RTxUser->create( name => 'RTxUser', comments => "RTx extension user", privileged => 1);
ok ($id,$msg);

my $group = RT::Model::Group->new(current_user => RT->system_user);
$group->load_acl_equivalence_group($RTxUser->principal_object);
my $RTxSysObj = {};
bless $RTxSysObj, 'RTx::System';
*RTx::System::Id = sub { 1; };
*RTx::System::id = *RTx::System::Id;
my $ace = RT::Model::ACE->new(current_user => RT->system_user);
($id, $msg) = $ace->RT::Record::create( principal_id => $group->id, principal_type => 'Group', right_name => 'RTxUserRight', object_type => 'RTx::System', object_id  => 1 );
ok ($id, "ACL for RTxSysObj Created");

my $RTxObj = {};
bless $RTxObj, 'RTx::System::Record';
*RTx::System::Record::id = sub { 4; };
*RTx::System::Record::id = *RTx::System::Record::id;

$users = RT::Model::UserCollection->new(current_user => RT->system_user);
$users->who_have_right(Right => 'RTxUserRight', Object => $RTxSysObj);
is($users->count, 1, "RTxUserRight found for RTxSysObj");

$users = RT::Model::UserCollection->new(current_user => RT->system_user);
$users->who_have_right(Right => 'RTxUserRight', Object => $RTxObj);
is($users->count, 0, "RTxUserRight not found for RTxObj");

$users = RT::Model::UserCollection->new(current_user => RT->system_user);
$users->who_have_right(Right => 'RTxUserRight', Object => $RTxObj, equiv_objects => [ $RTxSysObj ]);
is($users->count, 1, "RTxUserRight found for RTxObj using equiv_objects");

$ace = RT::Model::ACE->new(current_user => RT->system_user);
($id, $msg) = $ace->RT::Record::create( principal_id => $group->id, principal_type => 'Group', right_name => 'RTxUserRight', object_type => 'RTx::System::Record', object_id => 5 );
ok ($id, "ACL for RTxObj Created");

my $RTxObj2 = {};
bless $RTxObj2, 'RTx::System::Record';
*RTx::System::Record::Id = sub { 5; };
*RTx::System::Record::id = sub { 5; };

$users = RT::Model::UserCollection->new(current_user => RT->system_user);
$users->who_have_right(Right => 'RTxUserRight', Object => $RTxObj2);
is($users->count, 1, "RTxUserRight found for RTxObj2");

$users = RT::Model::UserCollection->new(current_user => RT->system_user);
$users->who_have_right(Right => 'RTxUserRight', Object => $RTxObj2, equiv_objects => [ $RTxSysObj ]);
is($users->count, 1, "RTxUserRight found for RTxObj2");



1;

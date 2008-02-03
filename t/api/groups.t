
use strict;
use warnings;
use RT::Test; use Test::More; 
plan tests => 28;




ok (require RT::Model::GroupCollection);


{

# next had bugs
# Groups->limit( column => 'id', operator => '!=', value => xx );
my $g = RT::Model::Group->new(current_user => RT->system_user);
my ($id, $msg) = $g->create_user_defined_group(name => 'GroupsNotEqualTest');
ok ($id, "Created group #". $g->id) or diag("error: $msg");

my $groups = RT::Model::GroupCollection->new(current_user => RT->system_user);
$groups->limit( column => 'id', operator => '!=', value => $g->id );
$groups->limit_to_user_defined_groups();
my $bug = grep $_->id == $g->id, @{$groups->items_array_ref};
ok (!$bug, "didn't find group");


}

{

my $u = RT::Model::User->new(current_user => RT->system_user);
my ($id, $msg) = $u->create( name => 'Membertests'. $$ );
ok ($id, 'Created user') or diag "error: $msg";

my $g = RT::Model::Group->new(current_user => RT->system_user);
($id, $msg) = $g->create_user_defined_group(name => 'Membertests');
ok ($id, $msg);

my ($aid, $amsg) =$g->add_member($u->id);
ok ($aid, $amsg);
ok($g->has_member($u->principal_object),"G has member u");

my $groups = RT::Model::GroupCollection->new(current_user => RT->system_user);
$groups->limit_to_user_defined_groups();
$groups->with_member(principal_id => $u->id);
is ($groups->count , 1,"found the 1 group - " . $groups->count);
is ($groups->first->id , $g->id, "it's the right one");


}

{
    no warnings qw/redefine once/;

my $q = RT::Model::Queue->new(current_user => RT->system_user);
my ($id, $msg) =$q->create( name => 'GlobalACLTest');
ok ($id, $msg);

my $testuser = RT::Model::User->new(current_user => RT->system_user);
($id,$msg) = $testuser->create(name => 'JustAnAdminCc');
ok ($id,$msg);

my $global_admin_cc = RT::Model::Group->new(current_user => RT->system_user);
$global_admin_cc->load_system_role_group('admin_cc');
ok($global_admin_cc->id, "Found the global admincc group");
my $groups = RT::Model::GroupCollection->new(current_user => RT->system_user);
$groups->with_right(right => 'OwnTicket', object => $q);
is($groups->count, 1);
($id, $msg) = $global_admin_cc->principal_object->grant_right(right =>'OwnTicket', object=> RT->system);
ok ($id,$msg);
ok (!$testuser->has_right(object => $q, right => 'OwnTicket') , "The test user does not have the right to own tickets in the test queue");
($id, $msg) = $q->add_watcher(type => 'admin_cc', principal_id => $testuser->id);
ok($id,$msg);
ok ($testuser->has_right(object => $q, right => 'OwnTicket') , "The test user does have the right to own tickets now. thank god.");

$groups = RT::Model::GroupCollection->new(current_user => RT->system_user);
$groups->with_right(right => 'OwnTicket', object => $q);
ok ($id,$msg);
is($groups->count, 3);

my $RTxGroup = RT::Model::Group->new(current_user => RT->system_user);
($id, $msg) = $RTxGroup->create_user_defined_group( name => 'RTxGroup', description => "RTx extension group");
ok ($id,$msg);
is ($RTxGroup->id, $id, "group loaded");

my $RTxSysObj = {};
bless $RTxSysObj, 'RTx::System';
*RTx::System::id = sub  { 1; };
*RTx::System::id = *RTx::System::id;
my $ace = RT::Model::ACE->new(current_user => RT->system_user);
($id, $msg) = $ace->RT::Record::create( principal_id => $RTxGroup->id, principal_type => 'Group', right_name => 'RTxGroupRight', object_type => 'RTx::System', object_id  => 1);
ok ($id, "ACL for RTxSysObj Created");

my $RTxObj = {};
bless $RTxObj, 'RTx::System::Record';
*RTx::System::Record::id = sub  { 4; };
*RTx::System::Record::id = *RTx::System::Record::id;

$groups = RT::Model::GroupCollection->new(current_user => RT->system_user);
$groups->with_right(right => 'RTxGroupRight', object => $RTxSysObj);
is($groups->count, 1, "RTxGroupRight found for RTxSysObj");

$groups = RT::Model::GroupCollection->new(current_user => RT->system_user);
$groups->with_right(right => 'RTxGroupRight', object => $RTxObj);
is($groups->count, 0, "RTxGroupRight not found for RTxObj");

$groups = RT::Model::GroupCollection->new(current_user => RT->system_user);
$groups->with_right(right => 'RTxGroupRight', object => $RTxObj, equiv_objects => [ $RTxSysObj ]);
is($groups->count, 1, "RTxGroupRight found for RTxObj using equiv_objects");

use RT::Model::ACE;
$ace = RT::Model::ACE->new(current_user => RT->system_user);
($id, $msg) = $ace->RT::Record::create( principal_id => $RTxGroup->id, principal_type => 'Group', right_name => 'RTxGroupRight', object_type => 'RTx::System::Record', object_id  => 5 );
ok ($id, "ACL for RTxObj Created");

my $RTxObj2 = {};
bless $RTxObj2, 'RTx::System::Record';
*RTx::System::Record::id = sub  { 5; };

$groups = RT::Model::GroupCollection->new(current_user => RT->system_user);
$groups->with_right(right => 'RTxGroupRight', object => $RTxObj2);
is($groups->count, 1, "RTxGroupRight found for RTxObj2");

$groups = RT::Model::GroupCollection->new(current_user => RT->system_user);
$groups->with_right(right => 'RTxGroupRight', object => $RTxObj2, equiv_objects => [ $RTxSysObj ]);
is($groups->count, 1, "RTxGroupRight found for RTxObj2");




}

1;

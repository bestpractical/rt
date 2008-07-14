
use strict;
use warnings;
use RT::Test; use Test::More; 
plan tests => 24;
use RT;
{


use RT::Model::Queue;
my $q = RT::Model::Queue->new(current_user => RT->system_user);
is($q->is_valid_status('new'), 1, 'New is a valid status');
is($q->is_valid_status('f00'), 0, 'f00 is not a valid status');


}

{

my $q = RT::Model::Queue->new(current_user => RT->system_user);
is($q->is_active_status('new'), 1, 'New is a Active status');
is($q->is_active_status('rejected'), 0, 'Rejected is an inactive status');
is($q->is_active_status('f00'), 0, 'f00 is not a Active status');


}

{

my $q = RT::Model::Queue->new(current_user => RT->system_user);
is($q->is_inactive_status('new'), 0, 'New is a Active status');
is($q->is_inactive_status('rejected'), 1, 'rejeected is an Inactive status');
is($q->is_inactive_status('f00'), 0, 'f00 is not a Active status');


}

{

my $queue = RT::Model::Queue->new(current_user => RT->system_user);
my ($id, $val) = $queue->create( name => 'Test1');
ok($id, $val);

($id, $val) = $queue->create( name => '66');
ok(!$id, $val);


}

{

my $Queue = RT::Model::Queue->new(current_user => RT->system_user);
my ($id, $msg) = $Queue->create(name => "Foo");
ok ($id, "Foo $id was Created");
ok(my $group = RT::Model::Group->new(current_user => RT->system_user));
ok($group->load_queue_role_group(queue => $id, type=> 'requestor'));
ok ($group->id, "Found the ccs object for this Queue");


{
    my ($status, $msg) = $Queue->add_watcher(type => 'cc', email => 'bob@fsck.com');
    ok ($status, "Added bob at fsck.com as a requestor") or diag "error: $msg";
}
ok(my $bob = RT::Model::User->new(current_user => RT->system_user), "Creating a bob rt::user");
$bob->load_by_email('bob@fsck.com');
ok($bob->id,  "Found the bob rt user");
ok ($Queue->is_watcher(type => 'cc', principal_id => $bob->principal_id), "The queue actually has bob at fsck.com as a requestor");

{
    my ($status, $msg) = $Queue->delete_watcher(type =>'cc', email => 'bob@fsck.com');
    ok ($status, "Deleted bob from Ccs") or diag "error: $msg";
    ok (!$Queue->is_watcher(type => 'cc', principal_id => $bob->principal_id),
        "The queue no longer has bob at fsck.com as a requestor");
}

$group = RT::Model::Group->new(current_user => RT->system_user);
ok($group->load_queue_role_group(queue => $id, type=> 'cc'));
ok ($group->id, "Found the cc object for this Queue");
$group = RT::Model::Group->new(current_user => RT->system_user);
ok($group->load_queue_role_group(queue => $id, type=> 'admin_cc'));
ok ($group->id, "Found the admin_cc object for this Queue");


}

1;

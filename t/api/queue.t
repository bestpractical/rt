
use strict;
use warnings;
use RT::Test; use Test::More; 
plan tests => 27;
use RT;
use RT::Model::Queue;

{
    my $q = RT::Model::Queue->new(current_user => RT->system_user);

    is($q->status_schema->is_valid('new'), 1, 'New is a valid status');
    is($q->status_schema->is_valid('f00'), 0, 'f00 is not a valid status');

    is($q->status_schema->is_active('open'), 1, 'Open is a Active status');
    is($q->status_schema->is_active('rejected'), 0, 'Rejected is an inactive status');
    is($q->status_schema->is_active('f00'), 0, 'f00 is not a Active status');

    is($q->status_schema->is_inactive('new'), 0, 'New is a Active status');
    is($q->status_schema->is_inactive('rejected'), 1, 'rejeected is an Inactive status');
    is($q->status_schema->is_inactive('f00'), 0, 'f00 is not a Active status');
}

{
    my $queue = RT::Model::Queue->new(current_user => RT->system_user);
    my ($id, $val) = $queue->create( name => 'Test1');
    ok($id, $val);

    ($id, $val) = $queue->create( name => '66');
    ok(!$id, $val);
}

my $Queue = RT::Model::Queue->new(current_user => RT->system_user);
my ($id, $msg) = $Queue->create(name => "Foo");
ok ($id, "Foo $id was Created");


{
    my $group = RT::Model::Group->new(current_user => RT->system_user);
    ok($group->load_role_group(object => $Queue, type=> 'cc'));
    ok (!$group->id, "No cc group as there are no ccs yet");

    my ($status, $msg) = $Queue->add_watcher(type => 'cc', email => 'bob@fsck.com');
    ok ($status, "Added bob at fsck.com as a cc") or diag "error: $msg";

    $group = RT::Model::Group->new(current_user => RT->system_user);
    ok ($group->load_role_group(object => $Queue, type=> 'cc'));
    ok ($group->id, "Found the cc object for this Queue");

    ok (my $bob = RT::Model::User->new(current_user => RT->system_user), "Creating a bob rt::user");
    $bob->load_by_email('bob@fsck.com');
    ok ($bob->id,  "Found the bob rt user");

    ok ($Queue->is_watcher(type => 'cc', principal_id => $bob->principal_id),
        "The queue actually has bob at fsck.com as a requestor");
    ok ($Queue->is_watcher(type => 'cc', email => $bob->email),
        "The queue actually has bob at fsck.com as a requestor");

    ok (!$Queue->is_watcher(type => 'admin_cc', principal_id => $bob->principal_id),
        "bob is not an admin cc");
    ok (!$Queue->is_watcher(type => 'admin_cc', email => $bob->email),
        "bob is not an admin cc");

    ($status, $msg) = $Queue->delete_watcher(type =>'cc', email => 'bob@fsck.com');
    ok ($status, "Deleted bob from Ccs") or diag "error: $msg";

    ok (!$Queue->is_watcher(type => 'cc', principal_id => $bob->principal_id),
        "The queue no longer has bob at fsck.com as a requestor");
    ok (!$Queue->is_watcher(type => 'cc', email => $bob->email),
        "The queue no longer has bob at fsck.com as a requestor");

}

{
    my $group = RT::Model::Group->new(current_user => RT->system_user);
    ok($group->load_role_group(object => $Queue, type=> 'admin_cc'));
    ok (!$group->id, "No admin_cc group as there are no admin ccs yet");
}

1;

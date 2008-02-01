
use strict;
use warnings;
use RT::Test; use Test::More; 
plan tests => 25;
use RT;



{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

use RT::Model::Queue;


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

my $q = RT::Model::Queue->new(current_user => RT->system_user);
is($q->is_valid_status('new'), 1, 'New is a valid status');
is($q->is_valid_status('f00'), 0, 'f00 is not a valid status');


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

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


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

my $Queue = RT::Model::Queue->new(current_user => RT->system_user); my ($id, $msg) = $Queue->create(name => "Foo",
                );
ok ($id, "Foo $id was Created");
ok(my $group = RT::Model::Group->new(current_user => RT->system_user));
ok($group->load_queue_role_group(queue => $id, type=> 'Requestor'));
ok ($group->id, "Found the ccs object for this Queue");


ok (my ($add_id, $add_msg) = $Queue->add_watcher(type => 'Cc', email => 'bob@fsck.com'), "Added bob at fsck.com as a cc");
ok ($add_id, "Add succeeded: ($add_msg)");
ok(my $bob = RT::Model::User->new(current_user => RT->system_user), "Creating a bob rt::user");
$bob->load_by_email('bob@fsck.com');
ok($bob->id,  "Found the bob rt user");
ok ($Queue->is_watcher(type => 'Cc', principal_id => $bob->principal_id), "The queue actually has bob at fsck.com as a cc");;
ok (($add_id, $add_msg) = $Queue->delete_watcher(type =>'Cc', principal_id => $bob->principal_id ), "Removed bob at fsck.com as a cc");
ok (!$Queue->is_watcher(type => 'Cc', principal_id => $bob->principal_id), "The queue no longer has bob at fsck.com as a cc");;


$group = RT::Model::Group->new(current_user => RT->system_user);
ok($group->load_queue_role_group(queue => $id, type=> 'Cc'));
ok ($group->id, "Found the cc object for this Queue");
$group = RT::Model::Group->new(current_user => RT->system_user);
ok($group->load_queue_role_group(queue => $id, type=> 'AdminCc'));
ok ($group->id, "Found the AdminCc object for this Queue");


}

1;

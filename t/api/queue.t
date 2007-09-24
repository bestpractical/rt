
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

my $q = RT::Model::Queue->new(RT->SystemUser);
is($q->IsValidStatus('new'), 1, 'New is a valid status');
is($q->IsValidStatus('f00'), 0, 'f00 is not a valid status');


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

my $q = RT::Model::Queue->new(RT->SystemUser);
is($q->IsActiveStatus('new'), 1, 'New is a Active status');
is($q->IsActiveStatus('rejected'), 0, 'Rejected is an inactive status');
is($q->IsActiveStatus('f00'), 0, 'f00 is not a Active status');


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

my $q = RT::Model::Queue->new(RT->SystemUser);
is($q->IsInactiveStatus('new'), 0, 'New is a Active status');
is($q->IsInactiveStatus('rejected'), 1, 'rejeected is an Inactive status');
is($q->IsInactiveStatus('f00'), 0, 'f00 is not a Active status');


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

my $queue = RT::Model::Queue->new(RT->SystemUser);
my ($id, $val) = $queue->create( Name => 'Test1');
ok($id, $val);

($id, $val) = $queue->create( Name => '66');
ok(!$id, $val);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

my $Queue = RT::Model::Queue->new(RT->SystemUser); my ($id, $msg) = $Queue->create(Name => "Foo",
                );
ok ($id, "Foo $id was Created");
ok(my $group = RT::Model::Group->new(RT->SystemUser));
ok($group->loadQueueRoleGroup(Queue => $id, Type=> 'Cc'));
ok ($group->id, "Found the requestors object for this Queue");


ok (my ($add_id, $add_msg) = $Queue->AddWatcher(Type => 'Cc', Email => 'bob@fsck.com'), "Added bob at fsck.com as a requestor");
ok ($add_id, "Add succeeded: ($add_msg)");
ok(my $bob = RT::Model::User->new(RT->SystemUser), "Creating a bob rt::user");
$bob->load_by_email('bob@fsck.com');
ok($bob->id,  "Found the bob rt user");
ok ($Queue->IsWatcher(Type => 'Cc', PrincipalId => $bob->PrincipalId), "The Queue actually has bob at fsck.com as a requestor");;
ok (($add_id, $add_msg) = $Queue->deleteWatcher(Type =>'Cc', Email => 'bob@fsck.com'), "Added bob at fsck.com as a requestor");
ok (!$Queue->IsWatcher(Type => 'Cc', Principal => $bob->PrincipalId), "The Queue no longer has bob at fsck.com as a requestor");;


$group = RT::Model::Group->new(RT->SystemUser);
ok($group->loadQueueRoleGroup(Queue => $id, Type=> 'Cc'));
ok ($group->id, "Found the cc object for this Queue");
$group = RT::Model::Group->new(RT->SystemUser);
ok($group->loadQueueRoleGroup(Queue => $id, Type=> 'AdminCc'));
ok ($group->id, "Found the AdminCc object for this Queue");


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

1;


use strict;
use warnings;
use Test::More; 
plan tests => 25;
use RT;
use RT::Test;


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

use RT::Queue;


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

my $q = RT::Queue->new($RT::SystemUser);
ok($q->IsValidStatus('new')== 1, 'New is a valid status');
ok($q->IsValidStatus('f00')== 0, 'f00 is not a valid status');


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

my $q = RT::Queue->new($RT::SystemUser);
ok($q->IsActiveStatus('new')== 1, 'New is a Active status');
ok($q->IsActiveStatus('rejected')== 0, 'Rejected is an inactive status');
ok($q->IsActiveStatus('f00')== 0, 'f00 is not a Active status');


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

my $q = RT::Queue->new($RT::SystemUser);
ok($q->IsInactiveStatus('new')== 0, 'New is a Active status');
ok($q->IsInactiveStatus('rejected')== 1, 'rejeected is an Inactive status');
ok($q->IsInactiveStatus('f00')== 0, 'f00 is not a Active status');


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

my $queue = RT::Queue->new($RT::SystemUser);
my ($id, $val) = $queue->Create( Name => 'Test1');
ok($id, $val);

($id, $val) = $queue->Create( Name => '66');
ok(!$id, $val);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

my $Queue = RT::Queue->new($RT::SystemUser); my ($id, $msg) = $Queue->Create(Name => "Foo",
                );
ok ($id, "Foo $id was created");
ok(my $group = RT::Group->new($RT::SystemUser));
ok($group->LoadQueueRoleGroup(Queue => $id, Type=> 'Cc'));
ok ($group->Id, "Found the requestors object for this Queue");


ok (my ($add_id, $add_msg) = $Queue->AddWatcher(Type => 'Cc', Email => 'bob@fsck.com'), "Added bob at fsck.com as a requestor");
ok ($add_id, "Add succeeded: ($add_msg)");
ok(my $bob = RT::User->new($RT::SystemUser), "Creating a bob rt::user");
$bob->LoadByEmail('bob@fsck.com');
ok($bob->Id,  "Found the bob rt user");
ok ($Queue->IsWatcher(Type => 'Cc', PrincipalId => $bob->PrincipalId), "The Queue actually has bob at fsck.com as a requestor");;
ok (($add_id, $add_msg) = $Queue->DeleteWatcher(Type =>'Cc', Email => 'bob@fsck.com'), "Added bob at fsck.com as a requestor");
ok (!$Queue->IsWatcher(Type => 'Cc', Principal => $bob->PrincipalId), "The Queue no longer has bob at fsck.com as a requestor");;


$group = RT::Group->new($RT::SystemUser);
ok($group->LoadQueueRoleGroup(Queue => $id, Type=> 'Cc'));
ok ($group->Id, "Found the cc object for this Queue");
$group = RT::Group->new($RT::SystemUser);
ok($group->LoadQueueRoleGroup(Queue => $id, Type=> 'AdminCc'));
ok ($group->Id, "Found the AdminCc object for this Queue");


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

1;

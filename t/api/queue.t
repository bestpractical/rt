
use strict;
use warnings;
use RT;
use RT::Test tests => 24;


{

use RT::Queue;


}

{

my $q = RT::Queue->new($RT::SystemUser);
is($q->IsValidStatus('new'), 1, 'New is a valid status');
is($q->IsValidStatus('f00'), 0, 'f00 is not a valid status');


}

{

my $q = RT::Queue->new($RT::SystemUser);
is($q->IsActiveStatus('new'), 1, 'New is a Active status');
is($q->IsActiveStatus('rejected'), 0, 'Rejected is an inactive status');
is($q->IsActiveStatus('f00'), 0, 'f00 is not a Active status');


}

{

my $q = RT::Queue->new($RT::SystemUser);
is($q->IsInactiveStatus('new'), 0, 'New is a Active status');
is($q->IsInactiveStatus('rejected'), 1, 'rejeected is an Inactive status');
is($q->IsInactiveStatus('f00'), 0, 'f00 is not a Active status');


}

{

my $queue = RT::Queue->new($RT::SystemUser);
my ($id, $val) = $queue->Create( Name => 'Test1');
ok($id, $val);

($id, $val) = $queue->Create( Name => '66');
ok(!$id, $val);


}

{

my $Queue = RT::Queue->new($RT::SystemUser);
my ($id, $msg) = $Queue->Create(Name => "Foo");
ok ($id, "Foo $id was created");
ok(my $group = RT::Group->new($RT::SystemUser));
ok($group->LoadQueueRoleGroup(Queue => $id, Type=> 'Requestor'));
ok ($group->Id, "Found the requestors object for this Queue");

{
    my ($status, $msg) = $Queue->AddWatcher(Type => 'Cc', Email => 'bob@fsck.com');
    ok ($status, "Added bob at fsck.com as a requestor") or diag "error: $msg";
}

ok(my $bob = RT::User->new($RT::SystemUser), "Creating a bob rt::user");
$bob->LoadByEmail('bob@fsck.com');
ok($bob->Id,  "Found the bob rt user");
ok ($Queue->IsWatcher(Type => 'Cc', PrincipalId => $bob->PrincipalId), "The Queue actually has bob at fsck.com as a requestor");

{
    my ($status, $msg) = $Queue->DeleteWatcher(Type =>'Cc', Email => 'bob@fsck.com');
    ok ($status, "Deleted bob from Ccs") or diag "error: $msg";
    ok (!$Queue->IsWatcher(Type => 'Cc', PrincipalId => $bob->PrincipalId),
        "The Queue no longer has bob at fsck.com as a requestor");
}

$group = RT::Group->new($RT::SystemUser);
ok($group->LoadQueueRoleGroup(Queue => $id, Type=> 'Cc'));
ok ($group->Id, "Found the cc object for this Queue");
$group = RT::Group->new($RT::SystemUser);
ok($group->LoadQueueRoleGroup(Queue => $id, Type=> 'AdminCc'));
ok ($group->Id, "Found the AdminCc object for this Queue");


}

1;

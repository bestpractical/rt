use strict;
use warnings;

use RT::Test tests => undef;

my $general = RT::Test->load_or_create_queue( Name => 'General' );
my $inbox = RT::Test->load_or_create_queue( Name => 'Inbox' );
my $specs = RT::Test->load_or_create_queue( Name => 'Specs' );
my $development = RT::Test->load_or_create_queue( Name => 'Development' );

diag 'testing no roles yet' if $ENV{'TEST_VERBOSE'};
{
    my $roles = RT::CustomRoles->new(RT->SystemUser);
    $roles->UnLimit;
    is($roles->Count, 0, 'no roles created yet');

    is_deeply([sort RT::System->Roles], ['AdminCc', 'Cc', 'Contact', 'HeldBy', 'Owner', 'Requestor'], 'System->Roles');
    is_deeply([sort RT::Queue->Roles], ['AdminCc', 'Cc', 'Owner', 'Requestor'], 'Queue->Roles');
    is_deeply([sort $general->Roles], ['AdminCc', 'Cc', 'Owner', 'Requestor'], 'General->Roles');
    is_deeply([sort RT::Ticket->Roles], ['AdminCc', 'Cc', 'Owner', 'Requestor'], 'Ticket->Roles');
    is_deeply([sort RT::Queue->ManageableRoleGroupTypes], ['AdminCc', 'Cc'], 'Queue->ManageableRoleTypes');
    is_deeply([sort $general->ManageableRoleGroupTypes], ['AdminCc', 'Cc'], 'General->ManageableRoleTypes');
}

diag 'create a single-member role' if $ENV{'TEST_VERBOSE'};
my $engineer;
{
    $engineer = RT::CustomRole->new(RT->SystemUser);
    my ($ok, $msg) = $engineer->Create(
        Name      => 'Engineer-' . $$,
        MaxValues => 1,
    );
    ok($ok, "created role: $msg");

    is($engineer->Name, 'Engineer-' . $$, 'role name');
    is($engineer->MaxValues, 1, 'role is single member');
    ok($engineer->SingleValue, 'role is single member');
    ok(!$engineer->UnlimitedValues, 'role is single member');
    ok(!$engineer->IsAddedToAny, 'role is not applied to any queues yet');
    ok(RT::Queue->Role('RT::CustomRole-1')->{Single}, 'role is single member');

    is_deeply([sort RT::System->Roles], ['AdminCc', 'Cc', 'Contact', 'HeldBy', 'Owner', 'RT::CustomRole-1', 'Requestor'], 'System->Roles');
    is_deeply([sort RT::Queue->Roles], ['AdminCc', 'Cc', 'Owner', 'RT::CustomRole-1', 'Requestor'], 'Queue->Roles');
    is_deeply([sort $general->Roles], ['AdminCc', 'Cc', 'Owner', 'Requestor'], 'General->Roles');
    is_deeply([sort RT::Ticket->Roles], ['AdminCc', 'Cc', 'Owner', 'RT::CustomRole-1', 'Requestor'], 'Ticket->Roles');
    is_deeply([sort RT::Queue->ManageableRoleGroupTypes], ['AdminCc', 'Cc'], 'Queue->ManageableRoleTypes');
    is_deeply([sort $general->ManageableRoleGroupTypes], ['AdminCc', 'Cc'], 'General->ManageableRoleTypes');
}

diag 'create a multi-member role' if $ENV{'TEST_VERBOSE'};
my $sales;
{
    $sales = RT::CustomRole->new(RT->SystemUser);
    my ($ok, $msg) = $sales->Create(
        Name      => 'Sales-' . $$,
        MaxValues => 0,
    );
    ok($ok, "created role: $msg");

    is($sales->Name, 'Sales-' . $$, 'role name');
    is($sales->MaxValues, 0, 'role is multi member');
    ok(!$sales->SingleValue, 'role is multi member');
    ok($sales->UnlimitedValues, 'role is multi member');
    ok(!$sales->IsAddedToAny, 'role is not applied to any queues yet');
    ok(!RT::Queue->Role('RT::CustomRole-2')->{Single}, 'role is multi member');

    is_deeply([sort RT::System->Roles], ['AdminCc', 'Cc', 'Contact', 'HeldBy', 'Owner', 'RT::CustomRole-1', 'RT::CustomRole-2', 'Requestor'], 'System->Roles');
    is_deeply([sort RT::Queue->Roles], ['AdminCc', 'Cc', 'Owner', 'RT::CustomRole-1', 'RT::CustomRole-2', 'Requestor'], 'Queue->Roles');
    is_deeply([sort $general->Roles], ['AdminCc', 'Cc', 'Owner', 'Requestor'], 'General->Roles');
    is_deeply([sort RT::Ticket->Roles], ['AdminCc', 'Cc', 'Owner', 'RT::CustomRole-1', 'RT::CustomRole-2', 'Requestor'], 'Ticket->Roles');
    is_deeply([sort RT::Queue->ManageableRoleGroupTypes], ['AdminCc', 'Cc', 'RT::CustomRole-2'], 'Queue->ManageableRoleTypes');
    is_deeply([sort $general->ManageableRoleGroupTypes], ['AdminCc', 'Cc'], 'General->ManageableRoleTypes');
}

diag 'collection methods' if $ENV{'TEST_VERBOSE'};
{
    my $roles = RT::CustomRoles->new(RT->SystemUser);
    $roles->UnLimit;
    $roles->OrderBy(
        FIELD => 'id',
        ORDER => 'Asc',
    );

    is($roles->Count, 2, 'two roles');
    is($roles->Next->Name, 'Engineer-' . $$, 'first role');
    is($roles->Next->Name, 'Sales-' . $$, 'second role');

    my $single = RT::CustomRoles->new(RT->SystemUser);
    $single->LimitToSingleValue;
    is($single->Count, 1, 'one single-value role');
    is($single->Next->Name, 'Engineer-' . $$, 'single role');

    my $multi = RT::CustomRoles->new(RT->SystemUser);
    $multi->LimitToMultipleValue;
    is($multi->Count, 1, 'one multi-value role');
    is($multi->Next->Name, 'Sales-' . $$, 'single role');
}

diag 'roles not added to any queues yet' if $ENV{'TEST_VERBOSE'};
{
    for my $queue ($general, $inbox, $specs, $development) {
        my $roles = RT::CustomRoles->new(RT->SystemUser);
        $roles->LimitToObjectId($queue->Id);
        is($roles->Count, 0, 'no roles yet for ' . $queue->Name);

        my $qroles = $queue->CustomRoles;
        is($qroles->Count, 0, 'no roles yet from ' . $queue->Name);

        ok(!$sales->IsAdded($queue->Id), 'Sales is not added to ' . $queue->Name);
        ok(!$engineer->IsAdded($queue->Id), 'Engineer is not added to ' . $queue->Name);
    }
}

diag 'add roles to queues' if $ENV{'TEST_VERBOSE'};
{
    my ($ok, $msg) = $sales->AddToObject($inbox->id);
    ok($ok, "added Sales to Inbox: $msg");

    ($ok, $msg) = $sales->AddToObject($specs->id);
    ok($ok, "added Sales to Specs: $msg");

    ($ok, $msg) = $engineer->AddToObject($specs->id);
    ok($ok, "added Engineer to Specs: $msg");

    ($ok, $msg) = $engineer->AddToObject($development->id);
    ok($ok, "added Engineer to Development: $msg");
}

diag 'roles now added to queues' if $ENV{'TEST_VERBOSE'};
{
    is_deeply([sort RT::System->Roles], ['AdminCc', 'Cc', 'Contact', 'HeldBy', 'Owner', 'RT::CustomRole-1', 'RT::CustomRole-2', 'Requestor'], 'System->Roles');
    is_deeply([sort RT::Queue->Roles], ['AdminCc', 'Cc', 'Owner', 'RT::CustomRole-1', 'RT::CustomRole-2', 'Requestor'], 'Queue->Roles');
    is_deeply([sort RT::Ticket->Roles], ['AdminCc', 'Cc', 'Owner', 'RT::CustomRole-1', 'RT::CustomRole-2', 'Requestor'], 'Ticket->Roles');
    is_deeply([sort RT::Queue->ManageableRoleGroupTypes], ['AdminCc', 'Cc', 'RT::CustomRole-2'], 'Queue->ManageableRoleTypes');

    # General
    {
        my $roles = RT::CustomRoles->new(RT->SystemUser);
        $roles->LimitToObjectId($general->Id);
        is($roles->Count, 0, 'no roles for General');

        my $qroles = $general->CustomRoles;
        is($qroles->Count, 0, 'no roles from General');

        ok(!$sales->IsAdded($general->Id), 'Sales is not added to General');
        ok(!$engineer->IsAdded($general->Id), 'Engineer is not added to General');

        is_deeply([sort $general->Roles], ['AdminCc', 'Cc', 'Owner', 'Requestor'], 'General->Roles');
        is_deeply([sort $general->ManageableRoleGroupTypes], ['AdminCc', 'Cc'], 'General->ManageableRoleTypes');
        is_deeply([grep { $general->IsManageableRoleGroupType($_) } 'AdminCc', 'Cc', 'Owner', 'RT::CustomRole-1', 'RT::CustomRole-2', 'Requestor', 'Nonexistent'], ['AdminCc', 'Cc'], 'General IsManageableRoleGroupType');
    }

    # Inbox
    {
        my $roles = RT::CustomRoles->new(RT->SystemUser);
        $roles->LimitToObjectId($inbox->Id);
        is($roles->Count, 1, 'one role for Inbox');
        is($roles->Next->Name, 'Sales-' . $$, 'and the one role is Sales');

        my $qroles = $inbox->CustomRoles;
        is($qroles->Count, 1, 'one role from Inbox');
        is($qroles->Next->Name, 'Sales-' . $$, 'and the one role is Sales');

        ok($sales->IsAdded($inbox->Id), 'Sales is added to Inbox');
        ok(!$engineer->IsAdded($inbox->Id), 'Engineer is not added to Inbox');

        is_deeply([sort $inbox->Roles], ['AdminCc', 'Cc', 'Owner', $sales->GroupType, 'Requestor'], 'Inbox->Roles');
        is_deeply([sort $inbox->ManageableRoleGroupTypes], ['AdminCc', 'Cc', $sales->GroupType], 'Inbox->ManageableRoleTypes');
        is_deeply([grep { $inbox->IsManageableRoleGroupType($_) } 'AdminCc', 'Cc', 'Owner', 'RT::CustomRole-1', 'RT::CustomRole-2', 'Requestor', 'Nonexistent'], ['AdminCc', 'Cc', 'RT::CustomRole-2'], 'Inbox IsManageableRoleGroupType');
    }

    # Specs
    {
        my $roles = RT::CustomRoles->new(RT->SystemUser);
        $roles->LimitToObjectId($specs->Id);
        $roles->OrderBy(
            FIELD => 'id',
            ORDER => 'Asc',
        );
        is($roles->Count, 2, 'two roles for Specs');
        is($roles->Next->Name, 'Engineer-' . $$, 'and the first role is Engineer');
        is($roles->Next->Name, 'Sales-' . $$, 'and the second role is Sales');

        my $qroles = $specs->CustomRoles;
        $qroles->OrderBy(
            FIELD => 'id',
            ORDER => 'Asc',
        );
        is($qroles->Count, 2, 'two roles from Specs');
        is($qroles->Next->Name, 'Engineer-' . $$, 'and the first role is Engineer');
        is($qroles->Next->Name, 'Sales-' . $$, 'and the second role is Sales');

        ok($sales->IsAdded($specs->Id), 'Sales is added to Specs');
        ok($engineer->IsAdded($specs->Id), 'Engineer is added to Specs');

        is_deeply([sort $specs->Roles], ['AdminCc', 'Cc', 'Owner', $engineer->GroupType, $sales->GroupType, 'Requestor'], 'Specs->Roles');
        is_deeply([sort $specs->ManageableRoleGroupTypes], ['AdminCc', 'Cc', $sales->GroupType], 'Specs->ManageableRoleTypes');
        is_deeply([grep { $specs->IsManageableRoleGroupType($_) } 'AdminCc', 'Cc', 'Owner', 'RT::CustomRole-1', 'RT::CustomRole-2', 'Requestor', 'Nonexistent'], ['AdminCc', 'Cc', 'RT::CustomRole-2'], 'Specs IsManageableRoleGroupType');
    }

    # Development
    {
        my $roles = RT::CustomRoles->new(RT->SystemUser);
        $roles->LimitToObjectId($development->Id);
        is($roles->Count, 1, 'one role for Development');
        is($roles->Next->Name, 'Engineer-' . $$, 'and the one role is sales');

        my $qroles = $development->CustomRoles;
        is($qroles->Count, 1, 'one role from Development');
        is($qroles->Next->Name, 'Engineer-' . $$, 'and the one role is sales');

        ok(!$sales->IsAdded($development->Id), 'Sales is not added to Development');
        ok($engineer->IsAdded($development->Id), 'Engineer is added to Development');

        is_deeply([sort $development->Roles], ['AdminCc', 'Cc', 'Owner', $engineer->GroupType, 'Requestor'], 'Development->Roles');
        is_deeply([sort $development->ManageableRoleGroupTypes], ['AdminCc', 'Cc'], 'Development->ManageableRoleTypes');
        is_deeply([grep { $development->IsManageableRoleGroupType($_) } 'AdminCc', 'Cc', 'Owner', 'RT::CustomRole-1', 'RT::CustomRole-2', 'Requestor', 'Nonexistent'], ['AdminCc', 'Cc'], 'Development IsManageableRoleGroupType');
    }
}

diag 'role names' if $ENV{'TEST_VERBOSE'};
{
    my ($ok, $msg) = $engineer->SetName('Programmer-' . $$);
    ok($ok, "SetName: $msg");
    is($engineer->Name, 'Programmer-' . $$, 'new name');

    # should be okay
    ($ok, $msg) = $engineer->SetName('Programmer-' . $$);
    ok($ok || $msg =~ /already the current value/ , "SetName: $msg");
    is($engineer->Name, 'Programmer-' . $$, 'new name');

    my $playground = RT::CustomRole->new(RT->SystemUser);
    ($ok, $msg) = $playground->Create(Name => 'Playground-' . $$, MaxValues => 1);
    ok($ok, "playground role: $msg");

    for my $name (
        'Programmer-' . $$,
        'proGRAMMER-' . $$,
        'Cc',
        'CC',
        'AdminCc',
        'ADMIN CC',
        'Requestor',
        'requestors',
        'Owner',
        'OWNer',
    ) {
        # creating a role with that name should fail
        my $new = RT::CustomRole->new(RT->SystemUser);
        ($ok, $msg) = $new->Create(Name => $name, MaxValues => 1);
        ok(!$ok, "creating a role with duplicate name $name should fail: $msg");

        # updating an existing role with the dupe name should fail too
        ($ok, $msg) = $playground->SetName($name);
        ok(!$ok, "updating an existing role with duplicate name $name should fail: $msg");
        is($playground->Name, 'Playground-' . $$, 'name stayed the same');
    }

    # make sure we didn't create any new roles
    my $roles = RT::CustomRoles->new(RT->SystemUser);
    $roles->UnLimit;
    is($roles->Count, 3, 'three roles (original two plus playground)');

    is_deeply([sort RT::System->Roles], ['AdminCc', 'Cc', 'Contact', 'HeldBy', 'Owner', 'RT::CustomRole-1', 'RT::CustomRole-2', 'RT::CustomRole-3', 'Requestor'], 'No new System->Roles');
    is_deeply([sort RT::Queue->Roles], ['AdminCc', 'Cc', 'Owner', 'RT::CustomRole-1', 'RT::CustomRole-2', 'RT::CustomRole-3', 'Requestor'], 'No new Queue->Roles');
    is_deeply([sort RT::Ticket->Roles], ['AdminCc', 'Cc', 'Owner', 'RT::CustomRole-1', 'RT::CustomRole-2', 'RT::CustomRole-3', 'Requestor'], 'No new Ticket->Roles');
    is_deeply([sort RT::Queue->ManageableRoleGroupTypes], ['AdminCc', 'Cc', 'RT::CustomRole-2'], 'No new Queue->ManageableRoleGroupTypes');
}

diag 'load by name and id' if $ENV{'TEST_VERBOSE'};
{
    my $role = RT::CustomRole->new(RT->SystemUser);
    $role->Load($engineer->id);
    is($role->Name, 'Programmer-' . $$, 'load by id');

    $role = RT::CustomRole->new(RT->SystemUser);
    $role->Load('Sales-' . $$);
    is($role->id, $sales->id, 'load by name');
}

diag 'LabelForRole' if $ENV{'TEST_VERBOSE'};
{
    is($inbox->LabelForRole($sales->GroupType), 'Sales-' . $$, 'Inbox label for Sales');
    is($specs->LabelForRole($sales->GroupType), 'Sales-' . $$, 'Specs label for Sales');
    is($specs->LabelForRole($engineer->GroupType), 'Programmer-' . $$, 'Specs label for Engineer');
    is($development->LabelForRole($engineer->GroupType), 'Programmer-' . $$, 'Development label for Engineer');
}

done_testing;

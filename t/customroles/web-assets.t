use strict;
use warnings;
use RT::Test::Assets tests => undef;
my ($baseurl, $m) = RT::Test::Assets->started_ok;
ok $m->login, "Logged in agent";


my $catalog = create_catalog( Name => "Software" );
ok $catalog->id, "Created Catalog";

my $owner = RT::Test->load_or_create_user(Name => 'owner', EmailAddress => 'owner@example.com');
my $licensee = RT::Test->load_or_create_user(Name => 'licensee@example.com', EmailAddress => 'licensee@example.com', Password => 'password');

my $role;
my ($asset, $asset2, $asset3);

diag "Create custom role and apply it to General assets";
{
    $m->follow_link_ok({ id => "admin-custom-roles-create" }, "Custom Role create link");
    $m->submit_form_ok({
        with_fields => {
            Name        => 'Licensee',
            Description => 'The person who licensed the software',
            LookupType  => RT::Asset->CustomFieldLookupType,
            EntryHint   => 'Make sure user has real name set',
        },
    }, "submitted create form");
    $m->text_like(qr/Custom role created/, "Found created message");
    my ($id) = $m->uri =~ /id=(\d+)/;
    ok($id, 'Got role id');

    $role = RT::CustomRole->new(RT->SystemUser);
    $role->Load($id);
    is $role->id, $id, "id matches";
    is $role->Name, "Licensee", "Name matches";
    is $role->Description, "The person who licensed the software", "Description matches";
    is $role->LookupType, RT::Asset->CustomFieldLookupType, "LookupType matches";
    is $role->EntryHint, "Make sure user has real name set", "EntryHint matches";

    ok(!$role->IsAdded($catalog->Id), 'not added to catalog yet');

    $m->follow_link_ok({ id => "page-applies-to" }, "Applies to link");
    $m->submit_form_ok({
        with_fields => {
            ("AddRole-" . $id) => $catalog->Id,
        },
        button => 'Update',
    }, "submitted applies to form");
    $m->text_like(qr/Object created/, "Found update message");

    # refresh cache
    RT::CustomRoles->RegisterRoles;

    ok($role->IsAdded($catalog->Id), 'added to catalog now');
    is_deeply([sort $catalog->Roles], [sort 'Contact', 'HeldBy', 'Owner', $role->GroupType], '->Roles');
}

diag "Create asset with custom role";
{
    $m->follow_link_ok({ id => "assets-create" }, "Asset create link");
    $m->submit_form_ok({ with_fields => { Catalog => $catalog->id } }, "Picked a catalog");
    $m->text_contains('Licensee', 'custom role name');
    $m->text_contains('Make sure user has real name set', 'custom role entry hint');

    $m->submit_form_ok({
        with_fields => {
            id               => 'new',
            Name             => 'Some Software',
            Owner            => 'owner@example.com',
            $role->GroupType => 'licensee@example.com',
        },
    }, "submitted create form");
    $m->text_like(qr/Asset .* created/, "Found created message");
    my ($id) = $m->uri =~ /id=(\d+)/;

    $asset = RT::Asset->new( RT->SystemUser );
    $asset->Load($id);
    is $asset->id, $id, "id matches";
    is $asset->Name, "Some Software", "Name matches";
    is $asset->Owner->EmailAddress, 'owner@example.com', "Owner matches";
    is $asset->RoleAddresses($role->GroupType), 'licensee@example.com', "Licensee matches";
}

diag "Grant permissions on Licensee";
{
    $m->follow_link_ok({ id => "admin-assets-catalogs-select" }, "Admin assets");
    $m->follow_link_ok({ text => 'Software' }, "Picked a catalog");
    $m->follow_link_ok({ id => 'page-group-rights' }, "Group rights");

    $m->text_contains('Licensee', 'role group name');

    my $acl_id = $catalog->RoleGroup($role->GroupType)->Id;

    $m->submit_form_ok({
        with_fields => {
            "SetRights-" . $acl_id . '-RT::Catalog-' . $catalog->id => 'ShowAsset',
        },
    }, "submitted rights form");
    $m->text_contains("Granted right 'ShowAsset' to Licensee");

    my $privileged = RT::Group->new(RT->SystemUser);
    $privileged->LoadSystemInternalGroup('Privileged');
    $m->submit_form_ok({
        with_fields => {
            "SetRights-" . $privileged->Id . '-RT::Catalog-' . $catalog->id => 'SeeCustomRole',
        },
    }, "submitted rights form");
    $m->text_contains("Granted right 'SeeCustomRole' to Privileged");

    RT::Principal::InvalidateACLCache();
}

diag "Create asset without custom role";
{
    $m->follow_link_ok({ id => "assets-create" }, "Asset create link");
    $m->submit_form_ok({ with_fields => { Catalog => $catalog->id } }, "Picked a catalog");
    $m->text_contains('Licensee', 'custom role name');
    $m->text_contains('Make sure user has real name set', 'custom role entry hint');

    $m->submit_form_ok({
        with_fields => {
            id               => 'new',
            Name             => 'More Software',
            Owner            => 'owner@example.com',
        },
    }, "submitted create form");
    $m->text_like(qr/Asset .* created/, "Found created message");
    my ($id) = $m->uri =~ /id=(\d+)/;

    $asset2 = RT::Asset->new( RT->SystemUser );
    $asset2->Load($id);
    is $asset2->id, $id, "id matches";
    is $asset2->Name, "More Software", "Name matches";
    is $asset2->Owner->EmailAddress, 'owner@example.com', "Owner matches";
    is $asset2->RoleAddresses($role->GroupType), '', "No Licensee";
}

diag "Search by custom role";
{
    $m->follow_link_ok({ id => "assets-search" }, "Asset search link");
    $m->submit_form_ok({ with_fields => { Catalog => $catalog->Id } }, "Picked a catalog");
    $m->submit_form_ok({
        with_fields => {
            'Role.' . $role->GroupType => 'licensee@example.com',
        },
        button => 'SearchAssets',
    }, "Search by role");

    $m->text_contains('Some Software', 'search hit');
    $m->text_lacks('More Software', 'search miss');

    $m->submit_form_ok({
        with_fields => {
            'Role.' . $role->GroupType => '',
            '!Role.' . $role->GroupType => 'licensee@example.com',
        },
        button => 'SearchAssets',
    }, "Search by role");

    $m->text_lacks('Some Software', 'search miss');
    $m->text_contains('More Software', 'search hit');
}

diag "Test permissions on Licensee";
{
    $m->logout;
    $m->login('licensee@example.com', 'password');

    $m->get_ok("$baseurl/Asset/Display.html?id=".$asset->Id);
    $m->text_contains('Some Software', 'asset name shows on page');
    $m->text_contains('Licensee', 'role name shows on page');

    $m->get_ok("$baseurl/Asset/Display.html?id=".$asset2->Id);
    $m->text_lacks('More Software', 'asset name does not show on page');
    $m->text_lacks('Licensee', 'role name does not show on page');
    $m->text_contains("You don't have permission to view this asset.");
    $m->warning_like( qr/You don't have permission to view this asset/, 'got warning' );
}

$m->logout;
$m->login; # log back in as root

diag "Disable role";
{
    $m->follow_link_ok({ id => "admin-custom-roles-select" }, "Custom Role select link");
    $m->follow_link_ok({ text => 'Licensee' }, "Picked a custom role");
    $m->submit_form_ok({
        with_fields => {
            Enabled => 0,
        },
    }, "submitted update form");
    $m->text_contains('Custom role disabled');

    # refresh cache
    RT::CustomRoles->RegisterRoles;

    $role->Load($role->Id);
    is $role->Name, "Licensee", "Name matches";
    ok $role->Disabled, "now disabled";

    is_deeply([sort $catalog->Roles], [sort 'Contact', 'HeldBy', 'Owner'], '->Roles no longer includes Licensee');
}

diag "Test permissions on Licensee";
{
    $m->logout;
    $m->login('licensee@example.com', 'password');

    $m->get_ok("$baseurl/Asset/Display.html?id=".$asset->Id);
    $m->text_lacks('Some Software', 'asset name does not show on page');
    $m->text_lacks('Licensee', 'role name does not show on page');
    $m->text_contains("You don't have permission to view this asset.");
    $m->warning_like( qr/You don't have permission to view this asset/, 'got warning' );

    $m->get_ok("$baseurl/Asset/Display.html?id=".$asset2->Id);
    $m->text_lacks('More Software', 'asset name does not show on page');
    $m->text_lacks('Licensee', 'role name does not show on page');
    $m->text_contains("You don't have permission to view this asset.");
    $m->warning_like( qr/You don't have permission to view this asset/, 'got warning' );
}

$m->logout;
$m->login; # log back in as root

diag "Create asset with disabled custom role";
{
    $m->follow_link_ok({ id => "assets-create" }, "Asset create link");
    $m->submit_form_ok({ with_fields => { Catalog => $catalog->id } }, "Picked a catalog");
    $m->text_lacks('Licensee', 'custom role name');
    $m->text_lacks('Make sure user has real name set', 'custom role entry hint');

    $m->submit_form_ok({
        with_fields => {
            id               => 'new',
            Name             => 'All Software',
            Owner            => 'owner@example.com',
        },
    }, "submitted create form");
    $m->text_like(qr/Asset .* created/, "Found created message");
    my ($id) = $m->uri =~ /id=(\d+)/;

    $asset3 = RT::Asset->new( RT->SystemUser );
    $asset3->Load($id);
    is $asset3->id, $id, "id matches";
    is $asset3->Name, "All Software", "Name matches";
    is $asset3->Owner->EmailAddress, 'owner@example.com', "Owner matches";
    is $asset3->RoleAddresses($role->GroupType), '', "No Licensee";
}

undef $m;
done_testing;

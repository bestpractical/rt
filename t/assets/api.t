use strict;
use warnings;

use RT::Test::Assets tests => undef;
use Test::Warn;

my $catalog;

diag "Create a catalog";
{
    $catalog = create_catalog( Name => 'Test Catalog', Disabled => 1 );
    ok $catalog && $catalog->id, "Created catalog";
    is $catalog->Name, "Test Catalog", "Name is correct";
    ok $catalog->Disabled, "Disabled";

    my $asset;
    warning_like {
        $asset = create_asset( Name => "Test", Catalog => $catalog->id );
    } qr/^Failed to create asset .* Invalid catalog/i;
    ok !$asset, "Couldn't create asset in disabled catalog";

    my ($ok, $msg) = $catalog->SetDisabled(0);
    ok $ok, "Enabled catalog: $msg";
    ok !$catalog->Disabled, "Enabled";
}

diag "Create basic asset (no CFs)";
{
    my $asset = RT::Asset->new( RT->SystemUser );
    my ($id, $msg) = $asset->Create(
        Name        => 'Thinkpad T420s',
        Description => 'Laptop',
        Catalog     => $catalog->Name,
    );
    ok $id, "Created: $msg";
    is $asset->id, $id, "id matches";
    is $asset->Name, "Thinkpad T420s", "Name matches";
    is $asset->Description, "Laptop", "Description matches";

    # Create txn
    my @txns = @{$asset->Transactions->ItemsArrayRef};
    is scalar @txns, 1, "One transaction";
    is $txns[0]->Type, "Create", "... of type Create";

    # Update
    my ($txnid, $txnmsg) = $asset->SetName("Lenovo Thinkpad T420s");
    ok $txnid, "Updated Name: $txnmsg";
    is $asset->Name, "Lenovo Thinkpad T420s", "New Name matches";

    # Set txn
    @txns = @{$asset->Transactions->ItemsArrayRef};
    is scalar @txns, 2, "Two transactions";
    is $txns[1]->Type, "Set", "... the second of which is Set";
    is $txns[1]->Field, "Name", "... Field is Name";
    is $txns[1]->OldValue, "Thinkpad T420s", "... OldValue is correct";

    # Delete
    my ($ok, $err) = $asset->Delete;
    ok !$ok, "Deletes are prevented: $err";
    $asset->Load($id);
    ok $asset->id, "Asset not deleted";
}

diag "Create with CFs";
{
    my $height = create_cf( Name => 'Height' );
    ok $height->id, "Created CF";

    my $material = create_cf( Name => 'Material' );
    ok $material->id, "Created CF";

    ok apply_cfs($height, $material), "Applied CFs";

    my $asset = RT::Asset->new( RT->SystemUser );
    my ($id, $msg) = $asset->Create(
        Name                        => 'Standing desk',
        "CustomField-".$height->id  => '46"',
        "CustomField-Material"      => 'pine',
        Catalog                     => $catalog->Name,
    );
    ok $id, "Created: $msg";
    is $asset->FirstCustomFieldValue('Height'), '46"', "Found height";
    is $asset->FirstCustomFieldValue('Material'), 'pine', "Found material";
    is $asset->Transactions->Count, 1, "Only a single txn";
}

note "Create/update with Roles";
{
    my $root = RT::User->new( RT->SystemUser );
    $root->Load("root");
    ok $root->id, "Found root";

    my $bps = RT::Test->load_or_create_user( Name => "BPS" );
    ok $bps->id, "Created BPS user";

    my $asset = RT::Asset->new( RT->SystemUser );
    my ($id, $msg) = $asset->Create(
        Name    => 'RT server',
        HeldBy  => $root->PrincipalId,
        Owner   => $bps->PrincipalId,
        Contact => $bps->PrincipalId,
        Catalog => $catalog->id,
    );
    ok $id, "Created: $msg";
    is $asset->HeldBy->UserMembersObj->First->Name, "root", "root is Holder";
    is $asset->Owner->Name, "BPS", "BPS is Owner";
    is $asset->Contacts->UserMembersObj->First->Name, "BPS", "BPS is Contact";

    my $sysadmins = RT::Group->new( RT->SystemUser );
    $sysadmins->CreateUserDefinedGroup( Name => 'Sysadmins' );
    ok $sysadmins->id, "Created group";
    is $sysadmins->Name, "Sysadmins", "Got group name";

    (my $ok, $msg) = $asset->AddRoleMember(
        Type        => 'Contact',
        Group       => 'Sysadmins',
    );
    ok $ok, "Added Sysadmins as Contact: $msg";
    is $asset->Contacts->MembersObj->Count, 2, "Found two members";

    my @txn = grep { $_->Type eq 'AddWatcher' } @{$asset->Transactions->ItemsArrayRef};
    ok @txn == 1, "Found one AddWatcher txn";
    is $txn[0]->Field, "Contact", "... of a Contact";
    is $txn[0]->NewValue, $sysadmins->PrincipalId, "... for the right principal";

    ($ok, $msg) = $asset->DeleteRoleMember(
        Type        => 'Contact',
        PrincipalId => $bps->PrincipalId,
    );
    ok $ok, "Removed BPS user as Contact: $msg";
    is $asset->Contacts->MembersObj->Count, 1, "Now just one member";
    is $asset->Contacts->GroupMembersObj(Recursively => 0)->First->Name, "Sysadmins", "... it's Sysadmins";

    @txn = grep { $_->Type eq 'DelWatcher' } @{$asset->Transactions->ItemsArrayRef};
    ok @txn == 1, "Found one DelWatcher txn";
    is $txn[0]->Field, "Contact", "... of a Contact";
    is $txn[0]->OldValue, $bps->PrincipalId, "... for the right principal";
}

diag "Custom Field handling";
{
    diag "Make sure we don't load queue CFs";
    my $queue_cf = RT::CustomField->new( RT->SystemUser );
    my ($ok, $msg) = $queue_cf->Create(
        Name       => "Queue CF",
        Type       => "Text",
        LookupType => RT::Queue->CustomFieldLookupType,
    );
    ok( $queue_cf->Id, "Created test CF: " . $queue_cf->Id);

    my $cf1 = RT::CustomField->new( RT->SystemUser );
    $cf1->LoadByNameAndCatalog ( Name => "Queue CF" );

    ok( (not $cf1->Id), "Queue CF not loaded with LoadByNameAndCatalog");

    my $cf2 = RT::CustomField->new( RT->SystemUser );
    $cf2->LoadByNameAndCatalog ( Name => "Height" );
    ok( $cf2->Id, "Loaded CF id: " . $cf2->Id . " with name");
    ok( $cf2->Name, "Loaded CF name: " . $cf2->Name . " with name");

    my $cf3 = RT::CustomField->new( RT->SystemUser );
    ($ok, $msg) = $cf3->LoadByNameAndCatalog ( Name => "Height", Catalog => $catalog->Name );
    ok( (not $cf3->Id), "CF 'Height'"
      . " not added to catalog: " . $catalog->Name);

    my $color = create_cf( Name => 'Color'  );
    ok $color->Id, "Created CF " . $color->Name;
    ($ok, $msg) = $color->AddToObject( $catalog );

    ($ok, $msg) = $color->LoadByNameAndCatalog ( Name => "Color", Catalog => $catalog->Name );
    ok( $color->Id, "Loaded CF id: " . $color->Id
      . " for catalog: " . $catalog->Name);
    ok( $color->Name, "Loaded CF name: " . $color->Name
    . " for catalog: " . $catalog->Name);

}


done_testing;

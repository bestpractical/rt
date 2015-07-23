use strict;
use warnings;

use RT::Test::Assets tests => undef;

my $user = RT::Test->load_or_create_user( Name => 'testuser' );
ok $user->id, "Created user";

my $ticket = RT::Test->create_ticket(
    Queue   => 1,
    Subject => 'a test ticket',
);
ok $ticket->id, "Created ticket";

my $catalog_one = create_catalog( Name => "One" );
ok $catalog_one && $catalog_one->id, "Created catalog one";

my $catalog_two = create_catalog( Name => "Two" );
ok $catalog_two && $catalog_two->id, "Created catalog two";

ok(RT::Test->add_rights({
    Principal   => 'Privileged',
    Right       => 'ShowCatalog',
    Object      => $catalog_one,
}), "Granted ShowCatalog");

my $asset = RT::Asset->new( RT::CurrentUser->new($user) );

diag "CreateAsset";
{
    my %create = (
        Name    => 'Thinkpad T420s',
        Contact => 'trs@example.com',
        Catalog => $catalog_one->id,
    );
    my ($id, $msg) = $asset->Create(%create);
    ok !$id, "Create denied: $msg";

    ok(RT::Test->add_rights({
        Principal   => 'Privileged',
        Right       => 'CreateAsset',
        Object      => $catalog_one,
    }), "Granted CreateAsset");

    ($id, $msg) = $asset->Create(%create);
    ok $id, "Created: $msg";
    is $asset->id, $id, "id matches";
    is $asset->CatalogObj->Name, $catalog_one->Name, "Catalog matches";
};

diag "ShowAsset";
{
    is $asset->Name, undef, "Can't see Name without ShowAsset";
    ok !$asset->Contacts->id, "Can't see Contacts role group";

    ok(RT::Test->add_rights({
        Principal   => 'Privileged',
        Right       => 'ShowAsset',
        Object      => $catalog_one,
    }), "Granted ShowAsset");

    is $asset->Name, "Thinkpad T420s", "Got Name";
    is $asset->Contacts->UserMembersObj->First->EmailAddress, 'trs@example.com', "Got Contact";
}

diag "ModifyAsset";
{
    my ($txnid, $txnmsg) = $asset->SetName("Lenovo Thinkpad T420s");
    ok !$txnid, "Update failed: $txnmsg";
    is $asset->Name, "Thinkpad T420s", "Name didn't change";

    my ($ok, $msg) = $asset->AddLink( Type => 'RefersTo', Target => 't:1' );
    ok !$ok, "No rights to AddLink: $msg";

    ($ok, $msg) = $asset->DeleteLink( Type => 'RefersTo', Target => 't:1' );
    ok !$ok, "No rights to DeleteLink: $msg";

    ok(RT::Test->add_rights({
        Principal   => 'Privileged',
        Right       => 'ModifyAsset',
        Object      => $catalog_one,
    }), "Granted ModifyAsset");
    
    ($txnid, $txnmsg) = $asset->SetName("Lenovo Thinkpad T420s");
    ok $txnid, "Updated Name: $txnmsg";
    is $asset->Name, "Lenovo Thinkpad T420s", "Name changed";
}

diag "Catalogs";
{
    my ($txnid, $txnmsg) = $asset->SetCatalog($catalog_two->id);
    ok !$txnid, "Failed to update Catalog: $txnmsg";
    is $asset->CatalogObj->Name, $catalog_one->Name, "Catalog unchanged";

    ok(RT::Test->add_rights({
        Principal   => 'Privileged',
        Right       => 'CreateAsset',
        Object      => $catalog_two,
    }), "Granted CreateAsset in second catalog");

    ($txnid, $txnmsg) = $asset->SetCatalog($catalog_two->id);
    ok $txnid, "Updated Catalog: $txnmsg";
    unlike $txnmsg, qr/Permission Denied/i, "Transaction message isn't Permission Denied";
    ok !$asset->CurrentUserCanSee, "Can no longer see the asset";

    ok(RT::Test->add_rights({
        Principal   => 'Privileged',
        Right       => 'ShowAsset',
        Object      => $catalog_two,
    }), "Granted ShowAsset");

    ok $asset->CurrentUserCanSee, "Can see the asset now";
    is $asset->CatalogObj->Name, undef, "Can't see the catalog name still";

    ok(RT::Test->add_rights({
        Principal   => 'Privileged',
        Right       => 'ShowCatalog',
        Object      => $catalog_two,
    }), "Granted ShowCatalog");

    is $asset->CatalogObj->Name, $catalog_two->Name, "Now we can see the catalog name";
}

done_testing;

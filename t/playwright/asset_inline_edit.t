use strict;
use warnings;

use RT::Test::Assets tests => undef, playwright => 1, config => q{
    Set(%CustomFieldGroupings,
        "RT::Asset" => {
            Dates => [qw(Purchased)],
        },
    );
};

my ( $url, $p ) = RT::Test->started_ok;

my $catalog = RT::Test::Assets->load_or_create_catalog( Name => "Office" );
ok $catalog->id, "Created Catalog";

my $purchased = create_cf( Name => 'Purchased', Pattern => '(?#Year)^(?:19|20)\d{2}$' );
ok $purchased->id, "Created CF Purchased";

my $height = create_cf( Name => 'Height', Pattern => '(?#Inches)^\d+"?$' );
ok $height->id, "Created CF Height";

my $material = create_cf( Name => 'Material' );
ok $material->id, "Created CF Material";

$p->login();

diag "Create basic asset (no CFs)";
{
    my $create_link = $p->find_element(q{//a[@id='assets-create']});
    $p->get_ok( $create_link->getAttribute('href') . '?Catalog=' . $catalog->id );
    $p->submit_form_ok(
        {
            form_name => 'CreateAsset',
            fields    => {
                Name        => 'Thinkpad T420s',
                Description => 'A laptop',
            },
        },
        'Submit create form'
    );
    $p->text_like( qr/Asset .* created/, "Found created message" );

    my $asset = RT::Test::Assets->last_asset;
    ok $asset->id, "Asset created";
    is $asset->Name,        "Thinkpad T420s", "Name matches";
    is $asset->Description, "A laptop",       "Description matches";
}

diag "Create with CFs";
{
    ok apply_cfs( $height, $material ), "Applied CFs";

    my $cf_height_name   = "Object-RT::Asset--CustomField-" . $height->id . "-Value";
    my $cf_material_name = "Object-RT::Asset--CustomField-" . $material->id . "-Value";

    my $create_link = $p->find_element(q{//a[@id='assets-create']});
    $p->get_ok( $create_link->getAttribute('href') . '?Catalog=' . $catalog->id );
    $p->submit_form_ok(
        {
            form_name => 'CreateAsset',
            fields    => {
                Name              => 'Standing desk',
                $cf_height_name   => 'forty-six inches',
                $cf_material_name => 'pine',
            },
        },
        'Submit create form with invalid CF'
    );
    $p->content_unlike( qr/Asset .* created/, "Lacks created message" );
    $p->text_contains( 'must match', "Found validation error" );

    # Fix the invalid CF and resubmit; other fields should be preserved
    $p->submit_form_ok(
        {
            form_name => 'CreateAsset',
            fields    => {
                $cf_height_name => '46"',
            },
        },
        'Resubmit form with valid CF'
    );
    $p->text_like( qr/Asset .* created/, "Found created message" );

    my $asset = RT::Test::Assets->last_asset;
    ok $asset->id, "Asset created";
    is $asset->FirstCustomFieldValue('Height'),   '46"',  "Found height";
    is $asset->FirstCustomFieldValue('Material'), 'pine', "Found material";
}

diag "Create with CFs in other groups";
{
    ok apply_cfs($purchased), "Applied CF";

    my $cf_height_name = "Object-RT::Asset--CustomField-" . $height->id . "-Value";

    my $create_link = $p->find_element(q{//a[@id='assets-create']});
    $p->get_ok( $create_link->getAttribute('href') . '?Catalog=' . $catalog->id );
    $p->submit_form_ok(
        {
            form_name => 'CreateAsset',
            fields    => {
                Name            => 'Chair',
                $cf_height_name => '23',
            },
        },
        'Submit create form'
    );
    $p->text_like( qr/Asset .* created/, "Found created message" );
    $p->content_unlike( qr/Purchased.*?must match.*?Year/, "Lacks validation error for Purchased" );
}

diag "Bulk update";
{
    my $search_link = $p->find_element(q{//a[@id='assets-simple_search']});
    $p->get_ok( $search_link->getAttribute('href') );
    $p->submit_form_ok(
        {
            form   => '#AssetSearch',
            fields => { Catalog => $catalog->Id },
            button => 'SearchAssets',
        },
        'Search assets'
    );

    # Navigate to Bulk Update
    $p->{page}->click('a:has-text("Bulk Update")');
    $p->wait_for_htmx();

    # Verify status options
    my $dom = $p->dom;
    my @options = $dom->find('select[name="UpdateStatus"] option')->map( attr => 'value' )->each;
    is_deeply(
        [ sort @options ],
        [ '', 'allocated', 'deleted', 'in-use', 'new', 'recycled', 'stolen' ],
        'Status options'
    );

    $p->submit_form_ok(
        {
            form_name => 'BulkUpdate',
            fields    => {
                UpdateStatus => 'allocated',
            },
            button => 'Update',
        },
        'Submit bulk update'
    );
    $p->text_like( qr{Asset \d+: Status changed from 'new' to 'allocated'}, 'Bulk update messages' );
    $p->text_unlike( qr{Asset \d+: Asset \d+:'}, 'Bulk update messages do not have duplicated prefix' );
}

diag "People inline edit";
{
    my $asset = create_asset( Name => "Test asset", Catalog => $catalog->Id );
    my $page  = $p->{page};
    my $id    = $asset->Id;
    my $staff = RT::Test->load_or_create_group('Staff');
    my $alice = RT::Test->load_or_create_user( Name => 'alice@localhost' );

    $p->get_ok( '/Asset/Display.html?id=' . $id );

    # Open People inline edit and submit all changes at once
    $page->click('div.asset-people a.inline-edit-toggle');
    $p->submit_form_ok(
        {
            form   => 'div.asset-people form.inline-edit',
            fields => {
                'SetRoleMember-Owner'     => 'root',
                'AddUserRoleMember-Role'  => 'Contact',
                'AddUserRoleMember'       => 'alice@localhost',
                'AddGroupRoleMember-Role' => 'HeldBy',
                'AddGroupRoleMember'      => 'Staff',
            },
        },
        'Submit people inline edit'
    );

    $p->wait_for_notifications(3);
    $p->wait_for_element('div.asset-people .inline-edit-display span.user:has-text("root")');

    my $dom = $p->dom;
    like( $dom->at('div.asset-people .inline-edit-display')->all_text, qr/root/, 'Display shows owner root' );
    $p->text_contains('Owner set to root');
    $p->text_contains('Member added: alice@localhost');
    $p->text_contains('Member added: Staff');
    $p->close_jgrowl;

    # Reopen inline edit to remove members
    $page->click('div.asset-people a.inline-edit-toggle');
    $p->wait_for_element( 'input#checkbox-RemoveRoleMember-Contact-' . $alice->PrincipalId );
    $page->click( 'input#checkbox-RemoveRoleMember-Contact-' . $alice->PrincipalId );
    $page->click( 'input#checkbox-RemoveRoleMember-HeldBy-' . $staff->PrincipalId );
    $p->submit_form_ok(
        {
            form => 'div.asset-people form.inline-edit',
        },
        'Remove contact and held by'
    );
    $p->wait_for_notifications(2);
    $p->text_contains('Member deleted');
    $p->close_jgrowl;

    # Add manager custom role and test it
    my $manager = RT::CustomRole->new( RT->SystemUser );
    ok(
        $manager->Create(
            Name       => 'Manager',
            LookupType => RT::Asset->CustomFieldLookupType,
            MaxValues  => 1,
        )
    );
    ok( $manager->AddToObject( $catalog->Id ) );

    # Reload to pick up the new custom role
    $p->get_ok( '/Asset/Display.html?id=' . $id );
    $page->click('div.asset-people a.inline-edit-toggle');

    $dom = $p->dom;
    my $manager_input = $dom->at( 'input[name="SetRoleMember-' . $manager->GroupType . '"]' );
    ok( $manager_input, 'Found manager input' );
    is( $manager_input->attr('value'), 'Nobody', 'Default manager is Nobody' );

    my $group_type = $manager->GroupType;
    $p->submit_form_ok(
        {
            form   => 'div.asset-people form.inline-edit',
            fields => {
                "SetRoleMember-$group_type" => 'root',
            },
        },
        'Set manager to root'
    );
    $p->wait_for_notifications(1);
    $p->text_contains('Manager set to root');
}

diag "Basics inline edit refresh";
{
    my $asset = create_asset( Name => "Inline edit test", Catalog => $catalog->Id );
    $p->get_ok( '/Asset/Display.html?id=' . $asset->Id );

    # Open inline edit and change the Name
    $p->{page}->click('div.asset-basics a.inline-edit-toggle');
    $p->submit_form_ok(
        {
            form   => 'div.asset-basics form.inline-edit',
            fields => {
                Name => 'Updated name',
            },
        },
        'Submit basics inline edit'
    );
    $p->wait_for_notifications(1);

    # Wait for the inline-edit-display to refresh via its htmx GET request
    # (triggered by assetBasicsChanged event) before reading the DOM
    $p->wait_for_element('div.asset-basics .inline-edit-display:has-text("Updated name")');

    # Verify the display shows the new value
    my $dom = $p->dom;
    like( $dom->at('div.asset-basics .inline-edit-display')->all_text, qr/Updated name/, 'Display shows updated name' );

    $p->close_jgrowl;

    # Reopen inline edit — the input should show the new value
    $p->{page}->click('div.asset-basics a.inline-edit-toggle');
    $p->wait_for_element('div.asset-basics form.inline-edit input[name="Name"][value="Updated name"]');
    $dom = $p->dom;
    my $name_input = $dom->at('div.asset-basics form.inline-edit input[name="Name"]');
    ok( $name_input, 'Found Name input in edit form' );
    is( $name_input->attr('value'), 'Updated name', 'Edit form shows updated name (not stale value)' );
}

$p->logout;

done_testing;

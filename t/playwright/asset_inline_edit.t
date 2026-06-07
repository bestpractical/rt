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

diag "People update";
{
    my $asset = create_asset( Name => "Test asset", Catalog => $catalog->Id );
    my $page = $p->{page};

    $p->get_ok( '/Asset/Display.html?id=' . $asset->Id );
    my $people_link = $p->find_element(q{//a[@id='page-people']});
    $p->get_ok( $people_link->getAttribute('href') );

    my $dom = $p->dom;
    my $owner_input = $dom->at('input[name="SetRoleMember-Owner"]');
    ok( $owner_input, 'Found owner input' );
    is( $owner_input->attr('value'), 'Nobody', 'Default owner is Nobody' );

    # submit_form_ok sets hidden input values directly, bypassing TomSelect UI
    $p->submit_form_ok(
        {
            form   => '#ModifyAssetPeople',
            fields => {
                'SetRoleMember-Owner' => 'root',
            },
            button => 'Update',
        },
        'Set owner to root'
    );
    $p->text_contains('Owner set to root');

    $dom = $p->dom;
    $owner_input = $dom->at('input[name="SetRoleMember-Owner"]');
    ok( $owner_input, 'Found owner input' );
    is( $owner_input->attr('value'), 'root', 'Input value of owner is root' );

    my $staff = RT::Test->load_or_create_group('Staff');

    $p->submit_form_ok(
        {
            form   => '#ModifyAssetPeople',
            fields => {
                'AddUserRoleMember-Role'  => 'Contact',
                'AddUserRoleMember'       => 'alice@localhost',
                'AddGroupRoleMember-Role' => 'HeldBy',
                'AddGroupRoleMember'      => 'Staff',
            },
            button => 'Update',
        },
        'Add contact and held by'
    );
    $p->text_contains('Member added: alice@localhost');
    $p->text_contains('Member added: Staff');

    # Remove the members we just added
    my $alice = RT::Test->load_or_create_user( Name => 'alice@localhost' );
    $page->click( 'input#checkbox-RemoveRoleMember-Contact-' . $alice->PrincipalId );
    $page->click( 'input#checkbox-RemoveRoleMember-HeldBy-' . $staff->PrincipalId );
    $p->submit_form_ok(
        {
            form   => '#ModifyAssetPeople',
            button => 'Update',
        },
        'Remove contact and held by'
    );
    $p->text_contains('Member deleted');

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

    $p->get_ok( '/Asset/ModifyPeople.html?id=' . $asset->Id );
    $dom = $p->dom;
    my $manager_input = $dom->at( 'input[name="SetRoleMember-' . $manager->GroupType . '"]' );
    ok( $manager_input, 'Found manager input' );
    is( $manager_input->attr('value'), 'Nobody', 'Default manager is Nobody' );

    $p->submit_form_ok(
        {
            form   => '#ModifyAssetPeople',
            fields => {
                'SetRoleMember-' . $manager->GroupType => 'root',
            },
            button => 'Update',
        },
        'Set manager to root'
    );
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


diag "merged from asset_links_edit.t";
{
    my $catalog = create_catalog( Name => 'Kit' );
    my $main    = create_asset( Name => 'pw main asset',  Catalog => $catalog->id );
    my $other   = create_asset( Name => 'pw other asset', Catalog => $catalog->id );

    $p->get_ok( '/Asset/Display.html?id=' . $main->id, 'asset display page' );

    # Enter edit mode via the pencil: a pure .editing CSS flip (no fetch). The unified body --
    # the add-link rows included -- is already in the DOM and becomes visible.
    $p->{page}->locator('div.asset-links .inline-edit-toggle.edit')->first()->click();
    $p->wait_for_element('div.asset-links.editing');
    $p->wait_for_element('div.asset-links .edit-ticket-links .add-link-row');

    # Wait for initAddLinkRows to bind the first row's TomSelect (default object type "ticket").
    $p->{handle}->await(
        $p->{page}->waitForFunction(
            'document.querySelector("div.asset-links .add-link-row .link-value.tomselected") !== null')
    );

    # Switch the object type to "asset": applyObjectType() destroys the current TomSelect and
    # binds a fresh one for the Assets autocomplete.
    $p->wait_for_element('div.asset-links .add-link-row:first-child .link-object-type-select.tomselected');
    $p->{page}->evaluate(
        'document.querySelector("div.asset-links .add-link-row:first-child .link-object-type-select").tomselect.setValue("asset")'
    );

    $p->{handle}->await(
        $p->{page}->waitForFunction(
            'document.querySelector("div.asset-links .add-link-row .link-value.tomselected") !== null')
    );

    # Drive the TomSelect control input via click+fill+blur; createOnBlur commits the value and
    # the change/blur handler prepends the "asset:" prefix.
    my $other_id = '' . $other->id;
    my $row1_ts  = 'div.asset-links .add-link-row:first-child .link-value + .ts-wrapper .ts-control input';
    $p->{page}->locator($row1_ts)->click();
    $p->{page}->locator($row1_ts)->fill($other_id);
    $p->{page}->evaluate(
        'document.querySelector("div.asset-links .add-link-row:first-child .link-value + .ts-wrapper .ts-control input").blur()'
    );

    my $row1_val = $p->{page}
        ->evaluate('return document.querySelector("div.asset-links .add-link-row:first-child .link-value").value');
    like( $row1_val, qr/\Q$other_id\E/, "row 1 link-value contains asset id $other_id" );

    $p->{page}->locator('div.asset-links form.inline-edit input[type=submit][value=Save]')->click();
    $p->wait_for_htmx;
    $p->wait_for_notifications(1);

    # After save the unified list refreshes via assetLinksChanged.
    $p->wait_for_element(qq{div.asset-links .links-edit-target tr[data-record-id="$other_id"]});

    DBIx::SearchBuilder::Record::Cachable->FlushCache;
    my $reload = RT::Asset->new( RT->SystemUser );
    $reload->Load( $main->id );
    ok( $reload->RefersTo->Count >= 1, 'asset now refers to the other asset after row-UI add' );
    my %target_ids = map { $_->TargetObj->id => 1 } @{ $reload->RefersTo->ItemsArrayRef };
    ok( $target_ids{ $other->id }, 'the referred asset is the expected one' );
}

diag 'Asset Links: filter/search state set in display mode persists into edit mode';
{
    my $catalog = create_catalog( Name => 'Persist Kit' );
    my $host    = create_asset( Name => 'persist host asset',   Catalog => $catalog->id );
    my $dep     = create_asset( Name => 'persist target asset', Catalog => $catalog->id );
    ok( $host->AddLink( Type => 'RefersTo', Target => $dep->URI ), 'linked the two assets' );

    $p->get_ok( '/Asset/Display.html?id=' . $host->id, 'asset display page' );

    # For an editable asset the widget renders ONE unified body: a single div.asset-links
    # .links-filter-form plus a single .links-edit-target list.
    $p->wait_for_element('div.asset-links .links-filter-form input[name="Search"]');

    # Set a search term while still in display (read-only) mode.
    $p->{page}->fill( 'div.asset-links .links-filter-form input[name="Search"]', 'persist target' );
    $p->{page}->dispatchEvent( 'div.asset-links .links-filter-form input[name="Search"]', 'input' );

    # Flip into edit mode via the pencil (CSS-only, no fetch).
    $p->{page}->locator('div.asset-links a.inline-edit-toggle.edit')->first()->click();

    # Same single bar, same value, filter still applied to the one list.
    $p->{handle}->await(
        $p->{page}->waitForFunction(
            <<'JS'
(function() {
    const forms = document.querySelectorAll('div.asset-links .links-filter-form');
    if (forms.length !== 1) return false;
    const box = forms[0].querySelector('input[name="Search"]');
    if (!box || box.value !== 'persist target') return false;
    const t = document.querySelector('div.asset-links .links-edit-target');
    if (!t) return false;
    const rows = t.querySelectorAll('tbody tr');
    const visible = [];
    rows.forEach(function(r){ if (!r.classList.contains('d-none')) visible.push(r.textContent); });
    return visible.length === 1 && /persist target asset/.test(visible[0]);
})()
JS
            , {}, { timeout => 10000 }
        )
    );
    pass('search term and filtering carried from display into edit mode on an asset');

    # Edit affordances are now visible: a trash link is shown under .editing. Check the
    # delete-link in a *visible* row (the search above leaves only the matching row visible).
    $p->{handle}->await(
        $p->{page}->waitForFunction(
            <<'JS'
(function() {
    const boxes = document.querySelectorAll('div.asset-links .links-edit-target .delete-link');
    if (!boxes.length) return false;
    return Array.prototype.some.call(boxes, function(box) { return box.offsetParent !== null; });
})()
JS
            , {}, { timeout => 10000 }
        )
    );
    pass('delete trash links are visible in edit mode on an asset');
}

$p->logout;

done_testing;

use strict;
use warnings;

use RT::Test::Assets tests => undef;

RT->Config->Set("CustomFieldGroupings",
    "RT::Asset" => {
        Dates => [qw(Purchased)],
    },
);
RT->Config->PostLoadCheck;

my $catalog = create_catalog( Name => "Office" );
ok $catalog->id, "Created Catalog";

my $purchased = create_cf( Name => 'Purchased', Pattern => '(?#Year)^(?:19|20)\d{2}$' );
ok $purchased->id, "Created CF";

my $height = create_cf( Name => 'Height', Pattern => '(?#Inches)^\d+"?$' );
ok $height->id, "Created CF";

my $material = create_cf( Name => 'Material' );
ok $material->id, "Created CF";

my %CF = (
    Height      => ".CF-" . $height->id    . "-Edit form-control",
    Material    => ".CF-" . $material->id  . "-Edit form-control",
    Purchased   => ".CF-" . $purchased->id . "-Edit form-control",
);

my ($base, $m) = RT::Test::Assets->started_ok;
ok $m->login, "Logged in agent";

diag "Create basic asset (no CFs)";
{
    $m->follow_link_ok({ id => "assets-create" }, "Asset create link");
    $m->submit_form_ok({
        with_fields => {
            id          => 'new',
            Catalog     => $catalog->id,
            Name        => 'Thinkpad T420s',
            Description => 'A laptop',
        },
    }, "submited create form");
    $m->content_like(qr/Asset .* created/, "Found created message");
    my ($id) = $m->uri =~ /id=(\d+)/;

    my $asset = RT::Asset->new( RT->SystemUser );
    $asset->Load($id);
    is $asset->id, $id, "id matches";
    is $asset->Name, "Thinkpad T420s", "Name matches";
    is $asset->Description, "A laptop", "Description matches";
}

diag "Create with CFs";
{
    ok apply_cfs($height, $material), "Applied CFs";

    $m->follow_link_ok({ id => "assets-create" }, "Asset create link");
    $m->submit_form_ok({ with_fields => { Catalog => $catalog->id } }, "Picked a catalog");

    ok $m->form_with_fields(qw(id Name Description)), "Found form";
    $m->submit_form_ok({
        fields => {
            id              => 'new',
            Name            => 'Standing desk',
            $CF{Height}     => 'forty-six inches',
            $CF{Material}   => 'pine',
        },
    }, "submited create form");
    $m->content_unlike(qr/Asset .* created/, "Lacks created message");
    $m->content_like(qr/must match .*?Inches/, "Found validation error");

    # Intentionally fix only the invalid CF to test the other fields are
    # preserved across errors
    ok $m->form_with_fields(qw(id Name Description)), "Found form again";
    $m->set_fields( $CF{Height} => '46"' );
    $m->submit_form_ok({}, "resubmitted form");

    $m->content_like(qr/Asset .* created/, "Found created message");
    my ($id) = $m->uri =~ /id=(\d+)/;

    my $asset = RT::Asset->new( RT->SystemUser );
    $asset->Load($id);
    is $asset->id, $id, "id matches";
    is $asset->FirstCustomFieldValue('Height'), '46"', "Found height";
    is $asset->FirstCustomFieldValue('Material'), 'pine', "Found material";
}

diag "Create with CFs in other groups";
{
    ok apply_cfs($purchased), "Applied CF";

    $m->follow_link_ok({ id => "assets-create" }, "Asset create link");
    $m->submit_form_ok({ with_fields => { Catalog => $catalog->id } }, "Picked a catalog");

    ok $m->form_with_fields(qw(id Name Description)), "Found form";

    $m->submit_form_ok({
        fields => {
            id          => 'new',
            Name        => 'Chair',
            $CF{Height} => '23',
        },
    }, "submited create form");

    $m->content_like(qr/Asset .* created/, "Found created message");
    $m->content_unlike(qr/Purchased.*?must match .*?Year/, "Lacks validation error for Purchased");
}

diag "Bulk update";
{
    $m->follow_link_ok( { id => 'assets-simple_search' }, "Asset search page" );
    $m->submit_form_ok(
        {
            form_id => 'AssetSearch',
            fields  => { Catalog => $catalog->Id },
            button  => 'SearchAssets'
        },
        "Search assets"
    );

    $m->follow_link_ok( { text => 'Bulk Update' }, "Asset bulk update page" );

    my $form = $m->form_id('BulkUpdate');
    my $status_input = $form->find_input('UpdateStatus');
    is_deeply(
        [ sort $status_input->possible_values ],
        [ '', 'allocated', 'deleted', 'in-use', 'new', 'recycled', 'stolen' ],
        'Status options'
    );

    $m->submit_form_ok(
        {
            fields => {
                UpdateStatus => 'allocated',
            },
            button => 'Update',
        },
        'Submit form BulkUpdate'
    );
    $m->text_like( qr{Asset \d+: Status changed from 'new' to 'allocated'}, 'Bulk update messages' );
    $m->text_unlike( qr{Asset \d+: Asset \d+:'}, 'Bulk update messages do not have duplicated prefix' );

    # TODO: test more bulk update actions
}

diag "People update";
{
    my $asset = create_asset( Name => "Test asset", Catalog => $catalog->Id );
    $m->get_ok( '/Asset/Display.html?id=' . $asset->Id );
    $m->follow_link_ok( { text => 'People' } );

    my $form = $m->form_id('ModifyAssetPeople');
    my $owner_input = $form->find_input('SetRoleMember-Owner');
    ok( $owner_input, 'Found owner input' );
    is( $owner_input->value, 'Nobody', 'Default owner is Nobody' );
    $m->submit_form_ok(
        {
            fields => {
                'SetRoleMember-Owner' => 'root',
            },
            button => 'Update',
        },
        'Submit form ModifyAssetPeople'
    );
    $m->text_contains('Owner set to root');

    $form = $m->form_id('ModifyAssetPeople');
    $owner_input = $form->find_input('SetRoleMember-Owner');
    ok( $owner_input, 'Found owner input' );
    is( $owner_input->value, 'root', 'Input value of owner is root' );

    my $staff = RT::Test->load_or_create_group('Staff');
    $m->submit_form_ok(
        {
            fields => {
                'AddUserRoleMember-Role' => 'Contact',
                AddUserRoleMember => 'alice@localhost',
                'AddGroupRoleMember-Role' => 'HeldBy',
                AddGroupRoleMember => 'Staff',
            },
            button => 'Update',
        },
        'Submit form ModifyAssetPeople'
    );
    $m->text_contains('Member added: alice@localhost');
    $m->text_contains('Member added: Staff');

    $form = $m->form_id('ModifyAssetPeople');
    my $alice = RT::Test->load_or_create_user( Name => 'alice@localhost' );
    $m->tick('RemoveRoleMember-Contact', $alice->Id);
    $m->tick('RemoveRoleMember-HeldBy', $staff->Id);

    $m->submit_form_ok(
        {
            button => 'Update',
        },
        'Submit form ModifyAssetPeople'
    );
    $m->text_contains('Member deleted');


    # Add manager later to test if the page works with absent role groups.
    my $manager = RT::CustomRole->new( RT->SystemUser );
    ok(
        $manager->Create(
            Name       => 'Manager',
            LookupType => RT::Asset->CustomFieldLookupType,
            MaxValues  => 1,
        )
    );
    ok( $manager->AddToObject( $catalog->Id ) );

    $m->reload;
    $form = $m->form_id('ModifyAssetPeople');
    my $manager_input = $form->find_input( 'SetRoleMember-' . $manager->GroupType );
    ok( $manager_input, 'Found manager input' );
    is( $manager_input->value, 'Nobody', 'Default manager is Nobody' );
    $m->submit_form_ok(
        {
            fields => {
                'SetRoleMember-' . $manager->GroupType => 'root',
            },
            button => 'Update',
        },
        'Submit form ModifyAssetPeople'
    );
    $m->text_contains('Manager set to root');
}

# XXX TODO: test other modify pages

done_testing;

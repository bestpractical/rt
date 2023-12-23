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

# XXX TODO: test other modify pages

done_testing;

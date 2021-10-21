use strict;
use warnings;

use RT::Test::Assets tests => undef;
use RT::Lifecycle;

# populate lifecycles
my $lifecycles = RT->Config->Get('Lifecycles');
RT->Config->Set(
    Lifecycles => %{$lifecycles},
    foo        => {
        type => 'asset',
        initial  => ['new'],
        active   => ['tracked'],
        inactive => ['retired'],
        defaults => { on_create => 'new', },
    },
);
RT::Lifecycle->FillCache();

RT->Config->Set( DefaultCatalog => 'Default catalog' );

# populate test catalogs
my $catalog_1 = RT::Test::Assets->load_or_create_catalog( Name => 'Default catalog' );
ok( $catalog_1, 'created catalog 1' );
my $catalog_2 = RT::Test::Assets->load_or_create_catalog( Name => 'Another catalog', Lifecycle => 'foo' );
ok( $catalog_2, 'created catalog 2 id:' . $catalog_2->id );

my ( $baseurl, $m ) = RT::Test->started_ok;
ok $m->login;

# set up custom field on catalog 2
my $cf = RT::Test::Assets::create_cf( Name => 'test_cf', Catalog => $catalog_2->Name, Type => 'FreeformSingle' );
$cf->AddToObject( $catalog_2 );
ok( $cf, "custom field created (id:" . $cf->Id . ")" );
my $cf_form_id    = 'Object-RT::Asset--CustomField-' . $cf->Id . '-Value';
my $cf_test_value = "some string for test_cf $$";

# load initial asset create page without specifying catalog
# should have default catalog with no custom fields
note('load create asset page with defaults');
$m->get_ok('/Asset/Create.html?');

ok( !$m->form_name('CreateAsset')->find_input($cf_form_id), 'custom field not present' );
is( $m->form_name('CreateAsset')->value('Catalog'), $catalog_1->id, 'Catalog selection dropdown populated and pre-selected' );
is( $m->form_name('CreateAsset')->value('Status'), 'new', 'Status selection dropdown populated and pre-selected' );

# test asset creation on reload from selected catalog, specifying catalog with custom fields
note('reload asset create page with selected catalog');
$m->get_ok( '/Asset/Create.html?Catalog=' . $catalog_2->id, 'go to asset create page' );

is( $m->form_name('CreateAsset')->value('Catalog'), $catalog_2->id, 'Catalog selection dropdown populated and pre-selected' );
ok( $m->form_name('CreateAsset')->find_input($cf_form_id), 'custom field present' );
is( $m->form_name('CreateAsset')->value($cf_form_id), '', 'custom field present and empty' );

my $form         = $m->form_name('CreateAsset');
my $status_input = $form->find_input('Status');
is_deeply(
    [ $status_input->possible_values ],
    [ 'new', 'tracked', 'retired' ],
    'status selectbox shows custom lifecycle for queue'
);
note('submit populated form');
$m->submit_form( fields => { Name => 'asset foo', 'Catalog' => $catalog_2->id, $cf_form_id => $cf_test_value } );
$m->text_contains( 'test_cf',      'custom field populated in display' );
$m->text_contains( $cf_test_value, 'custom field populated in display' );

my $asset = RT::Test::Assets->last_asset;
ok( $asset->id, 'asset is created' );
is( $asset->CatalogObj->id, $catalog_2->id, 'asset created with correct catalog' );

done_testing();

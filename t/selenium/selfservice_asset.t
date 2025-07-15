use strict;
use warnings;

use RT::Test::Assets tests => undef, selenium => 1;

my ($url, $s) = RT::Test->started_ok;

# Create a test catalog
my $catalog = RT::Test::Assets->load_or_create_catalog( Name => 'Test Catalog' );
ok( $catalog, 'created test catalog' );

# Create an asset
my $asset = RT::Test::Assets::create_asset(
    Name    => 'Test Asset',
    Catalog => $catalog->Name,
    Status  => 'new',
);
ok( $asset && $asset->id, 'created test asset' );

# Login as root for this test to focus on the SelfService page functionality
$s->login();

$s->get_ok( $url . '/SelfService/Asset/Display.html?id=' . $asset->id );
$s->title_is( 'Asset #' . $asset->id . ': Test Asset', 'Page title is correct for asset' );
$s->text_contains( 'Test Asset', 'Asset name found on page' );
$s->text_contains( 'Asset #' . $asset->id, 'Asset ID found on page' );
$s->text_contains( 'Test Catalog', 'Catalog name found on page' );
$s->text_contains( 'Status', 'Status label found on page' );

my $page_text = $s->get_body();
like( $page_text, qr/Status[\s]*new/i, 'Asset status "new" found with Status label' );

$s->logout;

done_testing;

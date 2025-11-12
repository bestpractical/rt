use strict;
use warnings;

use RT::Test::Assets tests => undef, playwright => 1;

my ($url, $p) = RT::Test->started_ok;

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
$p->login();

$p->get_ok( $url . '/SelfService/Asset/Display.html?id=' . $asset->id );

$p->title_is( 'Asset #' . $asset->id . ': Test Asset', 'Page title is correct for asset' );
$p->text_contains( 'Test Asset', 'Asset name found on page' );
$p->text_contains( 'Asset #' . $asset->id, 'Asset ID found on page' );
$p->text_contains( 'Test Catalog', 'Catalog name found on page' );
$p->text_contains( 'Status', 'Status label found on page' );

my $page_text = $p->get_body();

# Match Status label followed by "new" value, allowing for HTML tags in between
# The pattern allows for any HTML markup between the label and value
like( $page_text, qr/Status.*?new/si, 'Asset status "new" found with Status label' );

$p->logout;

done_testing;

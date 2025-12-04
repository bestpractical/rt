use strict;
use warnings;

use RT::Test tests => undef, plugins => ['RT::Extension::ShowSearchTest'];

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in as root';

# Create test tickets
my $ticket1 = RT::Test->create_ticket(
    Queue   => 'General',
    Subject => 'Test ticket one for shortcode search',
);

my $ticket2 = RT::Test->create_ticket(
    Queue   => 'General',
    Subject => 'Test ticket two for shortcode search',
);

# Create a shortener for a search query
# Use LoadOrCreate to ensure consistent code generation with ShortenSearchQuery
my $shortener = RT::Shortener->new( RT->SystemUser );
my $format = q{'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#','<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject'};
my $u = URI->new();
$u->query_form(
    Format      => $format,
    Order       => 'ASC',
    OrderBy     => 'id',
    Query       => 'Queue="General"',
    RowsPerPage => 50,
);
my ($id, $msg) = $shortener->LoadOrCreate( Content => $u->query );
ok( $id, "Created shortener: $msg" );
my $sc = $shortener->Code;
ok( $sc, "Got short code: $sc" );

diag "Test ShowSearch with valid short code";
{
    $m->get_ok( $baseurl . '/ShowSearchTest.html?sc=' . $sc );
    $m->content_contains( 'ShowSearch Short Code Test', 'Test page title present' );
    $m->content_contains( 'Test ticket one for shortcode search', 'First ticket found in results' );
    $m->content_contains( 'Test ticket two for shortcode search', 'Second ticket found in results' );

    # Verify the htmx target uses rt-sc- prefix (in reload link)
    $m->content_like( qr/hx-target="#rt-sc-\Q$sc\E"/, 'htmx target uses rt-sc- prefix' );

    # Verify the search param uses sc= (in reload link)
    $m->content_like( qr/hx-get="[^"]*\?sc=\Q$sc\E/, 'htmx get URL uses sc parameter' );
}

diag "Test ShowSearch with invalid short code";
{
    $m->get_ok( $baseurl . '/ShowSearchTest.html?sc=invalidcode123' );
    $m->content_contains( 'Search not found', 'Invalid short code shows error message' );

    # ExpandShortenerCode logs a warning when the short code is not found
    $m->next_warning_like( qr/Could not find short URL code invalidcode123/, 'Warning logged for unknown short code' );

    # ShowSearch logs an additional warning about the failed expansion
    $m->next_warning_like( qr/Short code 'invalidcode123' did not expand|Could not find short URL code/, 'Additional warning logged' );
}

diag "Test ShowSearch with no parameters";
{
    $m->get_ok( $baseurl . '/ShowSearchTest.html' );
    $m->content_contains( 'No short code provided', 'Page shows message when no sc provided' );
}

done_testing;

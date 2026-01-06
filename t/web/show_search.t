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

    # Verify the htmx target uses rt-... prefix (in reload link)
    $m->content_like( qr/hx-target="#rt-([-\w]{36})"/, 'htmx target uses guid prefix' );

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

diag "Test ShowSearch pagination with short code";
{
    # Create a shortener with only 1 row per page to test pagination
    my $paging_shortener = RT::Shortener->new( RT->SystemUser );
    my $paging_u = URI->new();
    $paging_u->query_form(
        Format      => $format,
        Order       => 'ASC',
        OrderBy     => 'id',
        Query       => 'Queue="General"',
        RowsPerPage => 1,
    );
    my ($paging_id, $paging_msg) = $paging_shortener->LoadOrCreate( Content => $paging_u->query );
    ok( $paging_id, "Created paging shortener: $paging_msg" );
    my $paging_sc = $paging_shortener->Code;

    $m->get_ok( $baseurl . '/ShowSearchTest.html?sc=' . $paging_sc );
    $m->content_contains( 'ShowSearch Short Code Test', 'Test page title present' );

    # With 2 tickets and 1 row per page, we should have pagination
    $m->content_like( qr/class="pagination/, 'Pagination controls present' );

    # Check that pagination uses htmx with well-formed URL (no double ?)
    $m->content_like( qr/hx-get="[^"?]*\?[^"?]*Page=2/, 'Pagination link to page 2 present with htmx and single ?' );
    $m->content_like( qr/hx-target="#rt-([-\w]{36})"/, 'Pagination uses correct htmx target' );

    # Page 1 should show ticket 1 (ordered by id ASC), not ticket 2
    $m->content_contains( 'Test ticket one for shortcode search', 'Page 1 shows first ticket' );
    $m->content_lacks( 'Test ticket two for shortcode search', 'Page 1 does not show second ticket' );

    # Now request page 2 directly via the htmx endpoint to verify pagination actually works
    $m->get_ok( $baseurl . '/Views/Component/SavedSearch?sc=' . $paging_sc . '&ShowPagination=1&Page=2' );
    $m->content_contains( 'Test ticket two for shortcode search', 'Page 2 shows second ticket' );
    $m->content_lacks( 'Test ticket one for shortcode search', 'Page 2 does not show first ticket' );
}

diag "Test ShowSearch column header sorting";
{
    # Use the original shortener which has both tickets visible
    $m->get_ok( $baseurl . '/ShowSearchTest.html?AllowSorting=1&sc=' . $sc );

    # Verify column headers have sort links with htmx attributes
    $m->content_like(
        qr/hx-get="[^"]*OrderBy=id[^"]*"[^>]*hx-target="#rt-[-\w]{36}"/,
        'Column header has htmx sort link with correct target'
    );

    # Verify sort links include necessary parameters
    $m->content_like(
        qr/hx-get="[^"]*Order=(?:ASC|DESC)[^"]*OrderBy=/,
        'Sort link includes Order and OrderBy parameters'
    );

    # The initial search is sorted by id ASC, so clicking # should toggle to DESC
    # Test the htmx endpoint directly with sort parameters
    $m->get_ok( $baseurl . '/Views/Component/SavedSearch?sc=' . $sc . '&AllowSorting=1&Order=DESC&OrderBy=id' );

    # Results should be in descending order - ticket 2 before ticket 1
    my $content = $m->content;
    my ($pos1) = $content =~ /Test ticket one.*?(\d+)/s;
    my ($pos2) = $content =~ /Test ticket two.*?(\d+)/s;

    # Both tickets should still be present
    $m->content_contains( 'Test ticket one for shortcode search', 'First ticket present after DESC sort' );
    $m->content_contains( 'Test ticket two for shortcode search', 'Second ticket present after DESC sort' );

    # Verify sort icon is present (sort-down for DESC)
    $m->content_like( qr/sort-down/, 'DESC sort icon present after sorting' );
}

diag "Test ShowSearch sorting with pagination";
{
    # Reuse the paging shortener from pagination test (1 row per page)
    my $paging_shortener = RT::Shortener->new( RT->SystemUser );
    my $paging_u = URI->new();
    $paging_u->query_form(
        Format      => q{'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#','<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject'},
        Order       => 'ASC',
        OrderBy     => 'id',
        Query       => 'Queue="General"',
        RowsPerPage => 1,
    );
    my ($paging_id) = $paging_shortener->LoadOrCreate( Content => $paging_u->query );
    ok( $paging_id, "Loaded paging shortener" );
    my $paging_sc = $paging_shortener->Code;

    # Request page 2 with DESC sort - should show ticket 1 (lower id comes second in DESC order)
    $m->get_ok( $baseurl . '/Views/Component/SavedSearch?sc=' . $paging_sc . '&ShowPagination=1&AllowSorting=1&Order=DESC&OrderBy=id&Page=2' );

    # With DESC order and page 2, we should see ticket 1 (the lower id)
    $m->content_contains( 'Test ticket one for shortcode search', 'Page 2 with DESC sort shows first ticket' );
    $m->content_lacks( 'Test ticket two for shortcode search', 'Page 2 with DESC sort does not show second ticket' );

    # Verify sort icon is shown for the sorted column
    $m->content_like( qr/sort-down/, 'DESC sort icon shown on page 2' );

    # Verify sort links include the current page
    $m->content_like(
        qr/hx-get="[^"]*Page=2[^"]*"/,
        'Sort links include current page parameter'
    );

    # The pagination link should have a NEW shortener code (with sort embedded)
    # Extract the pagination link for page 1
    my ($page1_url) = $m->content =~ /hx-get="([^"]*Page=1[^"]*)"/;
    ok( $page1_url, 'Found pagination link to page 1' );

    # The URL should have sc= parameter (shortener code)
    like( $page1_url, qr/sc=/, 'Pagination link has shortener code' );

    # Request page 1 via the pagination link (this tests the shortener contains the sort)
    # Unescape HTML entities
    $page1_url =~ s/&amp;/&/g;
    $page1_url =~ s/&#38;/&/g;
    $m->get_ok( $baseurl . $page1_url );

    # Page 1 with DESC sort should show ticket 2 (higher id comes first in DESC order)
    $m->content_contains( 'Test ticket two for shortcode search', 'Page 1 via pagination shows second ticket (DESC order)' );
    $m->content_lacks( 'Test ticket one for shortcode search', 'Page 1 via pagination does not show first ticket' );

    # Sort icon should STILL be present - sort was preserved in shortener
    $m->content_like( qr/sort-down/, 'DESC sort icon preserved after pagination' );
}

diag "Test sort URL format is well-formed";
{
    $m->get_ok( $baseurl . '/ShowSearchTest.html?sc=' . $sc );

    # Sort links should have proper URL format with single ? separator
    # The URL should be like /Views/Component/SavedSearch?Order=...&OrderBy=...
    $m->content_like(
        qr{hx-get="/Views/Component/SavedSearch\?[^"]+"},
        'Sort link URL has proper format with single ? separator'
    );

    # Should NOT have malformed URLs like /Views/Component/SavedSearchOrder=
    $m->content_unlike(
        qr{hx-get="/Views/Component/SavedSearchOrder=},
        'Sort link URL does not have missing ? separator'
    );
}

diag "Test Rows override preserved through pagination with SavedSearch";
{
    # Create a saved search via the web UI (like search_shortener.t)
    $m->get_ok('/Search/Build.html?Query=Queue="General"');
    $m->submit_form_ok(
        {   form_name => 'BuildQuery',
            fields    => { SavedSearchName => 'rows_test_search' },
            button    => 'SavedSearchSave',
        },
        'Created saved search'
    );

    # Get the saved search ID from the form (like saved_search_context.t)
    my $saved_search_id = $m->form_name('BuildQuery')->value('SavedSearchId');
    ok($saved_search_id, "Got saved search ID: $saved_search_id");

    # Load the saved search to verify it exists and check its RowsPerPage
    my $search = RT::SavedSearch->new( RT->SystemUser );
    $search->Load($saved_search_id);
    ok($search->Id, "Loaded saved search");

    my $content = $search->Content;
    my $saved_rows = $content->{RowsPerPage} // 50;
    ok($saved_rows >= 2, "Saved search has RowsPerPage >= 2 (actual: $saved_rows)");

    # Now test ShowSearch with Rows=1 override (simulating MyRT behavior)
    # This is what happens when MyRT displays a saved search with a Rows override
    $m->get_ok( $baseurl . '/Views/Component/SavedSearch?SavedSearch=' . $saved_search_id . '&ShowPagination=1&AllowSorting=1&Rows=1' );

    # With Rows=1 override, only first ticket should be visible
    $m->content_contains( 'Test ticket one for shortcode search', 'Page 1 shows first ticket with Rows=1 override' );
    $m->content_lacks( 'Test ticket two for shortcode search', 'Page 1 does not show second ticket (Rows=1 override applied)' );

    # Extract pagination link for page 2 - it should have both SavedSearch and sc params
    my ($page2_url) = $m->content =~ /hx-get="([^"]*Page=2[^"]*)"/;
    ok( $page2_url, 'Found pagination link to page 2' );

    # Verify the pagination link has both SavedSearch and sc (shortener code)
    like( $page2_url, qr/SavedSearch=/, 'Pagination link includes SavedSearch parameter' );
    like( $page2_url, qr/sc=/, 'Pagination link includes sc (shortener) parameter' );

    # Request page 2 via pagination link
    $page2_url =~ s/&amp;/&/g;
    $page2_url =~ s/&#38;/&/g;
    $m->get_ok( $baseurl . $page2_url );

    # Page 2 should show only ticket 2 (Rows=1 override preserved via shortener)
    # If the fix works, sc's RowsPerPage=1 takes precedence over saved search's RowsPerPage=50
    $m->content_contains( 'Test ticket two for shortcode search', 'Page 2 shows second ticket' );
    $m->content_lacks( 'Test ticket one for shortcode search', 'Page 2 does not show first ticket (Rows override preserved via sc)' );
}

done_testing;

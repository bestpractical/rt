use strict;
use warnings;

use RT::Test tests => undef;
use URI::Escape qw(uri_escape);

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in';

diag "Test default search result format rendering";

# Create test tickets with known, predictable values
# Use root user (created automatically) - no need for additional users or rights
my $ticket1 = RT::Test->create_ticket(
    Queue     => 'General',
    Subject   => 'Test ticket for default format',
    Requestor => 'user1@example.com',
    Priority  => 50,
    Status    => 'open',
);
ok($ticket1->id, 'Created test ticket 1');
my $ticket1_id = $ticket1->id;

# Add a comment to set Told date
my ($ok, $msg) = $ticket1->Comment(Content => 'Test comment');
ok($ok, 'Added comment to ticket');

diag "Navigate to default search results page";

# Navigate to search results without specifying Format parameter
# This should use the DefaultSearchResultFormat from RT_Config
$m->get_ok("/Search/Results.html?Query=" . uri_escape("id = " . $ticket1_id));

diag "Validate table exists and has expected structure";

# Get the DOM to inspect the actual table structure
my $dom = $m->dom;

# Find the search results table using RT-specific class
# RT adds 'collection-as-table' and 'ticket-list' classes to search results
my $table = $dom->at('table.collection-as-table');
ok($table, 'Found search results table with class="collection-as-table"');

# Verify it's specifically a ticket list
ok($table->attr('class') =~ /ticket-list/, 'Table has ticket-list class for ticket searches');

# Verify thead and tbody exist
ok($table->at('thead'), 'Table has thead element');
ok($table->at('tbody'), 'Table has tbody element');

# Verify there are header rows
my @header_rows = $table->find('thead tr')->each;
ok(@header_rows > 0, 'Table has header row(s)');

# Verify there are data rows
my @data_rows = $table->find('tbody tr')->each;
ok(@data_rows > 0, 'Table has data row(s)');

diag "Validate header structure and content";

# Default format creates sortable headers (links) for most columns
# Row 1 headers: #, Subject, Status, Queue, Owner, Priority
# Sortable columns have <a> tags with OrderBy parameter

# Find all header cells in first header row
my @header_row1 = $table->find('thead tr:first-child th')->each;
ok(@header_row1 >= 6, 'First header row has at least 6 columns');

# Validate specific sortable headers by checking for links with OrderBy
my $id_header = $table->at('thead th a[href*="OrderBy=id"]');
ok($id_header, 'ID column header is sortable (has OrderBy link)');
like($id_header->all_text, qr/#/i, 'ID header displays as #');

my $subject_header = $table->at('thead th a[href*="OrderBy=Subject"]');
ok($subject_header, 'Subject column header is sortable');
like($subject_header->all_text, qr/Subject/i, 'Subject header has correct text');

my $status_header = $table->at('thead th a[href*="OrderBy=Status"]');
ok($status_header, 'Status column header is sortable');
like($status_header->all_text, qr/Status/i, 'Status header has correct text');

my $queue_header = $table->at('thead th a[href*="OrderBy=Queue"]');
ok($queue_header, 'Queue column header is sortable');
like($queue_header->all_text, qr/Queue/i, 'Queue header has correct text');

my $owner_header = $table->at('thead th a[href*="OrderBy=Owner"]');
ok($owner_header, 'Owner column header is sortable');
like($owner_header->all_text, qr/Owner/i, 'Owner header has correct text');

my $priority_header = $table->at('thead th a[href*="OrderBy=Priority"]');
ok($priority_header, 'Priority column header is sortable');
like($priority_header->all_text, qr/Priority/i, 'Priority header has correct text');

# Row 2 headers (after NEWLINE) - Requestor, Created, Told, Last Updated, Time Left
# Default Format has __NEWLINE__ so we expect exactly 2 header rows
my @all_header_rows = $table->find('thead tr')->each;
is(scalar @all_header_rows, 2, 'Format with NEWLINE produces exactly 2 header rows');

# Validate Row 2 structure
my @header_row2 = $all_header_rows[1]->find('th')->each;
ok(@header_row2 >= 5, 'Second header row has at least 5 columns');

# Validate Row 2 header content - both sortability and text
my $requestor_header = $all_header_rows[1]->at('th a[href*="Requestor"]');
ok($requestor_header, 'Row 2 has Requestor header');
like($requestor_header->all_text, qr/Requestor/i, 'Requestor header has correct text');

my $created_header = $all_header_rows[1]->at('th a[href*="Created"]');
ok($created_header, 'Row 2 has Created header');
like($created_header->all_text, qr/Created/i, 'Created header has correct text');

my $told_header = $all_header_rows[1]->at('th a[href*="Told"]');
ok($told_header, 'Row 2 has Told header');
like($told_header->all_text, qr/Told/i, 'Told header has correct text');

my $updated_header = $all_header_rows[1]->at('th a[href*="LastUpdated"]');
ok($updated_header, 'Row 2 has Last Updated header');
like($updated_header->all_text, qr/Last Updated|Updated/i, 'Last Updated header has correct text');

my $timeleft_header = $all_header_rows[1]->at('th a[href*="TimeLeft"]');
ok($timeleft_header, 'Row 2 has Time Left header');
like($timeleft_header->all_text, qr/Time Left|TimeLeft/i, 'Time Left header has correct text');

diag "Validate data cell content and structure";

# Default format for Row 1:
# '<B><A HREF="...">__id__</a></B>/TITLE:#'
# '<B><A HREF="...">__Subject__</a></B>/TITLE:Subject'
# Status, QueueName, Owner, Priority

# Get first data row
my $first_row = $table->at('tbody tr:first-child');
ok($first_row, 'Found first data row');

# Get all cells in first row
my @cells = $first_row->find('td')->each;
ok(@cells >= 6, 'First row has at least 6 cells');

# Validate ID cell (first cell) - should have bold link per format
my $id_cell = $cells[0];
my $id_bold = $id_cell->at('b');
ok($id_bold, 'ID cell contains <b> tag per format');

my $id_link = $id_bold->at('a') if $id_bold;
ok($id_link, 'ID cell has link inside bold tag');
is($id_link->text, $ticket1_id, 'ID link text matches ticket id') if $id_link;
like($id_link->attr('href'), qr/Ticket\/Display\.html\?id=$ticket1_id/,
     'ID link href points to ticket display') if $id_link;

# Validate Subject cell (second cell) - should have bold link per format
my $subject_cell = $cells[1];
my $subject_bold = $subject_cell->at('b');
ok($subject_bold, 'Subject cell contains <b> tag per format');

my $subject_link = $subject_bold->at('a') if $subject_bold;
ok($subject_link, 'Subject cell has link inside bold tag');
like($subject_link->text, qr/Test ticket for default format/,
     'Subject link text matches ticket subject') if $subject_link;
like($subject_link->attr('href'), qr/Ticket\/Display\.html\?id=$ticket1_id/,
     'Subject link href points to ticket display') if $subject_link;

# Validate Status cell (third cell) - plain text
my $status_cell = $cells[2];
like($status_cell->all_text, qr/open/i, 'Status cell shows "open"');

# Validate Queue cell (fourth cell) - plain text
my $queue_cell = $cells[3];
like($queue_cell->all_text, qr/General/i, 'Queue cell shows "General"');

# Validate Owner cell (fifth cell) - shows "Nobody" for unassigned
my $owner_cell = $cells[4];
like($owner_cell->all_text, qr/Nobody/i, 'Owner cell shows "Nobody" (default unassigned owner)');

# Validate Priority cell (sixth cell) - shows text representation
my $priority_cell = $cells[5];
like($priority_cell->all_text, qr/Medium/i, 'Priority cell shows "Medium" for priority 50');

# Row 2 data (after NEWLINE) - wrapped in <small> tags per format:
# '<small>__Requestors__</small>', '<small>__CreatedRelative__</small>', etc.

# Check for small tags in the row (could be in same row or subsequent row depending on NEWLINE rendering)
my @small_tags = $first_row->find('small')->each;
ok(@small_tags > 0, 'Row contains <small> tags for Row 2 fields per format');

# Validate requestor appears in a small tag
my $has_requestor = grep { $_->all_text =~ /user1\@example\.com/i } @small_tags;
ok($has_requestor, 'Requestor email appears in <small> tag');

# Validate relative date format appears
my $has_relative_date = grep { $_->all_text =~ /\d+\s+(second|minute|hour|day|week|month|year)s?/i } @small_tags;
ok($has_relative_date, 'Relative date appears in <small> tag');

diag "Validate links work correctly";

# Check that links point to correct URLs using find_link
my $found_id_link = $m->find_link(text => $ticket1_id);
ok($found_id_link, 'Found id link via find_link');
like($found_id_link->url, qr/Ticket\/Display\.html\?id=$ticket1_id/, 'id link points to ticket display page');

my $found_subject_link = $m->find_link(text => 'Test ticket for default format');
ok($found_subject_link, 'Found Subject link via find_link');
like($found_subject_link->url, qr/Ticket\/Display\.html\?id=$ticket1_id/, 'Subject link points to ticket display page');

diag "Test with multiple tickets";

# Create a second ticket with different values
my $ticket2 = RT::Test->create_ticket(
    Queue     => 'General',
    Subject   => 'Second test ticket',
    Requestor => 'user2@example.com',
    Priority  => 25,
    Status    => 'new',
);
ok($ticket2->id, 'Created test ticket 2');

# Search for both tickets
$m->get_ok("/Search/Results.html?Query=" . uri_escape("Queue = 'General'"));

# Get the table with both tickets
$dom = $m->dom;
$table = $dom->at('table.collection-as-table');
ok($table, 'Found search results table for multiple tickets');

# Verify table structure is maintained with multiple tickets
my @all_rows = $table->find('tbody tr')->each;
ok(@all_rows >= 2, 'Table has at least 2 data rows for 2 tickets');

# Verify both tickets appear by checking subject links
my @subject_links = $table->find('tbody td b a')->each;
my @subjects = map { $_->text } @subject_links;

ok((grep { /Test ticket for default format/ } @subjects), 'First ticket subject found in results');
ok((grep { /Second test ticket/ } @subjects), 'Second ticket subject found in results');

# Verify both tickets have correct priority display in their cells
# First ticket (priority 50 = Medium) should be first
my $row1 = $all_rows[0];
my @row1_cells = $row1->find('td')->each;
if (@row1_cells >= 6) {
    like($row1_cells[5]->all_text, qr/Medium/i, 'First ticket shows Medium priority');
}

# Second ticket (priority 25 = Low) should be second
my $row2 = $all_rows[1];
my @row2_cells = $row2->find('td')->each;
if (@row2_cells >= 6) {
    like($row2_cells[5]->all_text, qr/Low/i, 'Second ticket shows Low priority');
}

diag "Test Format modifiers";

# Test /TITLE: modifier - Sets column header text
diag "Test /TITLE: modifier";
$m->get_ok("/Search/Results.html?Query=" . uri_escape("id = $ticket1_id") .
           "&Format=" . uri_escape("'__id__/TITLE:Ticket ID', '__Subject__/TITLE:Ticket Subject'"));

$dom = $m->dom;
$table = $dom->at('table.collection-as-table');
ok($table, 'Found search results table for /TITLE: test');

# Validate /TITLE: sets header text
my $header_row = $table->at('thead tr');
ok($header_row, 'Found header row');

my @headers = $header_row->find('th')->each;
ok(@headers >= 2, 'Table has at least 2 headers');

# Check first header text
my $id_header_title = $headers[0];
my $id_header_text = $id_header_title->find('span.title')->first;
ok($id_header_text, 'First header has span.title element');
like($id_header_text->all_text, qr/Ticket ID/, 'First header text is "Ticket ID" from /TITLE: modifier');

# Check second header text
my $subject_header_title = $headers[1];
my $subject_header_text = $subject_header_title->find('span.title')->first;
ok($subject_header_text, 'Second header has span.title element');
like($subject_header_text->all_text, qr/Ticket Subject/, 'Second header text is "Ticket Subject" from /TITLE: modifier');

# Test /CLASS: modifier - Adds class to inner div in data cells only
diag "Test /CLASS: modifier";
$m->get_ok("/Search/Results.html?Query=" . uri_escape("id = $ticket1_id") .
           "&Format=" . uri_escape("'__id__/CLASS:ticket-id-cell', '__Subject__/CLASS:ticket-subject-cell'"));

$dom = $m->dom;
$table = $dom->at('table.collection-as-table');
ok($table, 'Found search results table for /CLASS: test');

# Validate /CLASS: is NOT applied to headers
$header_row = $table->at('thead tr');
@headers = $header_row->find('th')->each;
ok(@headers >= 2, 'Table has at least 2 headers');

my $id_header_for_class = $headers[0];
ok(!$id_header_for_class->attr('class') || $id_header_for_class->attr('class') !~ /ticket-id-cell/,
   'ID header does not have ticket-id-cell class (/CLASS: not applied to headers)');

# Validate /CLASS: is applied to inner div in data cells
$first_row = $table->at('tbody tr:first-child');
@cells = $first_row->find('td')->each;
ok(@cells >= 2, 'Row has at least 2 cells for /CLASS: test');

# Check first cell - class should be on inner div, not td
my $id_cell_for_class = $cells[0];
my $id_inner_div = $id_cell_for_class->at('div');
ok($id_inner_div, 'ID cell contains inner div');
like($id_inner_div->attr('class'), qr/ticket-id-cell/,
     'ID cell inner div has ticket-id-cell class from /CLASS: modifier');

# Check second cell
my $subject_cell_for_class = $cells[1];
my $subject_inner_div = $subject_cell_for_class->at('div');
ok($subject_inner_div, 'Subject cell contains inner div');
like($subject_inner_div->attr('class'), qr/ticket-subject-cell/,
     'Subject cell inner div has ticket-subject-cell class from /CLASS: modifier');

# Test /CLASS: XSS prevention - malicious class values should be escaped
diag "Test /CLASS: XSS prevention";
$m->get_ok("/Search/Results.html?Query=" . uri_escape("id = $ticket1_id") .
           "&Format=" . uri_escape("'__id__/CLASS:test\" onclick=\"alert(1)'"));

$dom = $m->dom;
$table = $dom->at('table.collection-as-table');
ok($table, 'Found search results table for /CLASS: XSS test');

$first_row = $table->at('tbody tr:first-child');
my $xss_cell = $first_row->at('td:first-child');
ok($xss_cell, 'Found first cell for XSS test');

my $xss_inner_div = $xss_cell->at('div');
ok($xss_inner_div, 'XSS test cell has inner div');

# The class attribute should exist on the div but onclick should NOT be a separate attribute
ok($xss_inner_div->attr('class'), 'Inner div has class attribute');
ok(!$xss_inner_div->attr('onclick'), 'Inner div does not have onclick attribute (XSS prevented)');
ok(!$xss_cell->attr('onclick'), 'TD cell does not have onclick attribute (XSS prevented)');

# Verify the page content doesn't contain unescaped onclick
my $page_content = $m->content;
unlike($page_content, qr/onclick="alert\(1\)"/, 'No unescaped onclick in HTML (XSS prevented)');

# Test /SPAN: modifier - Apply colspan to <td>, not <div>
diag "Test /SPAN: modifier";
$m->get_ok("/Search/Results.html?Query=" . uri_escape("id = $ticket1_id") .
           "&Format=" . uri_escape("'__id__', '__Subject__/SPAN:2', '__Status__'"));

$dom = $m->dom;
$table = $dom->at('table.collection-as-table');
ok($table, 'Found search results table for /SPAN: test');

# Validate header has colspan on <th>
my $header_row_span = $table->at('thead tr');
my @header_cells_span = $header_row_span->find('th')->each;
ok(@header_cells_span >= 3, 'Header has at least 3 columns');

my $subject_header_span = $header_cells_span[1];
is($subject_header_span->attr('colspan'), '2', 'Subject header has colspan="2" on <th>');

# Validate data row has colspan on <td>, NOT on <div>
$first_row = $table->at('tbody tr:first-child');
my @data_cells_span = $first_row->find('td')->each;
ok(@data_cells_span >= 2, 'Data row has at least 2 cells (id and subject with colspan)');

# Check second cell (Subject with /SPAN:2)
my $subject_cell_span = $data_cells_span[1];
is($subject_cell_span->attr('colspan'), '2',
   'Subject cell <td> has colspan="2" from /SPAN:2 modifier');

# Verify colspan is NOT on the inner div
my $subject_inner_div_span = $subject_cell_span->at('div');
ok($subject_inner_div_span, 'Subject cell has inner div');
ok(!$subject_inner_div_span->attr('colspan'),
   'Subject cell inner div does NOT have colspan attribute (bug fixed)');

# Verify first cell (id) has no colspan
my $id_cell_span = $data_cells_span[0];
ok(!$id_cell_span->attr('colspan'), 'ID cell has no colspan attribute');

# Test /ATTRIBUTE: modifier - Controls which field is used for sorting
diag "Test /ATTRIBUTE: modifier";

# Create additional tickets for sorting tests
my $ticket_attr1 = RT::Test->create_ticket(
    Queue   => 'General',
    Subject => 'AAA First Subject',
    Status  => 'open',
);
ok($ticket_attr1->id, 'Created test ticket for /ATTRIBUTE: tests (AAA)');

my $ticket_attr2 = RT::Test->create_ticket(
    Queue   => 'General',
    Subject => 'ZZZ Last Subject',
    Status  => 'resolved',
);
ok($ticket_attr2->id, 'Created test ticket for /ATTRIBUTE: tests (ZZZ)');

# Test 1: Without /ATTRIBUTE:, last field in format is used for sorting
diag "Test default behavior without /ATTRIBUTE: (last_attribute)";
my $format_without = uri_escape("'__Subject__ [__Status__]'");
$m->get_ok("/Search/Results.html?Query=" . uri_escape("Queue = 'General'") .
           "&Format=$format_without");

$dom = $m->dom;
$table = $dom->at('table.collection-as-table');
ok($table, 'Found search results table for /ATTRIBUTE: test');

# Check header sort link - should use Status (last field)
my $header_without_attr = $table->at('thead tr th:first-child a');
ok($header_without_attr, 'Header has sort link without /ATTRIBUTE:');
like($header_without_attr->attr('href'), qr/OrderBy=Status/,
     'Without /ATTRIBUTE:, sort link uses last field (Status) in format');

# Verify display shows both Subject and Status
$first_row = $table->at('tbody tr:first-child');
my $first_cell_without = $first_row->at('td:first-child div');
my $first_text_without = $first_cell_without->all_text;
like($first_text_without, qr/\[(?:open|resolved)\]/, 'Display shows Status in brackets');

# Test 2: With /ATTRIBUTE:Subject, explicitly override to use Subject for sorting
diag "Test /ATTRIBUTE: explicitly overrides last_attribute";
my $format_with = uri_escape("'__Subject__ [__Status__]/ATTRIBUTE:Subject'");
$m->get_ok("/Search/Results.html?Query=" . uri_escape("Queue = 'General'") .
           "&Format=$format_with");

$dom = $m->dom;
$table = $dom->at('table.collection-as-table');
ok($table, 'Found search results table for /ATTRIBUTE:Subject test');

# Check header sort link - should use Subject (explicit via /ATTRIBUTE:)
my $header_with_attr = $table->at('thead tr th:first-child a');
ok($header_with_attr, 'Header has sort link with /ATTRIBUTE:Subject');
like($header_with_attr->attr('href'), qr/OrderBy=Subject/,
     'With /ATTRIBUTE:Subject, sort link uses Subject (not Status)');

# Verify display still shows both Subject and Status
$first_row = $table->at('tbody tr:first-child');
my $first_cell_with = $first_row->at('td:first-child div');
my $first_text_with = $first_cell_with->all_text;
like($first_text_with, qr/\[(?:open|resolved)\]/, 'Display still shows Status in brackets');

# Test 3: Verify actual sorting behavior with /ATTRIBUTE:Subject
diag "Test /ATTRIBUTE: controls actual sort order";
$m->get_ok("/Search/Results.html?Query=" . uri_escape("Queue = 'General'") .
           "&Format=$format_with&OrderBy=Subject&Order=ASC");

$dom = $m->dom;
$table = $dom->at('table.collection-as-table');
my @rows_sorted = $table->find('tbody tr')->each;
ok(@rows_sorted >= 3, 'Found at least 3 ticket rows for sort order test');

# Extract subjects from rows by looking at the full text
my @subject_texts;
foreach my $row (@rows_sorted) {
    my $cell_text = $row->at('td:first-child div')->all_text;
    push @subject_texts, $cell_text;
}

# Verify subjects are in alphabetical order
# We have tickets: AAA, Second test, Test ticket for default, ZZZ
like($subject_texts[0], qr/AAA/i, 'First row has AAA subject (alphabetically first)');
like($subject_texts[1], qr/Second test ticket/, 'Second row has "Second test ticket"');
like($subject_texts[2], qr/Test ticket for default format/, 'Third row has "Test ticket for default format"');
ok(@subject_texts >= 4, 'At least 4 rows present');
if (@subject_texts >= 4) {
    like($subject_texts[3], qr/ZZZ/i, 'Fourth row has ZZZ subject (alphabetically last)');
}

# Test 4: Composite format showing Queue name with Subject attribute
diag "Test /ATTRIBUTE: with composite display";
my $format_composite = uri_escape("'__Subject__ (__QueueName__)/ATTRIBUTE:Subject'");
$m->get_ok("/Search/Results.html?Query=" . uri_escape("Queue = 'General'") .
           "&Format=$format_composite");

$dom = $m->dom;
$table = $dom->at('table.collection-as-table');
ok($table, 'Found search results table for composite format test');

# Verify header uses Subject for sorting
my $header_composite = $table->at('thead tr th:first-child a');
like($header_composite->attr('href'), qr/OrderBy=Subject/,
     'Composite format with /ATTRIBUTE:Subject uses Subject for sorting');

# Verify display shows both Subject and Queue name
$first_row = $table->at('tbody tr:first-child');
my $first_cell_composite = $first_row->at('td:first-child div');
like($first_cell_composite->all_text, qr/\(General\)/,
     'Display shows Queue name in parentheses with /ATTRIBUTE:Subject');

# Test /ALIGN: modifier - Uses Bootstrap text alignment classes
diag "Test /ALIGN: modifier with Bootstrap classes";

# Test left, center, right alignment
my $format_align = uri_escape("'__id__/ALIGN:left', '__Subject__/ALIGN:center', '__Status__/ALIGN:right'");
$m->get_ok("/Search/Results.html?Query=" . uri_escape("id = $ticket1_id") .
           "&Format=$format_align");

$dom = $m->dom;
$table = $dom->at('table.collection-as-table');
ok($table, 'Found search results table for /ALIGN: test');

# Test headers have Bootstrap alignment classes
my $header_row_align = $table->at('thead tr');
my @header_cells_align = $header_row_align->find('th')->each;
ok(@header_cells_align >= 3, 'Header has at least 3 columns for alignment test');

# Check first header (left align)
my $id_header_align = $header_cells_align[0];
like($id_header_align->attr('class'), qr/text-start/,
     'ID header has text-start class from /ALIGN:left');
ok(!$id_header_align->attr('style') || $id_header_align->attr('style') !~ /text-align/,
   'ID header does not have inline text-align style (uses Bootstrap class)');

# Check second header (center align)
my $subject_header_align = $header_cells_align[1];
like($subject_header_align->attr('class'), qr/text-center/,
     'Subject header has text-center class from /ALIGN:center');
ok(!$subject_header_align->attr('style') || $subject_header_align->attr('style') !~ /text-align/,
   'Subject header does not have inline text-align style (uses Bootstrap class)');

# Check third header (right align)
my $status_header_align = $header_cells_align[2];
like($status_header_align->attr('class'), qr/text-end/,
     'Status header has text-end class from /ALIGN:right');
ok(!$status_header_align->attr('style') || $status_header_align->attr('style') !~ /text-align/,
   'Status header does not have inline text-align style (uses Bootstrap class)');

# Test data cells have Bootstrap alignment classes
$first_row = $table->at('tbody tr:first-child');
my @data_cells_align = $first_row->find('td')->each;
ok(@data_cells_align >= 3, 'Data row has at least 3 cells for alignment test');

# Check first data cell inner div (left align)
my $id_cell_align = $data_cells_align[0];
my $id_div_align = $id_cell_align->at('div');
ok($id_div_align, 'ID cell has inner div');
like($id_div_align->attr('class'), qr/text-start/,
     'ID cell inner div has text-start class from /ALIGN:left');
ok(!$id_div_align->attr('align'),
   'ID cell inner div does not have deprecated align attribute (uses Bootstrap class)');

# Check second data cell inner div (center align)
my $subject_cell_align = $data_cells_align[1];
my $subject_div_align = $subject_cell_align->at('div');
ok($subject_div_align, 'Subject cell has inner div');
like($subject_div_align->attr('class'), qr/text-center/,
     'Subject cell inner div has text-center class from /ALIGN:center');
ok(!$subject_div_align->attr('align'),
   'Subject cell inner div does not have deprecated align attribute (uses Bootstrap class)');

# Check third data cell inner div (right align)
my $status_cell_align = $data_cells_align[2];
my $status_div_align = $status_cell_align->at('div');
ok($status_div_align, 'Status cell has inner div');
like($status_div_align->attr('class'), qr/text-end/,
     'Status cell inner div has text-end class from /ALIGN:right');
ok(!$status_div_align->attr('align'),
   'Status cell inner div does not have deprecated align attribute (uses Bootstrap class)');

# Test /ALIGN: with invalid values (should be ignored)
diag "Test /ALIGN: with invalid alignment value";
my $format_invalid_align = uri_escape("'__id__/ALIGN:invalid', '__Subject__'");
$m->get_ok("/Search/Results.html?Query=" . uri_escape("id = $ticket1_id") .
           "&Format=$format_invalid_align");

$dom = $m->dom;
$table = $dom->at('table.collection-as-table');
ok($table, 'Found search results table for invalid /ALIGN: test');

# Check that invalid align value doesn't add any text alignment class
my $invalid_header = $table->at('thead tr th:first-child');
ok($invalid_header->attr('class') !~ /text-(?:start|center|end)/,
   'Invalid align value does not add any Bootstrap text alignment class to header');

# Check data cell doesn't have alignment class either
$first_row = $table->at('tbody tr:first-child');
my $invalid_cell = $first_row->at('td:first-child div');
ok($invalid_cell->attr('class') !~ /text-(?:start|center|end)/,
   'Invalid align value does not add any Bootstrap text alignment class to data cell');

# Test /ALIGN: combined with other modifiers
diag "Test /ALIGN: combined with /CLASS: and /TITLE:";
my $format_combined = uri_escape("'__id__/ALIGN:center/CLASS:custom-id-class/TITLE:ID Number', '__Subject__/ALIGN:right'");
$m->get_ok("/Search/Results.html?Query=" . uri_escape("id = $ticket1_id") .
           "&Format=$format_combined");

$dom = $m->dom;
$table = $dom->at('table.collection-as-table');
ok($table, 'Found search results table for combined modifiers test');

# Check header has both alignment and title
my $combined_header = $table->at('thead tr th:first-child');
like($combined_header->attr('class'), qr/text-center/,
     'Header has text-center class when combined with /CLASS: and /TITLE:');
my $combined_title = $combined_header->at('span.title');
like($combined_title->all_text, qr/ID Number/,
     'Header title is set correctly when combined with /ALIGN:');

# Check data cell has both alignment and custom class
$first_row = $table->at('tbody tr:first-child');
my $combined_cell = $first_row->at('td:first-child div');
like($combined_cell->attr('class'), qr/text-center/,
     'Data cell has text-center class when combined with /CLASS:');
like($combined_cell->attr('class'), qr/custom-id-class/,
     'Data cell has custom class when combined with /ALIGN:');

# Test /ALIGN: XSS prevention
diag "Test /ALIGN: XSS prevention";
my $format_xss_align = uri_escape("'__id__/ALIGN:left\"><script>alert(1)</script>'");
$m->get_ok("/Search/Results.html?Query=" . uri_escape("id = $ticket1_id") .
           "&Format=$format_xss_align");

$dom = $m->dom;
$table = $dom->at('table.collection-as-table');
ok($table, 'Found search results table for /ALIGN: XSS test');

# Check that malicious content is not executed
my $xss_header = $table->at('thead tr th:first-child');
ok(!$xss_header->at('script'), 'No script tag in header (XSS prevented)');
unlike($m->content, qr/<script>alert\(1\)<\/script>/,
       'Malicious script tag not present in HTML');

# Check data cell
$first_row = $table->at('tbody tr:first-child');
my $xss_cell_align = $first_row->at('td:first-child');
ok(!$xss_cell_align->at('script'), 'No script tag in data cell (XSS prevented)');

# Test that align value is treated as text and doesn't inject attributes
my $format_attr_inject = uri_escape("'__id__/ALIGN:left onclick=alert(1)'");
$m->get_ok("/Search/Results.html?Query=" . uri_escape("id = $ticket1_id") .
           "&Format=$format_attr_inject");

$dom = $m->dom;
$table = $dom->at('table.collection-as-table');
$first_row = $table->at('tbody tr:first-child');
my $inject_cell = $first_row->at('td:first-child div');
ok(!$inject_cell->attr('onclick'),
   'Malicious onclick attribute not injected via /ALIGN: value');

# Test /ALIGN: with empty value falls back to ColumnMap default
diag "Test /ALIGN: with empty value uses ColumnMap default";
my $format_empty_align = uri_escape("'__id__/ALIGN:', '__Subject__'");
$m->get_ok("/Search/Results.html?Query=" . uri_escape("id = $ticket1_id") .
           "&Format=$format_empty_align");

$dom = $m->dom;
$table = $dom->at('table.collection-as-table');
ok($table, 'Found search results table for empty /ALIGN: test');

# Empty align falls back to ColumnMap default (id defaults to right/text-end)
my $empty_header = $table->at('thead tr th:first-child');
my $empty_classes = $empty_header->attr('class') || '';
like($empty_classes, qr/text-end/,
     'Empty align value falls back to ColumnMap default (id defaults to right alignment)');

# Additional comprehensive tests for /CLASS: with Bootstrap utilities
diag "Test /CLASS: with Bootstrap utility classes";

# Test Bootstrap text color utilities
my $format_bootstrap_text = uri_escape("'__id__/CLASS:text-primary', '__Subject__/CLASS:text-success', '__Status__/CLASS:text-danger'");
$m->get_ok("/Search/Results.html?Query=" . uri_escape("id = $ticket1_id") .
           "&Format=$format_bootstrap_text");

$dom = $m->dom;
$table = $dom->at('table.collection-as-table');
ok($table, 'Found search results table for Bootstrap text color test');

$first_row = $table->at('tbody tr:first-child');
my @cells_bootstrap = $first_row->find('td')->each;

my $primary_div = $cells_bootstrap[0]->at('div');
like($primary_div->attr('class'), qr/text-primary/,
     'Bootstrap text-primary class applied to data cell');

my $success_div = $cells_bootstrap[1]->at('div');
like($success_div->attr('class'), qr/text-success/,
     'Bootstrap text-success class applied to data cell');

my $danger_div = $cells_bootstrap[2]->at('div');
like($danger_div->attr('class'), qr/text-danger/,
     'Bootstrap text-danger class applied to data cell');

# Test Bootstrap typography utilities
diag "Test /CLASS: with Bootstrap typography utilities";
my $format_typography = uri_escape("'__id__/CLASS:fw-bold', '__Subject__/CLASS:fst-italic text-uppercase', '__Status__/CLASS:text-decoration-underline'");
$m->get_ok("/Search/Results.html?Query=" . uri_escape("id = $ticket1_id") .
           "&Format=$format_typography");

$dom = $m->dom;
$table = $dom->at('table.collection-as-table');
ok($table, 'Found search results table for typography test');

$first_row = $table->at('tbody tr:first-child');
my @cells_typo = $first_row->find('td')->each;

my $bold_div = $cells_typo[0]->at('div');
like($bold_div->attr('class'), qr/fw-bold/,
     'Bootstrap fw-bold class applied');

my $italic_div = $cells_typo[1]->at('div');
like($italic_div->attr('class'), qr/fst-italic/,
     'Bootstrap fst-italic class applied');
like($italic_div->attr('class'), qr/text-uppercase/,
     'Multiple Bootstrap classes (text-uppercase) applied');

my $underline_div = $cells_typo[2]->at('div');
like($underline_div->attr('class'), qr/text-decoration-underline/,
     'Bootstrap text-decoration-underline class applied');

# Test Bootstrap background and spacing utilities
diag "Test /CLASS: with Bootstrap background and spacing utilities";
my $format_bg_spacing = uri_escape("'__id__/CLASS:bg-light p-2', '__Subject__/CLASS:bg-primary bg-opacity-10 px-3', '__Status__/CLASS:bg-warning rounded'");
$m->get_ok("/Search/Results.html?Query=" . uri_escape("id = $ticket1_id") .
           "&Format=$format_bg_spacing");

$dom = $m->dom;
$table = $dom->at('table.collection-as-table');
ok($table, 'Found search results table for background/spacing test');

$first_row = $table->at('tbody tr:first-child');
my @cells_bg = $first_row->find('td')->each;

my $light_div = $cells_bg[0]->at('div');
like($light_div->attr('class'), qr/bg-light/,
     'Bootstrap bg-light class applied');
like($light_div->attr('class'), qr/p-2/,
     'Bootstrap padding (p-2) class applied');

my $primary_bg_div = $cells_bg[1]->at('div');
like($primary_bg_div->attr('class'), qr/bg-primary/,
     'Bootstrap bg-primary class applied');
like($primary_bg_div->attr('class'), qr/bg-opacity-10/,
     'Bootstrap bg-opacity-10 class applied');
like($primary_bg_div->attr('class'), qr/px-3/,
     'Bootstrap horizontal padding (px-3) class applied');

my $warning_div = $cells_bg[2]->at('div');
like($warning_div->attr('class'), qr/bg-warning/,
     'Bootstrap bg-warning class applied');
like($warning_div->attr('class'), qr/rounded/,
     'Bootstrap rounded class applied');

# Comprehensive tests for /STYLE: modifier
diag "Test /STYLE: modifier with custom colors";

# Test custom color values
my $format_custom_colors = uri_escape("'__id__/STYLE:color: #FF6B35', '__Subject__/STYLE:background-color: rgba(0, 123, 255, 0.1)', '__Status__/STYLE:border-left: 3px solid #28a745'");
$m->get_ok("/Search/Results.html?Query=" . uri_escape("id = $ticket1_id") .
           "&Format=$format_custom_colors");

$dom = $m->dom;
$table = $dom->at('table.collection-as-table');
ok($table, 'Found search results table for custom colors test');

$first_row = $table->at('tbody tr:first-child');
my @cells_style = $first_row->find('td')->each;

my $color_div = $cells_style[0]->at('div');
like($color_div->attr('style'), qr/color:\s*#FF6B35/i,
     'Custom color applied via /STYLE:');

my $bg_div = $cells_style[1]->at('div');
like($bg_div->attr('style'), qr/background-color:\s*rgba\(0,\s*123,\s*255,\s*0\.1\)/i,
     'Custom RGBA background color applied via /STYLE:');

my $border_div = $cells_style[2]->at('div');
like($border_div->attr('style'), qr/border-left:\s*3px\s+solid\s+#28a745/i,
     'Custom border styling applied via /STYLE:');

# Test multiple style properties
diag "Test /STYLE: with multiple properties";
my $format_multi_style = uri_escape("'__Subject__/STYLE:max-width: 200px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap'");
$m->get_ok("/Search/Results.html?Query=" . uri_escape("id = $ticket1_id") .
           "&Format=$format_multi_style");

$dom = $m->dom;
$table = $dom->at('table.collection-as-table');
ok($table, 'Found search results table for multiple style properties test');

$first_row = $table->at('tbody tr:first-child');
my $multi_style_div = $first_row->at('td:first-child div');
my $style_attr = $multi_style_div->attr('style');

like($style_attr, qr/max-width:\s*200px/i, 'max-width property applied');
like($style_attr, qr/overflow:\s*hidden/i, 'overflow property applied');
like($style_attr, qr/text-overflow:\s*ellipsis/i, 'text-overflow property applied');
like($style_attr, qr/white-space:\s*nowrap/i, 'white-space property applied');

# Test /STYLE: with precise numerical values
diag "Test /STYLE: with precise numerical values";
my $format_precise = uri_escape("'__id__/STYLE:width: 123px; padding: 3px 7px', '__Subject__/STYLE:min-height: 45px; line-height: 1.2'");
$m->get_ok("/Search/Results.html?Query=" . uri_escape("id = $ticket1_id") .
           "&Format=$format_precise");

$dom = $m->dom;
$table = $dom->at('table.collection-as-table');
ok($table, 'Found search results table for precise values test');

$first_row = $table->at('tbody tr:first-child');
my @cells_precise = $first_row->find('td')->each;

my $precise_div = $cells_precise[0]->at('div');
like($precise_div->attr('style'), qr/width:\s*123px/i,
     'Precise width value (123px) applied');
like($precise_div->attr('style'), qr/padding:\s*3px\s+7px/i,
     'Precise padding values (3px 7px) applied');

my $height_div = $cells_precise[1]->at('div');
like($height_div->attr('style'), qr/min-height:\s*45px/i,
     'Precise min-height value applied');
like($height_div->attr('style'), qr/line-height:\s*1\.2/i,
     'Precise line-height value applied');

# Test /STYLE: XSS prevention
diag "Test /STYLE: XSS prevention";
my $format_xss_style = uri_escape("'__id__/STYLE:color: red</style><script>alert(1)</script>'");
$m->get_ok("/Search/Results.html?Query=" . uri_escape("id = $ticket1_id") .
           "&Format=$format_xss_style");

$dom = $m->dom;
$table = $dom->at('table.collection-as-table');
ok($table, 'Found search results table for /STYLE: XSS test');

$first_row = $table->at('tbody tr:first-child');
my $xss_style_cell = $first_row->at('td:first-child');
ok(!$xss_style_cell->at('script'), 'No script tag in cell (XSS prevented in /STYLE:)');
unlike($m->content, qr/<script>alert\(1\)<\/script>/,
       'Malicious script tag not present in HTML from /STYLE:');

# Test /STYLE: combined with /CLASS:
diag "Test /STYLE: combined with /CLASS:";
my $format_class_style = uri_escape("'__Subject__/CLASS:fw-bold text-truncate/STYLE:max-width: 300px; color: #2c3e50'");
$m->get_ok("/Search/Results.html?Query=" . uri_escape("id = $ticket1_id") .
           "&Format=$format_class_style");

$dom = $m->dom;
$table = $dom->at('table.collection-as-table');
ok($table, 'Found search results table for /CLASS: + /STYLE: combination test');

$first_row = $table->at('tbody tr:first-child');
my $combined_div = $first_row->at('td:first-child div');

like($combined_div->attr('class'), qr/fw-bold/,
     '/CLASS: applied when combined with /STYLE:');
like($combined_div->attr('class'), qr/text-truncate/,
     'Multiple /CLASS: values applied when combined with /STYLE:');
like($combined_div->attr('style'), qr/max-width:\s*300px/i,
     '/STYLE: applied when combined with /CLASS:');
like($combined_div->attr('style'), qr/color:\s*#2c3e50/i,
     'Multiple /STYLE: properties applied when combined with /CLASS:');

# Test Query Builder Face and Size options (BuildFormatString component)
diag "Test Query Builder Face option with Bootstrap classes";

# Test Face=Bold generates Bootstrap fw-bold class
$m->post_ok(
    "/Search/Build.html",
    {
        Query              => "Queue = 'General'",
        AddCol             => 1,
        SelectDisplayColumns => 'Subject',
        Face               => 'Bold',
    }
);
my $bold_format = $m->form_name('BuildQuery')->value('Format');
like($bold_format, qr/<span class="fw-bold">__Subject__<\/span>/,
     'Face=Bold generates Bootstrap fw-bold class');
unlike($bold_format, qr/<b>__Subject__<\/b>/,
       'Face=Bold does not use deprecated <b> tag');

# Test Face=Italic generates Bootstrap fst-italic class
$m->post_ok(
    "/Search/Build.html",
    {
        Query              => "Queue = 'General'",
        AddCol             => 1,
        SelectDisplayColumns => 'Status',
        Face               => 'Italic',
    }
);
my $italic_format = $m->form_name('BuildQuery')->value('Format');
like($italic_format, qr/<span class="fst-italic">__Status__<\/span>/,
     'Face=Italic generates Bootstrap fst-italic class');
unlike($italic_format, qr/<i>__Status__<\/i>/,
       'Face=Italic does not use deprecated <i> tag');

diag "Test Query Builder Size option with Bootstrap classes";

# Test Size=Large generates Bootstrap fs-4 class
$m->post_ok(
    "/Search/Build.html",
    {
        Query              => "Queue = 'General'",
        AddCol             => 1,
        SelectDisplayColumns => 'Priority',
        Size               => 'Large',
    }
);
my $large_format = $m->form_name('BuildQuery')->value('Format');
like($large_format, qr/<span class="fs-4">__Priority__<\/span>/,
     'Size=Large generates Bootstrap fs-4 class');
unlike($large_format, qr/font-size:larger/,
       'Size=Large does not use inline font-size style');

# Test Size=Small generates <small> element
$m->post_ok(
    "/Search/Build.html",
    {
        Query              => "Queue = 'General'",
        AddCol             => 1,
        SelectDisplayColumns => 'id',
        Size               => 'Small',
    }
);
my $small_format = $m->form_name('BuildQuery')->value('Format');
like($small_format, qr/<small>__id__<\/small>/,
     'Size=Small generates semantic <small> element');

diag "Test Query Builder combined Face and Size options";

# Test combining Bold and Large
$m->post_ok(
    "/Search/Build.html",
    {
        Query              => "Queue = 'General'",
        AddCol             => 1,
        SelectDisplayColumns => 'Subject',
        Face               => 'Bold',
        Size               => 'Large',
    }
);
my $bold_large_format = $m->form_name('BuildQuery')->value('Format');
like($bold_large_format, qr/<span class="fw-bold"><span class="fs-4">__Subject__<\/span><\/span>/,
     'Combining Face=Bold and Size=Large generates nested Bootstrap spans');

# Test combining Italic and Small
$m->post_ok(
    "/Search/Build.html",
    {
        Query              => "Queue = 'General'",
        AddCol             => 1,
        SelectDisplayColumns => 'Status',
        Face               => 'Italic',
        Size               => 'Small',
    }
);
my $italic_small_format = $m->form_name('BuildQuery')->value('Format');
like($italic_small_format, qr/<span class="fst-italic"><small>__Status__<\/small><\/span>/,
     'Combining Face=Italic and Size=Small generates Bootstrap span with <small>');

done_testing;

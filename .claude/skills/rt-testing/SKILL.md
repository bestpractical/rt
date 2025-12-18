---
name: rt-testing
description: Use when writing or reviewing RT tests - provides guidance on precise validation, proper test structure, and RT-specific testing patterns
---

# RT Testing Standards and Practices

This skill provides comprehensive guidance for writing high-quality, precise tests for RT (Request Tracker).

## Core Testing Philosophy

**Tests must validate EXACTLY what you expect, not approximately what you hope to find.**

### The Golden Rule
> If you're writing a test, you should know precisely what the code produces. The test should validate that exact output, not fuzzy-match that something similar appears somewhere.

## Validation Precision

### ❌ WRONG: Loose Text Matching

```perl
# BAD: Could match anywhere on page
$m->content_contains('50', 'Priority displays');

# BAD: Too permissive regex
ok($page_html =~ /Subject/, 'Has subject');
```

**Problems:**
- Could match in wrong context (sidebar, footer, JavaScript, etc.)
- Doesn't validate structure
- Will pass even if feature is broken but text appears elsewhere
- Hides regressions

### ✅ RIGHT: Precise Structure Validation

```perl
# GOOD: Validates exact location and structure
my $priority_cell = $first_row->find('td')->[5];
is($priority_cell->text, 'Medium', 'Priority cell shows Medium for priority 50');

# GOOD: Validates specific HTML structure
ok($page_html =~ /<td[^>]*>.*?Medium.*?<\/td>/is,
   'Priority "Medium" appears in table cell');
```

## DOM vs Content Validation

### When to Use DOM Selectors

Use `$m->dom` when you need:
- **Precise element location**: "The 3rd cell in the 2nd row"
- **Structure validation**: "A link inside a table header"
- **Attribute checking**: Link href, CSS classes, data attributes
- **Navigation**: Finding specific elements in known structure

```perl
my $dom = $m->dom;
my $table = $dom->at('table.collection-as-table');
my $first_row = $table->at('tbody tr:first-child');
my @cells = $first_row->find('td')->each;

# Validate specific cell
my $subject_cell = $cells[1];
my $subject_link = $subject_cell->at('a');
ok($subject_link, 'Subject cell contains a link');
like($subject_link->attr('href'), qr/Ticket\/Display\.html/,
     'Subject link points to ticket display');
```

### When to Use Content Regex

Use `$m->content` with regex when:
- **Checking presence in context**: "Does this appear in a `<td>`?"
- **Nested content**: Text might be in various nested elements
- **Multiple matches**: Need to find all occurrences
- **HTML attributes**: Checking for specific attributes in elements

```perl
my $page_html = $m->content;

# Validate text appears in specific HTML context
ok($page_html =~ /<td[^>]*>.*?open.*?<\/td>/is,
   'Status "open" appears in table cell');

# Validate attribute in specific element type
ok($page_html =~ /<th[^>]*>.*?<a[^>]*href="[^"]*OrderBy=Subject"[^>]*>Subject<\/a>.*?<\/th>/is,
   'Subject header is sortable link');
```

### ❌ NEVER: Loose Content Matching

```perl
# NEVER DO THIS - too imprecise
$m->content_contains('Medium');  # Where? In what context?
ok($page_html =~ /Subject/);      # Could be anywhere!
```

## RT-Specific Selectors

### Finding the Right Table

RT has multiple tables on many pages. Always use specific selectors:

```perl
# ❌ WRONG: Too generic
my $table = $dom->at('table.table');

# ✅ RIGHT: RT-specific class
my $table = $dom->at('table.collection-as-table');

# ✅ EVEN BETTER: Ticket-specific
my $table = $dom->at('table.ticket-list');
```

**RT table classes:**
- `collection-as-table` - All search results/collection displays
- `ticket-list` - Ticket search results specifically
- `collection` - Non-ticket collections (assets, etc.)

### Understanding Feature Output and Structure

When testing any feature, know exactly what it produces:

```perl
# Example: Testing a feature that adds title attributes
# Specification: Field with /TITLE: modifier produces title attribute
# Expected: <div title="#">1</div>

# Test should validate BOTH the display and the attribute
my $id_cell = $first_row->find('td')->[0];
ok($id_cell->at('[title="#"]'), 'Cell has title attribute as specified');
```

## Test Data Setup

### Keep It Simple

```perl
# ✅ GOOD: Minimal setup
my $ticket = RT::Test->create_ticket(
    Queue   => 'General',
    Subject => 'Test ticket',
    Status  => 'open',
);

# ❌ WRONG: Unnecessary complexity
my $user = RT::Test->load_or_create_user(...);
$user->PrincipalObj->GrantRight(...);  # Not needed if testing display/rendering!
```

**Remember:**
- Root user has all rights - use it when permissions aren't what you're testing
- Use General queue (created automatically)
- Only create what you're actually testing
- Add complexity only when it's required for the specific test

### Test File Organization

**When to combine tests in one file:**
- Tests share similar setup requirements
- Tests don't need special configuration
- Related functionality that benefits from shared test data
- **Performance**: Each test file has some overhead with test database setup/teardown, so each new test file adds time. We want tests to run as fast as possible, so we don't want unnecessary overhead.

**When to split into separate files:**
- Tests require different RT configurations like specific RT configuration values, or special setups for users, tickets, queues, rights, groups, etc.
- Tests are testing completely different subsystems
- File is becoming too large to maintain (>1000 lines)

```perl
# ✅ GOOD: Combine related tests in the same file
# - Tests can use the same test objects, like users tickets, etc.
# - Tests are all related to the same features or parts of RT so a failure immediately indicates what part of RT has an issue.
# - The test won't get so long that it will create a performance issue for running the test.
# - All share similar test database needs or easy updates, like adding a new ticket, can be made to accommodate related tests.
```

**Key principle**: Balance test organization clarity with test execution speed. Database overhead is significant in RT tests.

## Test Structure

### Organize with `diag`

```perl
diag "Validate table structure exists";
# ... structure tests ...

diag "Validate header content";
# ... header tests ...

diag "Validate data cells contain correct values";
# ... data cell tests ...
```

### Be Deterministic - Avoid Conditionals

**Tests must be deterministic.** If you're writing a test, you know what the code should produce. Don't use conditionals to handle "maybe this exists, maybe it doesn't" - assert that the expected structure exists.

```perl
# ❌ WRONG: Conditional makes test non-deterministic
my @rows = $table->find('thead tr')->each;
if (@rows > 1) {
    # Test second row...
    ok($rows[1]->at('th'), 'Second row has headers');
}
# If second row doesn't exist, test silently passes - bug hidden!

# ✅ RIGHT: Explicit expectation
my @rows = $table->find('thead tr')->each;
is(scalar @rows, 2, 'Table has exactly 2 header rows (Row 1 + NEWLINE Row 2)');
my $second_row = $rows[1];
ok($second_row->at('th'), 'Second row has headers');
# If second row doesn't exist, test fails immediately - bug detected!
```

**Why this matters:**
- If structure changes unexpectedly, test should **fail**, not skip
- Tests document expected behavior - conditionals hide expectations
- Skipped tests give false confidence that everything works

**When testing any feature:**
1. Read the specification or code to understand what it produces
2. Know exactly what structure or output it creates
3. Assert that exact structure exists
4. No "if it exists, check it" - instead "it MUST exist, so check it"

```perl
# Example: Feature creates 2-row table header
# Specification says: Header has 2 rows (main headers + additional info)

# Test should validate BOTH rows explicitly
my @header_rows = $table->find('thead tr')->each;
is(scalar @header_rows, 2, 'Table has 2 header rows as specified');

# Test Row 1
my @row1_headers = $header_rows[0]->find('th')->each;
ok(@row1_headers >= 6, 'Row 1 has at least 6 headers');

# Test Row 2 - no conditional needed!
my @row2_headers = $header_rows[1]->find('th')->each;
ok(@row2_headers >= 5, 'Row 2 has at least 5 headers');
```

### Test the Specification

Always test against the specification or documented behavior:

```perl
# Example: Testing display specification
# Spec: ID field displays as bold link with title="#"
# Expected HTML: <td><b><a href="/Ticket/Display.html?id=1" title="#">1</a></b></td>

# Test should validate all specified elements:
# 1. Cell contains a bold element
# 2. Bold element contains a link
# 3. Link href points to correct URL
# 4. Link text is correct
# 5. Element has correct title attribute

my $id_cell = $first_row->find('td')->[0];
my $link = $id_cell->at('b a');
ok($link, 'ID cell has bold link as specified');
is($link->text, $ticket->id, 'Link text is ticket id');
like($link->attr('href'), qr/Ticket\/Display\.html\?id=\d+/,
     'Link points to ticket display');
ok($id_cell->at('[title="#"]'), 'Cell has title="#" as specified');
```

## Common Patterns

### Validating Links

```perl
# Check link exists and points to right place
my $link = $m->find_link(text => $ticket->id);
ok($link, 'Found ticket id link');
like($link->url, qr/Ticket\/Display\.html\?id=\d+/,
     'Link URL matches expected pattern');

# Or use DOM
my $subject_link = $table->at('tbody tr:first-child td:nth-child(2) a');
ok($subject_link, 'Subject cell contains link');
is($subject_link->text, 'Test ticket', 'Link text is ticket subject');
```

### Validating Table Structure

```perl
# Get the table
my $table = $dom->at('table.collection-as-table');
ok($table, 'Found collection table');

# Validate structure
ok($table->at('thead'), 'Table has thead');
ok($table->at('tbody'), 'Table has tbody');

my @rows = $table->find('tbody tr')->each;
is(scalar @rows, 2, 'Table has exactly 2 data rows');

# Validate specific row
my @cells = $rows[0]->find('td')->each;
ok(@cells >= 6, 'First row has at least 6 cells');
```

### Validating Multiple Tickets

```perl
# When testing multiple tickets, validate they maintain structure
my @all_rows = $table->find('tbody tr')->each;
is(scalar @all_rows, 2, 'Table has 2 rows for 2 tickets');

# Check each row has correct structure
for my $row (@all_rows) {
    my @cells = $row->find('td')->each;
    ok(@cells >= 6, 'Row has expected number of columns');
    ok($cells[0]->at('a'), 'ID cell has link');
    ok($cells[1]->at('a'), 'Subject cell has link');
}
```

## Test Scope - Stay Focused

Each test should focus on **one specific area** and avoid testing unrelated functionality:

**Example - Display/Rendering Tests:**
- ✅ Test: Does the feature render HTML correctly?
- ❌ Don't test: Permissions, data validation, query parsing
- Those belong in their own focused tests (API tests, security tests, etc.)

**Example - API Tests:**
- ✅ Test: Does the API method return correct data?
- ❌ Don't test: How that data renders in HTML
- That belongs in web/display tests

**Key principle**: Each test validates one thing well. If a test needs to validate permissions AND rendering AND data correctness, split it into multiple focused tests.

## Red Flags in Tests

Watch out for these anti-patterns:

```perl
# 🚩 RED FLAG: Where does this appear?
$m->content_contains('50');

# 🚩 RED FLAG: What structure validates this?
ok($page_html =~ /Subject/);

# 🚩 RED FLAG: Why create unnecessary test data?
my $alice = RT::Test->load_or_create_user(...);  # Not needed for this test!

# 🚩 RED FLAG: Too generic selector
my $table = $dom->at('table');

# 🚩 RED FLAG: Imprecise cell access
my $cells = $dom->find('td')->each;  # Which row? Which table?
$cells[5]  # Could be any table's 6th cell!

# 🚩 RED FLAG: Conditional test logic
if (@rows > 1) {
    # Test second row...  # Might silently skip if structure wrong!
}
```

## Running Tests

```bash
# Single test
prove -lv t/web/ticket_display.t

# With verbose output (same as -lv)
prove -lv t/api/ticket.t

# Run all tests in a directory
prove -l t/web/

# Keep temp files on failure for inspection
# (automatically done by RT::Test on failure)
```

## Summary Checklist

When writing a test, ask yourself:

- ✅ Do I know exactly what the code produces?
- ✅ Am I validating that specific structure?
- ✅ Would this test fail if the structure changed?
- ✅ Am I using precise selectors?
- ✅ Is my test data minimal and focused?
- ✅ Is my test deterministic (no conditionals that skip validation)?
- ✅ Would another developer understand what I'm validating?

**Remember: Tests are documentation of expected behavior. Be precise and deterministic.**

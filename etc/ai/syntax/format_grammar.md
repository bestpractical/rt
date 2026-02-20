# RT Search Result Format Grammar (AI-Optimized)

## AI Assistant Guide

**Target Audience**: This document is optimized for AI language models assisting users with RT format string construction.

**Primary Goal**: Enable accurate interpretation of natural language requests and generate correct RT Format strings.

**Usage Context**: This grammar is designed for natural language search interfaces where the user types a request and the AI immediately responds with both a TicketSQL query and a Format string. There is no opportunity for back-and-forth clarification - the AI must make sensible default choices for any ambiguous requests and can provide a brief explanatory message to the user.

### Core Principles for AI Interpretation

1. **Default to simplicity**: Unless user requests specific features, use Tier 1 (most common) patterns
2. **Make common ticket identifiers into clickable links**: Ticket ID and Subject should be clickable links by default
3. **Prefer standard dates**: Use `Created` over `CreatedRelative` unless user asks for relative dates
4. **Infer from context**: "Show recent tickets" implies `CreatedRelative` or `LastUpdatedRelative`, "Show when tickets are due" implies `DueRelative`
5. **Never ask follow-up questions**: Always provide a complete response with sensible defaults for ambiguous requests

### Intent Recognition Patterns

When a user says... they typically want:

| User Intent Keywords | Likely Fields | Format Tier | Notes |
|---------------------|---------------|-------------|-------|
| "show", "list", "display" (no specifics) | id, Subject, Status, Queue | Tier 1 | Default minimal format |
| "recent", "latest", "new" | + CreatedRelative | Tier 2 | Add age/recency |
| "old", "aging", "stale" | + CreatedRelative or LastUpdatedRelative | Tier 2 | Same as recent |
| "owner", "assigned", "who owns" | + OwnerName | Tier 2 | Ownership tracking |
| "requestor", "requester", "who requested", "customer" | + Requestor.Name or Requestor.EmailAddress | Tier 2 | Customer context |
| "priority", "urgent", "importance" | + Priority | Tier 2 | Priority visibility |
| "due", "deadline", "overdue" | + DueRelative | Tier 2 | Time sensitivity |
| "time", "hours", "worked" | + TimeWorked | Tier 2 | Time tracking |
| "age", "how old", "when created" | + CreatedRelative | Tier 2 | Age tracking |
| "updated", "last modified", "activity" | + LastUpdatedRelative | Tier 2 | Recent activity |
| "department", "team", "group" (custom) | + CustomField.{Name} | Tier 2 | Custom categorization |
| "dependencies", "blocked", "blocks" | + DependsOn or DependedOnBy | Tier 3 | Relationship tracking |
| "bookmark", "bookmarked", "starred" | + Bookmark | Tier 3 | Only when explicitly requested |
| "reply", "comment", "actions" | + Reply, Comment | Tier 3 | Interactive buttons |

### Synonym Recognition

Recognize these as equivalent requests:

**Ownership**:
- "owner", "assigned to", "who owns", "responsible", "taken by" → `OwnerName`

**Requester**:
- "requestor", "requester", "customer", "reporter", "submitted by", "created by" → `Requestor.Name`
- "contact", "contact email", "requester email" → `Requestor.EmailAddress`

**Status**:
- "status", "state", "condition" → `Status`
- "blocked by", "waiting on" → `ExtendedStatus` or `DependsOn`

**Time/Age**:
- "age", "how old", "time since created" → `CreatedRelative`
- "when created", "creation date", "created on" (if exact date requested) → `Created`
- "recently updated", "last modified", "activity" → `LastUpdatedRelative`
- "due date", "deadline", "when due" → `DueRelative` (or `Due` if exact date)

**Priority**:
- "priority", "importance", "urgent", "severity" → `Priority`

**Time Tracking**:
- "time worked", "hours", "time spent", "effort" → `TimeWorked`
- "estimate", "estimated time", "time estimated" → `TimeEstimated`
- "remaining", "time left", "time remaining" → `TimeLeft`

**Queue**:
- "queue", "which queue", "category", "bucket" → `QueueName`

### Context-Based Field Selection

**When user mentions multiple concepts, combine appropriately**:

"Show me recent tickets assigned to people"
→ id, Subject, Status, CreatedRelative, OwnerName

"List overdue tickets with priority"
→ id, Subject, DueRelative, Priority, Status

"Display tickets with customer contact info"
→ id, Subject, Status, Requestor.Name, Requestor.EmailAddress

"Show aging tickets by department"
→ id, Subject, CreatedRelative, CustomField.{Department}, Status

### Default Format Template

When a user says nothing specific about the fields to show in search results, use the provided system default.

When user provides minimal information, use this as the base:
```
'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#',
'<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject',
QueueName, Status
```

Then add fields based on what user mentions.

### Field Combination Patterns

These fields commonly appear together:

**Ownership + Activity**:
```
OwnerName, LastUpdatedRelative
```

**Customer Context**:
```
Requestor.Name, Requestor.EmailAddress
```

**Time Tracking**:
```
TimeWorked, TimeEstimated, TimeLeft
```

**Priority + Deadlines**:
```
Priority, DueRelative
```

**Aging Analysis**:
```
CreatedRelative, LastUpdatedRelative, Status
```

### Response Strategy

When interpreting natural language requests for RT search formats:

1. **Parse user request** for key intent words and recognize synonyms
2. **Identify tier** (1, 2, 3, or 4) based on specificity
3. **Start with Tier 1 base** (id, Subject, basic fields as clickable links)
4. **Add Tier 2 fields** based on user keywords and context
5. **Add Tier 3+ only** if explicitly mentioned by user
6. **Keep column count** between 4-7 for readability (max 10)
7. **Use two-row layout for 8+ columns**: Insert `NEWLINE` token to split into two rows for better readability
8. **Make sensible defaults** for ambiguous requests - never ask follow-up questions
9. **Always provide brief explanation** in response message describing what's being shown

**Column Layout Guidelines**:
- **1-7 columns**: Single row format (most common)
- **8-10 columns**: Two-row format using `NEWLINE` token
- **Example two-row format**:
  ```
  '__id__/TITLE:#', '__Subject__/TITLE:Subject', Status, QueueName, NEWLINE,
  OwnerName, Priority, '__CreatedRelative__/TITLE:Age', '__DueRelative__/TITLE:Due'
  ```
  This displays 8 columns across 2 rows, making each row easier to scan.

**Critical**: In natural language search contexts, the AI cannot ask follow-up questions. Always provide a complete TicketSQL query and Format string immediately, with sensible defaults for any ambiguous parts.

## Overview

This document describes the **Format** parameter syntax used to control how search results are displayed in RT. The Format parameter determines which columns appear in search results, how they're rendered, and how they're styled.

**Purpose**: Enable AI assistants and developers to construct proper Format strings for customizing ticket search result displays.

**Scope**: This document covers Format strings for RT::Tickets search results. Similar concepts apply to Assets, Transactions, and other searchable objects.

## Format String Basics

### What Format Controls

A Format string specifies:
- **Which columns to display**: id, Subject, Queue, Owner, Status, custom fields, etc.
- **How each column renders**: Plain text, clickable links, formatted dates, icons, buttons
- **Column headers**: Custom titles for each column
- **Styling**: CSS classes, inline styles, alignment, column spanning
- **Layout**: Multi-line headers, spacing, special formatting

### Simple Format Example

```
'__id__/TITLE:#', '__Subject__/TITLE:Subject', Status, Queue
```

This creates a 4-column display:
1. Ticket ID (header: "#")
2. Subject (header: "Subject")
3. Status (default header: "Status")
4. Queue (default header: "Queue")

### Format String Structure

A Format string is a **comma-separated list of column definitions**:

```
Format = Column1, Column2, Column3, ...
```

Each column can be:
- A simple field name: `Status`, `Queue`, `Priority`
- A quoted field reference: `'__id__'`, `'__Subject__'`
- A field with modifiers: `'__id__/TITLE:#'`
- Complex HTML: `'<a href="...">__id__</a>/TITLE:#'`
- Special tokens: `NEWLINE`, `NBSP`

## Field Reference Syntax

### Basic Field Syntax

Fields are referenced using double underscores:

```
__FieldName__
```

**Examples**:
- `__id__` - Ticket ID
- `__Subject__` - Ticket subject
- `__Status__` - Ticket status
- `__QueueName__` - Queue name

### Quoting Rules

**When to quote**:
- Field references with modifiers: `'__id__/TITLE:#'`
- HTML content: `'<a href="...">__id__</a>'`
- Fields with special characters in modifiers
- Complex expressions

**When quotes are optional**:
- Simple field names without modifiers: `Status`, `Queue`, `Priority`
- These are shorthand for `__Status__`, `__Queue__`, `__Priority__`

### Field Name Forms

**Simple name**:
- `Status` - Expands to `__Status__`
- `Queue` - Expands to `__Queue__`

**Explicit reference**:
- `__Status__` - Explicit field reference
- `__Subject__` - Explicit field reference

**With modifiers**:
- `'__Status__/TITLE:Current Status'` - Must be quoted
- `'__id__/TITLE:#/ALIGN:right'` - Multiple modifiers

## Modifiers

Modifiers customize how fields are displayed and provide metadata about columns. They use the syntax `/MODIFIER:value` and can be chained.

### Modifier Syntax

```
'__FieldName__/MODIFIER1:value1/MODIFIER2:value2'
```

Modifiers are separated by `/` and come after the field reference.

### Available Modifiers

#### /TITLE:HeaderText

Sets the column header text.

**Syntax**: `/TITLE:HeaderText`

**Examples**:
```
'__id__/TITLE:#'                           # Header: "#"
'__Subject__/TITLE:Summary'                # Header: "Summary"
'__Owner__/TITLE:Assigned To'              # Header: "Assigned To"
'__Created__/TITLE:Date Created'           # Header: "Date Created"
'__CustomField.{Department}__/TITLE:Dept'  # Header: "Dept"
```

**Special values**:
- `/TITLE:#` - Common for ticket ID column
- `/TITLE:NBSP` - Non-breaking space (invisible header)
- Empty title: `/TITLE:` - No header text

#### /CLASS:CssClass

Adds CSS class(es) to the table cell's inner `<div>` element.

**Syntax**: `/CLASS:class-name` or `/CLASS:class1 class2`

**RT 6 uses Bootstrap 5**, which provides extensive utility classes for styling without custom CSS.

**Bootstrap Text Utilities**:
```
'__Priority__/CLASS:text-primary'              # Blue text
'__Status__/CLASS:text-success'                # Green text
'__Status__/CLASS:text-danger'                 # Red text
'__Queue__/CLASS:text-warning'                 # Yellow text
'__Owner__/CLASS:text-muted'                   # Gray text
'__Subject__/CLASS:text-uppercase'             # Uppercase text
'__id__/CLASS:fw-bold'                         # Bold text
'__Subject__/CLASS:fst-italic'                 # Italic text
'__Status__/CLASS:text-decoration-underline'   # Underlined text
'__Subject__/CLASS:text-truncate'              # Truncate with ellipsis
```

**Bootstrap Background & Border Utilities**:
```
'__Priority__/CLASS:bg-light'                  # Light gray background
'__Status__/CLASS:bg-primary'                  # Blue background
'__Status__/CLASS:bg-success'                  # Green background
'__Status__/CLASS:bg-danger'                   # Red background
'__Status__/CLASS:bg-warning'                  # Yellow background
'__Status__/CLASS:bg-primary bg-opacity-10'    # Light blue (10% opacity)
'__Status__/CLASS:bg-warning rounded'          # Yellow with rounded corners
'__Subject__/CLASS:border border-primary'      # Blue border
```

**Bootstrap Spacing Utilities**:
```
'__Status__/CLASS:p-2'                         # Padding (all sides)
'__Status__/CLASS:px-3'                        # Horizontal padding
'__Status__/CLASS:py-2'                        # Vertical padding
'__Subject__/CLASS:m-2'                        # Margin (all sides)
'__Status__/CLASS:mx-auto'                     # Center horizontally
```

**Combining Multiple Classes**:
```
'__Status__/CLASS:text-danger bg-warning bg-opacity-25 p-2 rounded'
'__Subject__/CLASS:fw-bold text-primary text-truncate'
'__Priority__/CLASS:text-center bg-light p-2'
```

**Custom CSS Classes**:
```
'__Priority__/CLASS:priority-cell'
'__Status__/CLASS:status-badge text-center'
'__Due__/CLASS:date-field overdue-warning'
```

**Common use cases**:
- **Semantic coloring**: Use Bootstrap color utilities (`text-success`, `text-danger`) for status indication
- **Visual emphasis**: Apply Bootstrap typography classes (`fw-bold`, `fst-italic`) for importance
- **Layout control**: Use Bootstrap spacing utilities (`p-2`, `px-3`) for padding
- **Background highlights**: Use Bootstrap background utilities with opacity for subtle highlights
- **Custom styling**: Add custom class names for site-specific CSS
- **JavaScript hooks**: Use class names for DOM selection and event handling

**Best practices**:
- **Prefer Bootstrap utilities** over custom CSS for consistency and maintainability
- **Use semantic colors** (`text-success` for success, `text-danger` for errors)
- **Combine classes** for complex styling needs
- **Keep it simple** - avoid over-styling search results

#### /STYLE:CssStyle

Adds inline CSS styles to the table cell's inner `<div>` element.

**Syntax**: `/STYLE:property: value` or `/STYLE:prop1: val1; prop2: val2`

**When to use /STYLE: vs /CLASS:**
- **Use /CLASS:** For standard styling that fits Bootstrap's design system (colors, spacing, typography)
- **Use /STYLE:** For precise values, custom colors, or properties without Bootstrap utilities

**Custom Brand Colors**:
```
'__Status__/STYLE:color: #FF6B35'                           # Custom orange
'__Priority__/STYLE:color: #2C3E50; font-weight: 600'       # Dark blue, semi-bold
'__Subject__/STYLE:background-color: rgba(0, 123, 255, 0.1)'  # Transparent blue background
'__Status__/STYLE:border-left: 4px solid #28a745'           # Green left border
'__Queue__/STYLE:color: #6C757D; font-style: italic'        # Gray italic
```

**Precise Numerical Values**:
```
'__Subject__/STYLE:width: 123px'                            # Exact width
'__id__/STYLE:padding: 3px 7px'                             # Non-Bootstrap spacing
'__Subject__/STYLE:min-height: 45px; line-height: 1.2'      # Exact dimensions
'__Priority__/STYLE:font-size: 13px; letter-spacing: 0.05em'  # Typography control
'__Status__/STYLE:max-width: 200px'                         # Width constraint
```

**Layout & Display Properties**:
```
'__Subject__/STYLE:overflow: hidden; text-overflow: ellipsis; white-space: nowrap'  # Truncate text
'__Description__/STYLE:max-height: 100px; overflow-y: auto'                         # Scrollable content
'__Status__/STYLE:cursor: help'                                                     # Help cursor on hover
'__Code__/STYLE:font-family: Monaco, monospace; font-size: 13px'                    # Monospace font
'__Subject__/STYLE:display: block; max-width: 300px'                                # Block with max width
```

**Visual Effects**:
```
'__Priority__/STYLE:text-shadow: 1px 1px 2px rgba(0, 0, 0, 0.3)'     # Text shadow
'__Status__/STYLE:box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1)'          # Box shadow
'__Subject__/STYLE:border-bottom: 2px solid #007bff'                 # Bottom border
'__Queue__/STYLE:opacity: 0.7'                                        # Transparency
'__Status__/STYLE:background: linear-gradient(to right, #f8f9fa, #e9ecef)'  # Gradient
```

**Text Formatting**:
```
'__Subject__/STYLE:font-weight: 600'                                  # Semi-bold (not 500 or 700)
'__Status__/STYLE:text-transform: capitalize; font-variant: small-caps'  # Fancy caps
'__Description__/STYLE:word-break: break-word; hyphens: auto'        # Word breaking
'__Code__/STYLE:tab-size: 4; white-space: pre-wrap'                  # Code formatting
```

**Combining /CLASS: and /STYLE:**
```
'__Subject__/CLASS:fw-bold text-truncate/STYLE:max-width: 300px; color: #2c3e50'
'__Status__/CLASS:text-center p-2/STYLE:background-color: rgba(255, 193, 7, 0.1)'
'__Priority__/CLASS:rounded/STYLE:border: 2px solid #007bff; padding: 4px 8px'
```

**Common use cases**:
- **Corporate branding**: Apply exact brand colors not in Bootstrap palette
- **Precise control**: Use exact pixel values, custom fonts, or specific spacing
- **Complex effects**: Apply shadows, gradients, or multi-property styling
- **Text handling**: Control overflow, wrapping, and truncation behavior
- **Legacy compatibility**: Maintain existing format strings from RT 5 and earlier
- **Prototyping**: Quick one-off styling before creating custom CSS classes

**Best practices**:
- **Prefer /CLASS: with Bootstrap** for common styling needs (80% of cases)
- **Use /STYLE: for precision** when Bootstrap utilities don't meet requirements
- **Escape properly**: RT handles CSS escaping, but avoid user input in styles
- **Combine wisely**: Use /CLASS: for framework styles, /STYLE: for custom touches
- **Consider performance**: Inline styles work well, but shared CSS classes are more efficient

**Security note**: RT automatically escapes style values to prevent XSS attacks.

#### /ALIGN:Alignment

Sets horizontal alignment for the cell content using Bootstrap 5 text alignment classes.

**Syntax**: `/ALIGN:left|center|right`

**Implementation**: RT 6 converts alignment values to Bootstrap classes:
- `left` → `text-start` (Bootstrap 5 class)
- `center` → `text-center`
- `right` → `text-end`

**Examples**:
```
'__id__/TITLE:#/ALIGN:right'              # Right-align ticket IDs (text-end)
'__Priority__/TITLE:Pri/ALIGN:center'     # Center priority values (text-center)
'__Subject__/ALIGN:left'                  # Left-align subject (text-start, default)
'__Status__/ALIGN:center'                 # Center status values
'__TimeWorked__/ALIGN:right'              # Right-align numbers
```

**Common patterns**:
```
# Numeric columns aligned right
'__id__/TITLE:#/ALIGN:right'
'__Priority__/TITLE:Pri/ALIGN:right'
'__TimeWorked__/TITLE:Time/ALIGN:right'

# Short status/badge columns centered
'__Status__/TITLE:Status/ALIGN:center'
'__Queue__/TITLE:Queue/ALIGN:center'

# Text columns left-aligned (default)
'__Subject__/TITLE:Subject'               # No /ALIGN: needed for left
'__Owner__/TITLE:Owner'
```

**Default**: left (if not specified)

**Note**: RT 6 uses modern Bootstrap classes instead of deprecated HTML `align` attributes for better accessibility and maintainability.

#### /SPAN:Number

Sets column span (colspan) for the cell.

**Syntax**: `/SPAN:N` where N is the number of columns to span

**Examples**:
```
'__Subject__/SPAN:2'                      # Subject spans 2 columns
'Header Text/SPAN:3'                      # Static text spans 3 columns
```

**Use cases**:
- Wide columns for long content
- Merged header cells
- Layout spacing

#### /ATTRIBUTE:FieldName

Specifies the field name used for sorting and grouping.

**Syntax**: `/ATTRIBUTE:ActualFieldName`

**Examples**:
```
'__QueueName__/ATTRIBUTE:Queue'           # Sort by Queue ID, display Queue name
'__OwnerName__/ATTRIBUTE:Owner'           # Sort by Owner ID, display Owner name
'Custom Label/ATTRIBUTE:Priority'         # Custom display, sort by Priority
```

**When needed**:
- Display field differs from sort field
- Custom labels that need sortability
- Computed or formatted values

#### /CALENDAR:start|end

Marks a date field as the start or end of a multi-day calendar event span. Used only in calendar view — ignored in table/list views.

**Syntax**: `/CALENDAR:start` or `/CALENDAR:end`

**Examples**:
```
'__CF.{Project Start}__/CALENDAR:start', '__CF.{Project End}__/CALENDAR:end', '__Due__'
'__Starts__/CALENDAR:start', '__CF.{Target Date}__/CALENDAR:end'
```

**Behavior**:
- Both `/CALENDAR:start` and `/CALENDAR:end` must be present on date fields for multi-day spans to work
- If only one is specified, it is ignored and the calendar falls back to auto-detection (Starts+Due or Started+Resolved)
- If multiple fields have the same `/CALENDAR:` value, the first one encountered is used
- Fields marked as start/end are displayed as multi-day span bars; they are suppressed as individual date dots
- Other date fields in the same Format (without `/CALENDAR:`) still appear as individual date dots
- Can be applied to both built-in date fields and date custom fields

**Auto-detection (default when no /CALENDAR: modifiers)**:
When no `/CALENDAR:` modifiers are present, the calendar automatically detects multi-day pairs:
1. Starts + Due (preferred)
2. Started + Resolved (fallback)

### Modifier Combinations

Modifiers can be chained in any order:

```
'__id__/TITLE:#/ALIGN:right/CLASS:ticket-id'
'__Status__/TITLE:State/CLASS:badge/STYLE:font-size:0.9em'
'__Priority__/TITLE:Pri/ALIGN:center/ATTRIBUTE:Priority'
'__CF.{Start Date}__/CALENDAR:start/TITLE:Start'
```

**Processing order**: Modifiers are processed left-to-right as parsed.

## Query Builder Display Options

The Query Builder (Search → Edit Search → Display Columns) provides UI options that generate formatted output. These options wrap fields in Bootstrap 5 classes and semantic HTML.

### Face Option

Controls text styling using Bootstrap typography utilities.

**Available values**:
- **Bold** - Generates `<span class="fw-bold">field</span>`
- **Italic** - Generates `<span class="fst-italic">field</span>`

**Examples**:
```
# User selects Face=Bold for Subject field in Query Builder
Result: '<span class="fw-bold">__Subject__</span>'

# User selects Face=Italic for Status field
Result: '<span class="fst-italic">__Status__</span>'
```

**Bootstrap classes used**:
- `fw-bold` - Font weight bold (replaces deprecated `<b>` tag)
- `fst-italic` - Font style italic (replaces deprecated `<i>` tag)

**Manual alternative**: You can achieve the same result by writing the HTML directly in format strings:
```
'<span class="fw-bold">__Subject__</span>/TITLE:Subject'
```

### Size Option

Controls text size using Bootstrap font-size utilities and semantic HTML.

**Available values**:
- **Large** - Generates `<span class="fs-4">field</span>` (1.5rem, larger than default)
- **Small** - Generates `<small>field</small>` (0.875em, smaller than default)

**Examples**:
```
# User selects Size=Large for Priority field in Query Builder
Result: '<span class="fs-4">__Priority__</span>'

# User selects Size=Small for id field
Result: '<small>__id__</small>'
```

**Bootstrap classes used**:
- `fs-4` - Font size 1.5rem (Bootstrap font-size scale, larger than default)
- `<small>` - Semantic HTML element, styled by Bootstrap at 0.875em

**Manual alternative**: Write the HTML directly:
```
'<span class="fs-4">__Priority__</span>/TITLE:Priority'
'<small>__id__</small>/TITLE:#'
```

### Combining Face and Size

The Query Builder allows combining both options, which generates nested HTML wrappers.

**Examples**:
```
# Face=Bold and Size=Large
Result: '<span class="fw-bold"><span class="fs-4">__Subject__</span></span>'

# Face=Italic and Size=Small
Result: '<span class="fst-italic"><small>__Status__</small></span>'
```

**Nesting order**: Face wrapper (outer) → Size wrapper (inner) → field

**Visual result**: A field that is both bold and large, or both italic and small.

### Direct HTML Approach

For maximum flexibility, write Bootstrap classes directly in your format strings instead of using the Query Builder UI:

**Using Query Builder**:
1. Select field: "Subject"
2. Set Face: "Bold"
3. Set Size: "Large"
4. Result: `<span class="fw-bold"><span class="fs-4">__Subject__</span></span>`

**Using Manual Format**:
```
# More efficient - single span with multiple classes
'<span class="fw-bold fs-4">__Subject__</span>/TITLE:Subject'

# Or use /CLASS: modifier for dynamic styling
'__Subject__/CLASS:fw-bold fs-4/TITLE:Subject'
```

**Advantage of manual approach**:
- Single element with multiple classes (cleaner HTML)
- Can combine with other Bootstrap utilities
- More control over exact markup

**Advantage of Query Builder approach**:
- User-friendly GUI for non-technical users
- No HTML knowledge required
- Generates valid format strings automatically

### Bootstrap 5 Typography Reference

Common Bootstrap typography classes for manual format strings:

**Font Weight**:
- `fw-light` - Light (300)
- `fw-normal` - Normal (400)
- `fw-bold` - Bold (700)
- `fw-bolder` - Bolder (relative)

**Font Style**:
- `fst-normal` - Normal (not italic)
- `fst-italic` - Italic

**Font Size** (from large to small):
- `fs-1` - 2.5rem (largest)
- `fs-2` - 2rem
- `fs-3` - 1.75rem
- `fs-4` - 1.5rem (used for "Large")
- `fs-5` - 1.25rem
- `fs-6` - 1rem (default)
- `<small>` - 0.875em (used for "Small")

**Text Transform**:
- `text-lowercase` - Lowercase
- `text-uppercase` - Uppercase
- `text-capitalize` - Capitalize first letter

**Example combinations**:
```
'__Subject__/CLASS:fw-bold fs-3 text-uppercase/TITLE:SUBJECT'
'__Status__/CLASS:fst-italic text-lowercase/TITLE:status'
'__Priority__/CLASS:fw-bolder fs-2/TITLE:Priority'
```

## Special Tokens

### NEWLINE

Creates a line break in the column headers, allowing multi-row headers.

**Usage**:
```
'__id__/TITLE:#', NEWLINE, '__Subject__/TITLE:Summary', Status
```

**Result**:
- Row 1 headers: "#" | (empty)
- Row 2 headers: (empty) | "Summary" | "Status"

**Common pattern** - Two-row headers:
```
'__id__', '__Queue__', NEWLINE, '__Subject__', '__Status__'
```

### NBSP

Inserts a non-breaking space, useful for spacing or empty columns.

**Usage**:
```
'__id__', NBSP, '__Subject__', Status
```

**Use cases**:
- Visual spacing between column groups
- Empty columns for layout
- Padding between elements

### Special Token Placement

Special tokens are **standalone** - not quoted, not modified:

**Correct**:
```
'__id__', NEWLINE, '__Subject__'
'__Queue__', NBSP, '__Status__'
```

**Incorrect**:
```
'__id__/NEWLINE'              # NEWLINE is not a modifier
'__Subject__, NBSP'           # NBSP must be separate
```

## Natural Language Request Patterns (AI Guide)

This section maps common natural language requests to Format string patterns. **AI assistants should use these patterns to interpret user intent.**

### Request Pattern Categories

#### Category 1: Basic Display Requests

**Pattern**: Simple viewing without specific requirements

**Keywords**: "show", "list", "display", "get", "find", "see"

**User Says** → **AI Interprets** → **Format Pattern**

"Show me tickets"
→ Basic display with core fields
→ `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject', Status, QueueName`

"List all tickets"
→ Same as above
→ Same format

"Display ticket information"
→ Same as above
→ Same format

"Get me a ticket list"
→ Same as above
→ Same format

#### Category 2: Ownership & Assignment

**Pattern**: Questions about who owns or is responsible for tickets

**Keywords**: "owner", "assigned", "responsible", "taken by", "who owns", "belonging to"

**User Says** → **Format Pattern**

"Show tickets with owner"
→ `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject', Status, OwnerName`

"Who owns these tickets"
→ Same as above

"List tickets by assigned person"
→ Same as above

"Show me who's responsible for each ticket"
→ Same as above

"Display tickets with assignment"
→ Same as above

#### Category 3: Time & Recency

**Pattern**: Questions about when tickets were created or updated

**Keywords**: "recent", "latest", "new", "old", "age", "when", "created", "updated", "modified", "aging", "stale"

**User Says** → **Format Pattern**

"Show recent tickets"
→ `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject', Status, '__CreatedRelative__/TITLE:Age'`

"List latest tickets"
→ Same as above

"Display new tickets"
→ Same as above

"Show aging tickets"
→ Same as above

"How old are these tickets"
→ Same as above

"When were tickets created"
→ Same as above

"Show tickets with creation date"
→ Replace CreatedRelative with Created if user explicitly wants exact dates

"Display recently updated tickets"
→ `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject', Status, '__LastUpdatedRelative__/TITLE:Last Updated'`

"Show activity on tickets"
→ Same as above

"List tickets modified recently"
→ Same as above

#### Category 4: Customer/Requestor Information

**Pattern**: Questions about who requested tickets

**Keywords**: "requestor", "requester", "customer", "reporter", "submitted by", "created by", "who requested", "contact"

**User Says** → **Format Pattern**

"Show who requested tickets"
→ `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject', Status, '__Requestor.Name__/TITLE:Requestor'`

"Display customer for each ticket"
→ Same as above

"List tickets with requestor"
→ Same as above

"Show who submitted these"
→ Same as above

"Include requestor email"
→ `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject', Status, '__Requestor.EmailAddress__/TITLE:Contact'`

"Show customer contact info"
→ `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject', '__Requestor.Name__/TITLE:Requestor', '__Requestor.EmailAddress__/TITLE:Email'`

"Display reporter information"
→ Same as above (Name + Email)

#### Category 5: Priority & Urgency

**Pattern**: Questions about ticket importance

**Keywords**: "priority", "urgent", "importance", "critical", "severity"

**User Says** → **Format Pattern**

"Show ticket priority"
→ `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject', Status, Priority`

"Display urgent tickets"
→ Same as above

"List by importance"
→ Same as above

"Show severity"
→ Same as above

"Include priority level"
→ Same as above

#### Category 6: Deadlines & Due Dates

**Pattern**: Questions about when tickets are due

**Keywords**: "due", "deadline", "overdue", "when due", "due date"

**User Says** → **Format Pattern**

"Show due dates"
→ `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject', Status, '__DueRelative__/TITLE:Due'`

"Display deadlines"
→ Same as above

"List overdue tickets"
→ Same as above (DueRelative highlights overdue in red)

"When are tickets due"
→ Same as above

"Show tickets with due dates"
→ Replace DueRelative with Due if user explicitly wants exact dates

#### Category 7: Time Tracking

**Pattern**: Questions about work time and effort

**Keywords**: "time worked", "hours", "time spent", "effort", "estimate", "estimated time", "remaining", "time left"

**User Says** → **Format Pattern**

"Show time worked"
→ `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject', Status, TimeWorked`

"Display hours spent"
→ Same as above

"List effort on tickets"
→ Same as above

"Show time tracking"
→ `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject', Status, TimeWorked, TimeEstimated, TimeLeft`

"Include time estimates"
→ `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject', Status, TimeEstimated`

"Show remaining time"
→ `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject', Status, TimeLeft`

#### Category 8: Queue & Categorization

**Pattern**: Questions about ticket organization

**Keywords**: "queue", "which queue", "category", "bucket", "department", "team", "group"

**User Says** → **Format Pattern**

"Show which queue"
→ `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject', QueueName, Status`

"Display ticket categories"
→ Same as above

"List by queue"
→ Same as above

"Show department"  (if literal department field)
→ Add QueueName if queue represents departments, or add CustomField.{Department} if custom field exists

#### Category 9: Custom Fields

**Pattern**: Questions about custom attributes

**Keywords**: Mentions of specific custom field names like "department", "customer", "project", "category", specific domain terminology

**User Says** → **Format Pattern**

"Show department field"
→ `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject', Status, '__CustomField.{Department}__/TITLE:Dept'`

"Include customer name"  (if custom field exists)
→ `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject', Status, '__CustomField.{Customer Name}__/TITLE:Customer'`

"Display project information"
→ `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject', Status, '__CustomField.{Project}__/TITLE:Project'`

**AI Note**: If custom field name is unclear, use the most common interpretation or search for related field names. If unable to determine, omit the custom field and explain in the response message.

#### Category 10: Dependencies & Relationships

**Pattern**: Questions about ticket relationships

**Keywords**: "depends", "dependencies", "blocked", "blocking", "related", "parent", "child", "linked"

**User Says** → **Format Pattern**

"Show dependencies"
→ `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject', Status, DependsOn`

"What's blocking tickets"
→ Same as above OR use ExtendedStatus for inline blocking display

"Display blocked tickets"
→ Same as above

"Show what tickets block"
→ `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject', Status, DependedOnBy`

"List related tickets"
→ `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject', Status, RefersTo, ReferredToBy`

"Show parent tickets"
→ `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject', Status, Parents`

"Display child tickets"
→ `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject', Status, Children`

#### Category 11: Interactive Elements

**Pattern**: Requests for buttons or interactive controls

**Keywords**: "bookmark", "reply", "comment", "action", "button"

**User Says** → **Format Pattern**

"Add bookmark button"
→ `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject', Status, Bookmark`

"Include reply button"
→ `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject', Status, Reply`

"Show comment button"
→ `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject', Status, Comment`

"Add action buttons"
→ `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject', Status, Reply, Comment`

#### Category 12: Styling Requests

**Pattern**: Requests for visual formatting

**Keywords**: "bold", "italic", "large", "small", "highlight", "color", "red", "green", "center", "align"

**User Says** → **Format Pattern**

"Make subject bold"
→ `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '<span class="fw-bold">__Subject__</span>/TITLE:Subject', Status`

"Show priority in large text"
→ `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '__Subject__/TITLE:Subject', Status, '<span class="fs-4">__Priority__</span>/TITLE:Priority'`

"Make status italic"
→ `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '__Subject__/TITLE:Subject', '<span class="fst-italic">__Status__</span>/TITLE:Status'`

"Highlight overdue tickets in red"
→ `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '__Subject__/TITLE:Subject', Status, '__DueRelative__/CLASS:text-danger/TITLE:Due'`

"Center align priority"
→ `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '__Subject__/TITLE:Subject', Status, '__Priority__/TITLE:Pri/ALIGN:center'`

"Right align ID numbers"
→ `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#/ALIGN:right', '__Subject__/TITLE:Subject', Status`

### Multi-Concept Requests

When user mentions multiple concepts, combine fields appropriately:

**User Says** → **AI Interprets** → **Format Pattern**

"Show recent tickets with owner and priority"
→ Combines: recency + ownership + priority
→ `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject', Status, CreatedRelative, OwnerName, Priority`

"List overdue tickets by department"
→ Combines: deadline + custom field
→ `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject', Status, DueRelative, '__CustomField.{Department}__/TITLE:Dept'`

"Display aging tickets with customer contact"
→ Combines: age + requestor info
→ `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject', Status, CreatedRelative, '__Requestor.Name__/TITLE:Requestor', '__Requestor.EmailAddress__/TITLE:Email'`

"Show time worked and estimates for assigned tickets"
→ Combines: time tracking + ownership
→ `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject', Status, OwnerName, TimeWorked, TimeEstimated`

"List high priority tickets with deadlines and owners"
→ Combines: priority + deadline + ownership
→ `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject', Status, Priority, DueRelative, OwnerName`

### Ambiguous Requests (AI Should Choose Sensible Defaults)

When user requests are unclear, AI should choose sensible defaults and provide a brief explanation in the response message.

**User Says** → **AI Default Choice** → **Explanation to Show User**

"Show ticket dates"
→ Use `CreatedRelative` and `LastUpdatedRelative`
→ "Showing creation date and last update (as relative times like '2 days ago')"

"Display people"
→ Use `OwnerName` and `Requestor.Name`
→ "Showing ticket owner and requestor"

"Show custom information"
→ Omit custom fields, use standard format
→ "Using standard columns - specific custom fields can be requested if needed"

"Include time information"
→ Use `CreatedRelative` (age of ticket)
→ "Showing ticket age (time since creation)"

"Show related information"
→ Use `DependsOn` and `RefersTo`
→ "Showing ticket dependencies and references"

"Show dates"
→ Use relative dates (`CreatedRelative`, `DueRelative`)
→ "Showing dates as relative times (e.g., '3 days ago')"

"Show contact info"
→ Use `Requestor.EmailAddress`
→ "Showing requestor email address"

"Show all information"
→ Use Tier 1 + Tier 2 most common fields with two-row layout (8 columns)
→ Format: `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject', QueueName, Status, NEWLINE, OwnerName, Priority, '__CreatedRelative__/TITLE:Age', '__LastUpdatedRelative__/TITLE:Updated'`
→ "Showing most commonly used ticket information across two rows"

**Default Resolution Strategy**:
1. **Choose the most common interpretation** based on Intent Recognition Patterns
2. **Prefer Tier 1 and Tier 2 fields** over advanced fields
3. **Default to relative dates** unless "exact" or "specific date" is mentioned
4. **Include both owner and requestor** if "people" mentioned without specifics
5. **Use formatted fields** (OwnerName vs Owner, QueueName vs Queue)
6. **Keep column count reasonable** (5-7 columns for single row, 8-10 for two rows)
7. **Use NEWLINE for 8+ columns** to create two-row layout for better readability
8. **Provide brief explanation** in response message describing what's being shown

### Field Selection Priority Rules for AI

1. **Always include**: id (as link), Subject (as link)
2. **Usually include**: Status, QueueName (unless user excludes)
3. **Add if mentioned**: Any specifically requested field
4. **Infer if context suggests**:
   - User asks about "recent" → Add CreatedRelative
   - User asks about "who" → Add OwnerName or Requestor.Name based on context
   - User asks about "when due" → Add DueRelative
   - User asks about "how long" or "time" → Add TimeWorked
5. **Default to relative dates** unless user says "exact", "specific", or "date"
6. **Use formatted variants**:
   - Prefer OwnerName over Owner
   - Prefer QueueName over Queue
   - Prefer Requestor.Name or Requestor.EmailAddress over bare Requestor
7. **Keep column count reasonable**: 4-7 columns optimal (single row), 8-10 columns (two rows with NEWLINE), avoid exceeding 10
8. **Use two-row layout**: Insert NEWLINE token when displaying 8 or more columns for better readability

### Special Case Handling

**Case**: User mentions exact numbers or ranges
"Show tickets older than 30 days"
→ This is primarily a Query (TicketSQL) request
→ Provide TicketSQL: `Created < '30 days ago'`
→ Provide default Format with age field: `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject', Status, QueueName, '__CreatedRelative__/TITLE:Age'`
→ Message: "Searching for tickets older than 30 days, showing age column for reference"

**Case**: User asks about sorting
"Sort tickets by priority"
→ Provide both OrderBy parameter and sensible Format
→ Provide OrderBy: `Priority`
→ Provide Format that includes priority: `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject', Status, Priority`
→ Message: "Sorting by priority (highest first)"

**Case**: User requests many fields
"Show everything about tickets"
→ Use comprehensive but readable format with two-row layout (8 columns)
→ Provide: `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#', '<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject', QueueName, Status, NEWLINE, OwnerName, Priority, '__CreatedRelative__/TITLE:Age', '__LastUpdatedRelative__/TITLE:Updated'`
→ Message: "Showing comprehensive ticket information across two rows for easier reading"

**Case**: User asks for "everything" or "all fields"
→ Default to most common comprehensive format (8 columns maximum)
→ Never exceed 10 columns for readability
→ Focus on Tier 1 and Tier 2 fields

## Field Categories

RT provides 80+ fields for ticket search results, organized into categories:

### Core Ticket Fields

Basic ticket attributes accessible directly.

#### Identification
- **id** - Ticket ID number
  - Display: Numeric ID
  - Common usage: `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#'`

- **EffectiveId** - Effective ticket ID (same as id unless ticket is merged)
  - Display: Numeric ID
  - Usage: Rarely displayed directly

- **Type** - Ticket type (ticket, reminder, approval)
  - Display: Type name
  - Default: "ticket"

#### Content
- **Subject** - Ticket subject/title
  - Display: Text (may be truncated in some views)
  - Common: `'<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject'`
  - Empty tickets: Shows "(No subject)"

- **Description** - Ticket description (body text)
  - Display: HTML-scrubbed content
  - Note: Not sortable (sortable => 0)
  - Inline editable via modal

#### Queue
- **Queue** - Queue ID number
  - Display: Numeric queue ID
  - For display, usually prefer QueueName

- **QueueName** - Queue name
  - Display: Queue name as text
  - Sortable by Queue ID via attribute
  - Common usage: `QueueName` (simple form)

#### Status
- **Status** - Current ticket status
  - Display: Localized status name
  - Examples: "new", "open", "resolved", "rejected"
  - Inline editable via dropdown

- **ExtendedStatus** - Status with dependency information
  - Display: Status with pending ticket links if blocked
  - Shows: "(pending approval)", "(pending ticket #123)", "(pending N other tickets)"
  - Provides clickable links to blocking tickets

### Priority Fields

- **Priority** - Current priority (0-100)
  - Display: Numeric value
  - Inline editable

- **InitialPriority** - Starting priority when ticket created
  - Display: Numeric value
  - Inline editable

- **FinalPriority** - Target priority when ticket due
  - Display: Numeric value
  - Inline editable

### Date Fields

Date fields come in two variants: **absolute** and **relative**.

#### Absolute Dates

Display as formatted date/time strings.

- **Created** - When ticket was created
  - Display: "2024-01-15 14:30:00" (formatted per user preference)

- **Starts** - When ticket work should start
  - Display: Formatted date or empty

- **Started** - When ticket work actually started
  - Display: Formatted date or empty

- **Due** - When ticket is due
  - Display: Formatted date or empty
  - Special: Overdue dates highlighted in red if ticket still active

- **Resolved** - When ticket was resolved
  - Display: Formatted date or empty

- **Told** - Last correspondence with requestor
  - Display: Formatted date or empty

- **LastUpdated** - Last modification time
  - Display: Formatted date

#### Relative Dates

Display as human-readable age strings ("2 days ago", "3 weeks ago").

- **CreatedRelative** - Age since creation
  - Display: "2 hours ago", "3 days ago", "2 weeks ago"

- **StartsRelative** - Time until/since start date

- **StartedRelative** - Time since actually started

- **DueRelative** - Time until/since due date
  - Special: Overdue dates highlighted if ticket active

- **ResolvedRelative** - Time since resolution

- **ToldRelative** - Time since last told requestor

- **LastUpdatedRelative** - Time since last update

**Common pattern**: Use relative dates for recent activity, absolute for historical data.

### Actor Fields

Track who created, owns, or updated tickets.

- **CreatedBy** - Username of ticket creator
  - Display: Creator's username
  - Attribute: Links to Creator ID for sorting

- **LastUpdatedBy** - Username of last updater
  - Display: Last updater's username
  - Attribute: Links to LastUpdatedBy ID

### Owner Fields

- **Owner** - Owner role (can include subfields)
  - Display: Owner principal (may show as group)
  - Subfields: `.Name`, `.EmailAddress`, `.RealName`, `.id`
  - Inline editable

- **OwnerName** - Owner's name
  - Display: Formatted user display (name with avatar/icon)
  - Sortable by Owner ID
  - Common usage for readable owner display

- **OwnerNameEdit** - Owner name with inline editing
  - Display: Owner name as text
  - Inline editable via autocomplete dropdown

### Time Tracking Fields

- **TimeWorked** - Total time worked (minutes)
  - Display: Formatted as "X hours Y minutes"
  - Inline editable

- **TimeEstimated** - Estimated time to complete
  - Display: Formatted time string
  - Inline editable

- **TimeLeft** - Time remaining
  - Display: Formatted time string
  - Inline editable

### Watcher Fields (Roles)

Watchers are users associated with tickets in various roles. Support subfields for detailed display.

#### Core Watchers

- **Requestor** / **Requestors** - Ticket requestor(s)
  - Display: Formatted principal display
  - Subfields: `.Name`, `.EmailAddress`, `.RealName`, `.Nickname`, `.Organization`, etc.
  - Examples:
    - `Requestor` - Full formatted display
    - `Requestor.Name` - Just username
    - `Requestor.EmailAddress` - Just email
    - `Requestor.RealName` - Real name

- **Cc** / **Ccs** - Carbon copy watchers
  - Same subfield support as Requestor

- **AdminCc** / **AdminCcs** - Administrative watchers
  - Same subfield support as Requestor

#### Watcher Subfields

All watcher fields support these subfields:

- `.Name` - Username
- `.EmailAddress` - Email address
- `.RealName` - Full name
- `.Nickname` - Nickname
- `.Organization` - Organization
- `.Address1`, `.Address2` - Street address
- `.City`, `.State`, `.Zip`, `.Country` - Location
- `.WorkPhone`, `.HomePhone`, `.MobilePhone`, `.PagerPhone` - Contact info
- `.id` - User ID number

**Example**:
```
'__Requestor.EmailAddress__/TITLE:Contact'
'__Owner.RealName__/TITLE:Assigned To'
```

### Link Fields

Display related tickets via RT's linking system.

#### Link Types

All link types from `RT::Link::TYPEMAP` are available:

- **RefersTo** - Tickets this ticket refers to
- **ReferredToBy** - Tickets that refer to this ticket
- **DependsOn** - Tickets this depends on
- **DependedOnBy** - Tickets that depend on this
- **MemberOf** - Parent tickets
- **HasMember** - Child tickets (members)
- **Parents** - Parent tickets
- **Children** - Child tickets

**Display**: Links render as clickable links with ticket IDs/URIs.

**Filtering by object type**:
```
RefersTo.{Ticket}      # Only ticket links
RefersTo.{Asset}       # Only asset links
MemberOf.{Ticket}      # Parent tickets only
```

### Custom Fields

Custom fields use special syntax with the field name in braces.

**Syntax**: `CustomField.{FieldName}` or `CF.{FieldName}`

**Examples**:
```
'__CustomField.{Department}__/TITLE:Dept'
'__CF.{Priority Level}__/TITLE:Priority'
'__CustomField.{Customer Name}__'
```

**Braces required** when field name contains spaces or special characters.

**View-only variant**: `CustomFieldView.{Name}` - Same as CustomField but without inline editing.

**Display varies by custom field type**:
- Text fields: Plain text
- Select fields: Selected value
- Date fields: Formatted date
- Multi-value: Bulleted HTML list

### Custom Roles

Custom roles use similar syntax to custom fields.

**Syntax**:
- By numeric ID: `CustomRole.{5}.Field`
- By role name: `'CustomRole.{RoleName}.Field'` (must quote entire expression)

**Subfield required**: Must specify which user attribute to display.

**Available subfields**: Same as core watchers (`.Name`, `.EmailAddress`, `.RealName`, `.id`, etc.)

**Examples**:
```
'__CustomRole.{5}.Name__/TITLE:Engineer'
'__CustomRole.{Sales}.EmailAddress__/TITLE:Sales Contact'
'__CustomRole.{7}.RealName__/TITLE:Department Head'
```

**Note**: Role names require quoting the entire expression; numeric IDs don't.

### Action Fields

Interactive buttons/controls in the search results.

- **Reply** - Reply button for correspondence
  - Display: Button that opens reply modal
  - Requires: ReplyToTicket or ModifyTicket right
  - Not sortable

- **Comment** - Comment button for internal notes
  - Display: Button that opens comment modal
  - Requires: CommentOnTicket or ModifyTicket right
  - Not sortable

### Special Display Fields

- **Bookmark** - Bookmark toggle control
  - Display: Star icon for bookmarking tickets
  - Interactive: Click to bookmark/unbookmark
  - Shows bookmarked state

- **UpdateStatus** - Unread message indicator
  - Display: "New" link if unread messages, "No" if all read
  - Links to first unread transaction
  - Helps track which tickets have updates

- **SLA** - Service Level Agreement
  - Display: SLA name
  - Requires: RT::Extension::SLA or similar
  - Inline editable

### Encryption Fields

For sites using GPG/SMIME encryption:

- **KeyRequestors** - Requestors with key trust indicators
  - Display: Requestor list with "(no pubkey!)" or "(untrusted!)" warnings

- **KeyOwner** - Owner with key trust indicator
  - Display: Owner with trust status

- **KeyOwnerName** - Owner name with key trust text
  - Display: "username (untrusted!)"

### Helper Fields

Fields providing context and functionality:

- **WebPath** - RT's web path (e.g., "/rt")
- **WebBaseURL** - RT's base URL
- **WebURL** - Full RT URL
- **WebHomePath** - User's home path (adjusts for SelfService)
- **CurrentUser** - Current user's ID
- **CurrentUserName** - Current user's username

**Usage**: Primarily for building URLs in clickable links.

### Row Control Fields

Special fields for row-level functionality:

- **CheckBox** - Checkbox for bulk operations
  - Display: Checkbox with "Update" header
  - Used for bulk ticket updates

- **RadioButton** - Radio button for single selection
  - Display: Radio button for selecting one ticket
  - Common in ticket pickers

- **_CLASS** - Dynamic CSS class for rows
  - Returns: 'oddline' or 'evenline' for row striping
  - Usage: Applied automatically to `<tr>` elements

- **_CHECKBOX** - Legacy bulk update checkbox
  - Display: Checked checkbox per row
  - Default: checked="checked"

## Common Format Patterns

### Minimal Format

Simplest useful format:

```
'__id__/TITLE:#', '__Subject__/TITLE:Subject', Status, Queue
```

### Standard Format with Links

Ticket ID and Subject as clickable links:

```
'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#',
'<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject',
QueueName, ExtendedStatus
```

### Default "My Tickets" Format

From `etc/initialdata`:

```
'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#',
'<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject',
Priority, QueueName, ExtendedStatus
```

### Format with Relative Dates

Show age instead of absolute dates:

```
'__id__/TITLE:#',
'__Subject__/TITLE:Subject',
Status,
'__CreatedRelative__/TITLE:Age',
'__LastUpdatedRelative__/TITLE:Updated'
```

### Format with Owner and Requestor

```
'__id__/TITLE:#',
'__Subject__/TITLE:Subject',
QueueName,
Status,
'__OwnerName__/TITLE:Owner',
'__Requestor.Name__/TITLE:Requestor'
```

### Format with Custom Fields

```
'__id__/TITLE:#',
'__Subject__/TITLE:Subject',
'__CustomField.{Department}__/TITLE:Dept',
'__CustomField.{Priority Level}__/TITLE:Priority',
Status
```

### Format with Time Tracking

```
'__id__/TITLE:#',
'__Subject__/TITLE:Subject',
Status,
'__TimeWorked__/TITLE:Worked',
'__TimeEstimated__/TITLE:Estimate',
'__TimeLeft__/TITLE:Remaining'
```

### Multi-Line Header Format

Create two-row headers:

```
'__id__/TITLE:#',
'__Queue__/TITLE:Queue',
'__Status__/TITLE:Status',
NEWLINE,
'__Subject__/TITLE:Subject',
'__Owner__/TITLE:Owner',
'__Priority__/TITLE:Pri'
```

Results in:
```
Row 1: #     | Queue  | Status  |
Row 2: Subject | Owner  | Pri     |
```

### Format with Styling

Apply custom styling:

```
'__id__/TITLE:#/ALIGN:right',
'__Subject__/TITLE:Subject',
'__Priority__/TITLE:Pri/ALIGN:center/CLASS:priority-badge',
'__Status__/TITLE:Status/CLASS:status-cell'
```

### Format with Action Buttons

Include interactive controls:

```
'__id__/TITLE:#',
'__Subject__/TITLE:Subject',
Status,
QueueName,
Bookmark,
Reply,
Comment
```

### Unowned Tickets Format

From `etc/initialdata` - includes Take link:

```
'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#',
'<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject',
QueueName,
ExtendedStatus,
CreatedRelative,
'<A HREF="__WebPath__/Ticket/Display.html?Action=Take&id=__id__">__loc(Take)__</a>/TITLE:NBSP'
```

## Format Construction Guidelines

### Usage Tiers and Recommendations

Format fields and patterns fall into usage tiers. **AI should prefer common patterns** unless the user specifically requests advanced features.

#### Tier 1: Most Common (Use by Default)

These patterns appear in 80%+ of formats and should be the AI's first choice:

**Fields**:
- `id` - Usually as clickable link
- `Subject` - Usually as clickable link
- `Status` - Plain display
- `Queue` or `QueueName` - Plain display
- `Priority` - Plain display
- `Owner` or `OwnerName` - Plain display

**Typical Format**:
```
'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#',
'<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject',
QueueName, Status
```

**When to use**: Default for "show me tickets" requests

#### Tier 2: Common (Use When Relevant)

These appear in 40-80% of formats when the context requires them:

**Fields**:
- `CreatedRelative`, `LastUpdatedRelative`, `DueRelative` - When showing age/activity
- `Requestor.Name` or `Requestor.EmailAddress` - When showing who requested
- `ExtendedStatus` - When dependencies matter
- `TimeWorked`, `TimeEstimated` - When time tracking relevant
- `CustomField.{Name}` - When specific CF mentioned

**Example**:
```
'__id__/TITLE:#', '__Subject__/TITLE:Subject',
Status, OwnerName,
'__CreatedRelative__/TITLE:Age'
```

**When to use**: User mentions time, ownership, or specific custom fields

#### Tier 3: Specialized (Use Only When Requested)

These serve specific purposes and should only appear when explicitly needed:

**Fields**:
- `Bookmark` - Only when user mentions bookmarks
- `Reply`, `Comment` - Only when user wants action buttons
- `SLA` - Only when user mentions SLA
- `UnreadMessages` - Only when tracking unread important
- Link fields (`DependsOn`, `RefersTo`, etc.) - Only when relationships matter
- Absolute dates (`Created`, `Due`) - Only when specific dates needed (prefer relative)

**Modifiers**:
- `/CLASS:`, `/STYLE:` - Only for custom styling requests
- `/ALIGN:` - Only when alignment specifically requested
- `NEWLINE` - Only for multi-line header requests

**When to use**: User explicitly asks for these features

#### Tier 4: Advanced (Rare, Specialist Use)

These are rarely used and should only appear when specifically requested:

**Fields**:
- Encryption fields (`KeyOwner`, `KeyRequestors`) - Only for encrypted sites
- `Timer` - Only if time tracking with timers
- `TotalTimeWorked` - Only if config enabled and user needs rollup
- Row controls (`CheckBox`, `RadioButton`, `_CLASS`) - Only for special interfaces
- `Type` - Only when distinguishing tickets/reminders/approvals

**Complex patterns**:
- Multi-line headers with `NEWLINE`
- Heavily styled columns
- Custom HTML beyond standard links
- Multiple action buttons

**When to use**: User has specific, advanced requirements

### Default Format Decision Tree for AI

When constructing a Format string, follow this decision tree:

```
1. Start with Tier 1 (Most Common):
   - ID as link: '<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#'
   - Subject as link: '<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject'
   - Status: Status
   - Queue: QueueName

2. Add from Tier 2 (Common) based on user request:
   - Mentions "who owns" or "owner" → Add OwnerName
   - Mentions "age", "recent", "when" → Add CreatedRelative or LastUpdatedRelative
   - Mentions "due", "deadline" → Add DueRelative
   - Mentions "who requested" → Add Requestor.Name or Requestor.EmailAddress
   - Mentions specific custom field → Add CustomField.{Name}
   - Mentions "priority" explicitly → Add Priority (otherwise optional)

3. Add from Tier 3 (Specialized) only if explicitly requested:
   - Mentions "bookmark" → Add Bookmark
   - Mentions "reply" or "comment" → Add Reply, Comment
   - Mentions "dependencies" or "blocked by" → Add DependsOn or DependedOnBy
   - Mentions "links" or "related" → Add RefersTo, ReferredToBy
   - Requests custom styling → Add /CLASS: or /STYLE: modifiers

4. Add from Tier 4 (Advanced) only for specialist needs:
   - Mentions encryption/keys → Add KeyOwner, KeyRequestors
   - Needs custom interface → Add row controls
   - Explicitly wants absolute dates → Use Created instead of CreatedRelative

5. Field rendering defaults:
   - ID and Subject: Always as clickable links (Tier 1 pattern)
   - Dates: Prefer relative (CreatedRelative) over absolute (Created) unless user wants specific dates
   - Owner: Use OwnerName not raw Owner (more readable)
   - Queue: Use QueueName not raw Queue (more readable)
   - Watchers: Use .Name or .EmailAddress subfields, not bare Requestor
   - Status: Use plain Status unless dependencies matter (then ExtendedStatus)

6. Modifier defaults:
   - /TITLE: Always use for clarity
   - /CLASS:, /STYLE:, /ALIGN: Only when user requests styling
   - /SPAN: Rarely needed
   - /ATTRIBUTE: Only when sort field differs from display
```

### Anti-Patterns (Avoid Unless Specifically Requested)

These are technically possible but should be avoided unless the user explicitly asks:

**❌ Don't**: Add too many columns (reduces readability)
```
id, Subject, Status, Queue, Owner, Priority, Created, Due, Resolved, TimeWorked, Requestor, Cc  # Too many!
```
**✅ Do**: Keep to 5-7 most relevant columns
```
'__id__/TITLE:#', '__Subject__/TITLE:Subject', QueueName, Status, OwnerName
```

**❌ Don't**: Add styling unless requested
```
'__Status__/CLASS:badge bg-primary/STYLE:font-weight:bold'  # Overly styled
```
**✅ Do**: Use plain display by default
```
Status  # Simple and clean
```

**❌ Don't**: Make everything a link
```
'<a href="...">__Status__</a>', '<a href="...">__Queue__</a>'  # Unnecessary links
```
**✅ Do**: Only link ID and Subject by default
```
'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#',
'<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject'
```

**❌ Don't**: Use raw role fields without subfields
```
Requestor, Owner, Cc  # May not display as expected
```
**✅ Do**: Use formatted variants or specify subfield
```
OwnerName, 'Requestor.Name', 'Requestor.EmailAddress'
```

**❌ Don't**: Add action buttons unless user wants them
```
Reply, Comment, Bookmark, Timer  # Clutters display
```
**✅ Do**: Include only when user mentions actions
```
# Only add if user says "show reply button" or similar
```

### Start Simple

Begin with minimal columns, add complexity as needed:

**Step 1**: Basic display
```
id, Subject, Status
```

**Step 2**: Add headers
```
'__id__/TITLE:#', '__Subject__/TITLE:Subject', Status
```

**Step 3**: Make links clickable
```
'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#',
'<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject',
Status
```

**Step 4**: Add more fields
```
'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#',
'<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject',
QueueName,
Status,
OwnerName,
Priority
```

### Quote When Needed

- **Always quote** when using modifiers: `'__id__/TITLE:#'`
- **Always quote** HTML content: `'<a href="...">text</a>'`
- **Optional** for simple field names: `Status` vs `'__Status__'`

### Use Standard Field Names

In most cases, use the default name for each field so the user can easily understand where that field comes from on a ticket. Providing custom titles makes it difficult to trace a value back to the ticket.

## Troubleshooting

### Common Errors

#### Error: Field not found or column empty

**Cause**: Field name misspelled or doesn't exist for this object type.

**Solution**:
- Check field name spelling (case-sensitive)
- Verify field exists for tickets (some fields are transaction-specific)
- Check ColumnMap in `/Elements/RT__Ticket/ColumnMap`

#### Error: Modifiers not applied

**Cause**: Forgot to quote the field when using modifiers.

**Wrong**: `__id__/TITLE:#`
**Correct**: `'__id__/TITLE:#'`

#### Error: HTML displays as text

**Cause**: Returned string instead of HTML reference in custom ColumnMap.

**Solution**: In custom ColumnMap value subs, return `\("<html>")` not `"<html>"`.

#### Error: Custom field not displaying

**Cause**:
- Custom field name misspelled
- Custom field not applied to queue
- Missing braces around field name with spaces

**Solutions**:
```
# Correct syntax
'__CustomField.{Field Name}__'
'__CF.{Department}__'

# Verify field applied to queue in Admin → Custom Fields
```

#### Error: Custom role displays "Unable to load"

**Cause**:
- Role name misspelled
- Role not applied to queue
- Missing required subfield

**Solutions**:
```
# Use numeric ID
'__CustomRole.{5}.Name__'

# Or quote entire expression with role name
'__CustomRole.{Engineer}.EmailAddress__'

# Subfield is required
'__CustomRole.{5}.Name__'  # Good
'__CustomRole.{5}__'        # Bad - missing subfield
```

### Debugging Format Strings

#### Test incrementally

Build complex formats step by step:

1. Start with: `id, Subject`
2. Add headers: `'__id__/TITLE:#', '__Subject__/TITLE:Subject'`
3. Add more fields one at a time
4. Test after each addition

#### Use RT's Format Builder

The Query Builder's Display Columns section provides:
- Dropdown of available fields
- Preview of format string
- Drag-and-drop column ordering
- Validation before applying

#### Check Mason cache

After modifying ColumnMap callbacks:
```bash
make clean-mason-cache
```

#### Review RT logs

Look for errors in `var/log/rt.log`:
- ColumnMap loading failures
- Custom field lookup errors
- Role loading problems

### Linking to External Systems

Format strings can include links to external web-based systems for integration with other tools.

**Use case**: Link ticket fields to external systems for additional information lookup.

**Example**: Serial number lookup in inventory system
```
'<a href="https://inventory.example.com/lookup?serial=__CustomField.{Serial Number}__">__CustomField.{Serial Number}__</a>/TITLE:Serial #'
```

**Example**: Customer ID lookup in CRM system
```
'<a href="https://crm.example.com/customer/__CustomField.{Customer ID}__">__CustomField.{Customer ID}__</a>/TITLE:Customer'
```

**Example**: Order number linking to e-commerce platform
```
'<a href="https://shop.example.com/orders/__CustomField.{Order Number}__">__CustomField.{Order Number}__</a>/TITLE:Order'
```

#### Security: RestrictLinkDomains Configuration

By default, RT restricts links in Format strings to the RT instance itself for security. To enable links to external domains, you must configure `RestrictLinkDomains` in `RT_SiteConfig.pm`.

**Configuration option**: `RestrictLinkDomains`

**Documentation**: https://docs.bestpractical.com/rt/6.0.2/RT_Config.html#RestrictLinkDomains

**Purpose**: Controls which domains are allowed in Format string links to prevent malicious URLs.

**Default behavior**: Links are restricted to the RT instance domain only.

**To allow specific external domains**:
```perl
# In etc/RT_SiteConfig.pm
Set(@RestrictLinkDomains, qw(
    inventory.example.com
    crm.example.com
    shop.example.com
));
```

**To allow all domains** (not recommended for security):
```perl
# In etc/RT_SiteConfig.pm
Set(@RestrictLinkDomains, undef);
```

**Security considerations**:
- **Whitelist specific domains**: Only allow trusted external systems
- **Avoid wildcards**: Be explicit about allowed domains
- **Review regularly**: Audit external links and remove unused domains
- **User education**: Train users not to click suspicious external links
- **HTTPS preferred**: Use secure connections for external links when possible

**Common patterns**:
```
# Asset tracking system
'<a href="https://assets.company.com/asset/__CustomField.{Asset Tag}__">__CustomField.{Asset Tag}__</a>/TITLE:Asset'

# Bug tracker integration
'<a href="https://bugs.company.com/issue/__CustomField.{Bug ID}__">__CustomField.{Bug ID}__</a>/TITLE:Bug'

# Documentation wiki
'<a href="https://wiki.company.com/kb/__CustomField.{KB Article}__">__CustomField.{KB Article}__</a>/TITLE:KB Article'

# Monitoring system
'<a href="https://monitoring.company.com/host/__CustomField.{Hostname}__">__CustomField.{Hostname}__</a>/TITLE:Host'
```

**Best practices**:
1. **Use HTTPS**: Always prefer secure connections for external links
2. **URL encode values**: Field values are automatically HTML-escaped but complex URLs may need attention
3. **Document dependencies**: Note which external systems are linked in your RT documentation
4. **Handle missing values**: External links will display empty if field value is not set
5. **Test thoroughly**: Verify external links work with various field value formats

**Troubleshooting**:
- **Link blocked**: Check `RestrictLinkDomains` includes the target domain
- **Link displays as text**: Verify domain is in allowed list
- **Security warning**: RT logs attempts to link to restricted domains

## Field Quick Reference Table

| Category | Fields |
|----------|--------|
| **Core** | id, EffectiveId, Type, Subject, Description, Queue, QueueName, Status, ExtendedStatus, UpdateStatus |
| **Priority** | Priority, InitialPriority, FinalPriority, PriorityNumber, InitialPriorityNumber, FinalPriorityNumber |
| **Dates (Absolute)** | Created, Starts, Started, Due, Resolved, Told, LastUpdated |
| **Dates (Relative)** | CreatedRelative, StartsRelative, StartedRelative, DueRelative, ResolvedRelative, ToldRelative, LastUpdatedRelative |
| **Actors** | CreatedBy, LastUpdatedBy |
| **Owner** | Owner, OwnerName, OwnerNameEdit |
| **Time** | TimeWorked, TimeEstimated, TimeLeft, TotalTimeWorked |
| **Watchers** | Requestor, Requestors, Cc, Ccs, AdminCc, AdminCcs (+ all subfields) |
| **Links** | RefersTo, ReferredToBy, DependsOn, DependedOnBy, MemberOf, Members, Parents, Children, HasMember, MergedInto |
| **Custom** | CustomField.{Name}, CF.{Name}, CustomFieldView.{Name}, CustomRole.{ID}.Field |
| **Actions** | Reply, Comment |
| **Special** | Bookmark, Timer, UnreadMessages, SLA |
| **Encryption** | KeyRequestors, KeyOwner, KeyOwnerName |
| **Helpers** | WebPath, WebBaseURL, WebURL, WebHomePath, CurrentUser, CurrentUserName |
| **Row Controls** | CheckBox, RadioButton, _CLASS, _CHECKBOX |
| **Tokens** | NEWLINE, NBSP |

### Modifier Quick Reference

- `/TITLE:text` - Column header
- `/CLASS:name` - CSS class
- `/STYLE:prop:val` - Inline CSS
- `/ALIGN:left|center|right` - Alignment
- `/SPAN:N` - Column span
- `/ATTRIBUTE:field` - Sort/group field
- `/CALENDAR:start|end` - Multi-day calendar span (date fields only)

### Special Tokens

- `NEWLINE` - Multi-row header break
- `NBSP` - Non-breaking space/empty column

## See Also

- **TicketSQL Grammar**: `devel/docs/ticketsql_grammar.md` - Query syntax for finding tickets
- **RT Documentation**: `docs/customizing/search_result_columns.pod` - Adding custom columns
- **RT Config**: `etc/RT_Config.pm.in` - Default format configurations
- **Default Formats**: `etc/initialdata` - Standard saved search formats

# TicketSQL Grammar Reference for AI Systems

## Overview

TicketSQL is Request Tracker's query language for searching tickets. This document provides a comprehensive grammar specification optimized for AI systems to understand and generate valid TicketSQL queries from natural language.

## Query Structure

```
Query := Condition | Query AND Query | Query OR Query | ( Query )
Condition := Field Operator Value
Field := CoreField | CustomField | WatcherField | DateField | LinkField
Operator := EqualityOp | ComparisonOp | StringOp | NullOp
Value := Literal | SpecialValue | RelativeDate | ColumnReference
```

## Core Fields

### Ticket Identification

#### id
- **Type**: Integer
- **Operators**: `=`, `!=`, `<`, `>`, `<=`, `>=`
- **Examples**:
  - `id = 123` - ticket number 123
  - `id > 100` - tickets with id greater than 100
  - `id != 42` - all tickets except 42
- **Natural Language**: "ticket 123", "tickets greater than 100", "tickets above number 500"

### Queue and Lifecycle

#### Queue
- **Type**: String
- **Operators**: `=`, `!=`, `LIKE`, `NOT LIKE`
- **Examples**:
  - `Queue = 'General'` - tickets in General queue
  - `Queue != 'Spam'` - tickets not in Spam queue
  - `Queue LIKE 'Support'` - queues matching "Support" (Support, "IT Support", etc.)
  - `Queue = 'General' OR Queue = 'Support'` - tickets in either queue
- **Natural Language**: "tickets in General queue", "tickets in Support or Sales queues", "tickets in queues like Support"

#### Lifecycle
- **Type**: String (lifecycle name)
- **Operators**: `=`, `!=`
- **Examples**:
  - `Lifecycle = 'default'` - tickets using default lifecycle
  - `Lifecycle = 'support'` - support tickets
  - `Lifecycle != 'Change Management'` - tickets not using the Change Management lifecycle
- **Natural Language**: "tickets with default lifecycle", "approval workflow tickets"
- **Common Values**: default, support, Change Management, incidents, investigations, countermeasures, incident_reports

#### Type
- **Type**: String
- **Operators**: `=`, `!=`
- **Examples**:
  - `Type = 'ticket'` - standard tickets (usually implied, rarely queried)
  - `Type = 'reminder'` - reminder tickets
- **Natural Language**: "reminder tickets", "show reminders"
- **IMPORTANT - Rarely Used**: This field should **only** be used when users specifically ask about "reminders" or "reminder tickets". The Type field is rarely useful for general ticket searches as most tickets are Type='ticket'. Do not use this field for general filtering unless the user explicitly mentions reminders.
### Status

#### Status
- **Type**: String (status name)
- **Operators**: `=`, `!=`
- **Special Values**: `__Active__`, `__Inactive__`
- **Examples**:
  - `Status = 'new'` - new tickets
  - `Status = 'open'` - open tickets
  - `Status = '__Active__'` - all active statuses (new, open, stalled)
  - `Status = '__Inactive__'` - all inactive statuses (resolved, rejected, deleted)
  - `Status != 'deleted'` - all tickets except deleted
  - `Status = 'new' OR Status = 'open'` - new or open tickets
- **Natural Language**: "new tickets", "open tickets", "all active tickets", "resolved tickets", "tickets not deleted"
- **Common Values**: new, open, stalled, resolved, rejected, deleted
- **Note**: Active/inactive sets are defined by the lifecycle

#### SLA
- **Type**: String (SLA name)
- **Operators**: `=`, `!=`, `LIKE`, `NOT LIKE`
- **Examples**:
  - `SLA = '4h'` - tickets with 4-hour SLA
  - `SLA LIKE 'priority'` - SLAs matching "priority"
  - `SLA IS NULL` - tickets without SLA
- **Natural Language**: "tickets with 4h SLA", "tickets without SLA"

### Content and Description

#### Subject
- **Type**: String
- **Operators**: `=`, `!=`, `LIKE`, `NOT LIKE`, `STARTSWITH`, `ENDSWITH`
- **Examples**:
  - `Subject = 'Server Down'` - exact subject match
  - `Subject LIKE 'server'` - subject containing "server"
  - `Subject STARTSWITH 'URGENT'` - subject starting with "URGENT"
  - `Subject IS NULL` - tickets with no subject
- **Natural Language**: "tickets with subject containing 'server'", "urgent tickets", "tickets about database"

#### Description
- **Type**: String (ticket description field)
- **Operators**: `LIKE` only (NOT LIKE is not supported)
- **Examples**:
  - `Description LIKE 'urgent'` - description containing "urgent"
- **Natural Language**: "tickets with description matching 'urgent'"
- **Note**: Description does not support NOT LIKE operator

#### Content
- **Type**: With full-text indexing enabled, searches all indexed fields which includes transaction content, custom fields, and description
- **Operators**: `LIKE`, `NOT LIKE`
- **Examples**:
  - `Content LIKE 'avocado'` - tickets containing "avocado" in a transaction, custom field, or description
  - `Content LIKE '+server +down'` - tickets containing both "server" AND "down" (MySQL boolean mode)
  - `Content LIKE '"server down"'` - exact phrase "server down" (MySQL boolean mode)
  - `Content NOT LIKE 'spam'` - tickets not containing "spam"
- **Natural Language**: "tickets containing 'error message'", "tickets about server down"
- **Note**: Behavior varies by database (MySQL boolean mode vs PostgreSQL tsquery)

#### HistoryContent
- **Type**: Full-text search in transaction history
- **Operators**: `LIKE`, `NOT LIKE`
- **Examples**:
  - `HistoryContent LIKE 'resolved'` - tickets with "resolved" in history
- **Natural Language**: "tickets with history containing 'resolved'"

#### ContentType
- **Type**: MIME content type
- **Operators**: `=`, `!=`, `LIKE`, `NOT LIKE`
- **Examples**:
  - `ContentType = 'text/plain'` - plain text content
  - `ContentType LIKE 'image'` - any image content
- **Natural Language**: "tickets with PDF attachments", "tickets with images"

#### Filename
- **Type**: Attachment filename
- **Operators**: `LIKE`, `NOT LIKE`
- **Examples**:
  - `Filename LIKE 'report.pdf'` - tickets with attachment named "report.pdf"
  - `Filename LIKE '%.xlsx'` - tickets with Excel attachments
- **Natural Language**: "tickets with PDF attachments", "tickets with file named report"

### Priority

#### Priority
- **Type**: Integer (0-100), but accepts string labels
- **Operators**: `=`, `!=`, `<`, `>`, `<=`, `>=`
- **String-to-Number Conversion**: Priority is stored internally as a number, but users can reference it using configured string labels (e.g., "Low", "Medium", "High"). RT automatically converts these strings to their numeric values based on the `%PriorityAsString` configuration.
- **Default String Mappings**:
  - `Low` → 0
  - `Medium` → 50
  - `High` → 100
- **Examples**:
  - `Priority = 'High'` - high priority tickets (converted to Priority = 100)
  - `Priority = 'Medium'` - medium priority tickets (converted to Priority = 50)
  - `Priority = 50` - numeric priority value (also works)
  - `Priority > 80` - priority greater than 80
  - `Priority < 'Medium'` - priority less than Medium (converted to Priority < 50)
- **Natural Language**: "high priority tickets", "medium priority", "priority greater than 50", "low priority tickets"
- **Note**: String mappings can be customized per queue in RT configuration. When translating natural language, prefer using string values ("High", "Medium", "Low") over numeric values for better readability.

#### InitialPriority
- **Type**: Integer (0-100), but accepts string labels
- **Operators**: `=`, `!=`, `<`, `>`, `<=`, `>=`
- **Examples**:
  - `InitialPriority = 'Low'` - tickets that started at low priority (converted to 0)
  - `InitialPriority = 0` - tickets that started at priority 0 (also works)
- **Natural Language**: "tickets that started with high priority", "initially low priority"
- **Note**: Uses the same string-to-number conversion as Priority field

#### FinalPriority
- **Type**: Integer (0-100), but accepts string labels
- **Operators**: `=`, `!=`, `<`, `>`, `<=`, `>=`
- **Examples**:
  - `FinalPriority = 'High'` - tickets with final priority of High (converted to 100)
  - `FinalPriority = 100` - tickets with final priority of 100 (also works)
- **Natural Language**: "tickets with final priority high", "target priority low"
- **Note**: Uses the same string-to-number conversion as Priority field

### Time Tracking

#### TimeWorked
- **Type**: Integer (minutes)
- **Operators**: `=`, `!=`, `<`, `>`, `<=`, `>=`
- **Examples**:
  - `TimeWorked > 120` - tickets with more than 2 hours worked
  - `TimeWorked = 0` - tickets with no time worked
- **Natural Language**: "tickets with more than 2 hours worked", "tickets with no time logged"

#### TimeEstimated
- **Type**: Integer (minutes)
- **Operators**: `=`, `!=`, `<`, `>`, `<=`, `>=`
- **Examples**:
  - `TimeEstimated < 60` - tickets estimated under 1 hour
  - `TimeEstimated IS NULL` - tickets with no estimate
- **Natural Language**: "tickets estimated under 1 hour", "tickets without time estimate"

#### TimeLeft
- **Type**: Integer (minutes)
- **Operators**: `=`, `!=`, `<`, `>`, `<=`, `>=`
- **Examples**:
  - `TimeLeft > 0` - tickets with time remaining
  - `TimeLeft = 0` - tickets with no time left
- **Natural Language**: "tickets with time remaining", "tickets over estimate"

### Users and Actors

#### Owner
- **Type**: User (single-value user field)
- **Operators**: `=`, `!=`, `LIKE`, `NOT LIKE`, `IS`, `IS NOT`
- **Subfields**: Name, EmailAddress, RealName, id, etc.
- **Special Values**: `__CurrentUser__`, `__CurrentUserName__`, Nobody
- **Shorthand Syntax**: Unlike watcher fields, Owner shorthand works with both usernames AND email addresses
  - `Owner = 'alice'` - Works with username (Owner is single-valued)
  - `Owner = 'alice@example.com'` - Works with email address
- **NOTE**: Owner behaves differently from watcher fields (Requestor/Cc/AdminCc). For Owner, shorthand syntax works with usernames. For watcher fields, you must use `.Name` subfield for usernames.
- **Examples**:
  - `Owner = 'root'` - tickets owned by root (username)
  - `Owner = 'alice'` - tickets owned by alice (username works)
  - `Owner = '__CurrentUser__'` - tickets owned by current user
  - `Owner.EmailAddress = 'admin@example.com'` - tickets owned by user with specific email
  - `Owner.Name = 'alice'` - tickets owned by alice (explicit subfield also works)
  - `Owner = 'Nobody'` - unowned tickets
  - `Owner != 'Nobody'` - owned tickets
- **Natural Language**: "my tickets", "tickets owned by root", "unowned tickets", "tickets I own", "tickets owned by alice"

#### Creator
- **Type**: User ID
- **Operators**: `=`, `!=`
- **Examples**:
  - `Creator = 'root'` - tickets created by root
  - `Creator = '__CurrentUser__'` - tickets I created
- **Natural Language**: "tickets I created", "tickets created by alice"

#### LastUpdatedBy
- **Type**: User ID
- **Operators**: `=`, `!=`
- **Examples**:
  - `LastUpdatedBy = 'root'` - tickets last updated by root
- **Natural Language**: "tickets last updated by root"

#### UpdatedBy
- **Type**: User ID (from transactions)
- **Operators**: `=`, `!=`
- **Examples**:
  - `UpdatedBy = 'root'` - tickets with any update by root
- **Natural Language**: "tickets updated by root"

### Watchers and Roles

**IMPORTANT - Watcher Field Shorthand Syntax Rules**:
- Watcher fields (Requestor, Cc, AdminCc, Watcher) have special shorthand syntax requirements
- Shorthand (without subfield) ONLY works with **email addresses**: `Requestor = 'user@example.com'` ✓
- Shorthand does NOT work with usernames: `Requestor = 'alice'` ✗
- For username matching, you MUST use the `.Name` subfield: `Requestor.Name = 'alice'` ✓
- This is different from Owner field, where shorthand works with both usernames and emails

#### Requestor / Requestors
- **Type**: User (watcherfield)
- **Operators**: `=`, `!=`, `LIKE`, `NOT LIKE`, `SHALLOW =`, `SHALLOW !=`, `SHALLOW LIKE`, `SHALLOW NOT LIKE`
- **Subfields**: EmailAddress, Name, RealName, Nickname, Organization, Address1, Address2, City, State, Zip, Country, WorkPhone, HomePhone, MobilePhone, PagerPhone, id
- **Shorthand Syntax**:
  - `Requestor = 'user@example.com'` - Works with email addresses
  - `Requestor.Name = 'jsmith'` - Required for username matching (shorthand does NOT work for usernames)
  - `Requestor LIKE 'John'` - Searches across RealName and other text fields
- **IMPORTANT**: Shorthand syntax (without subfield) only works reliably with email addresses. For username matching, you MUST use the `.Name` subfield explicitly.
- **Examples**:
  - `Requestor.EmailAddress = 'user@example.com'` - tickets requested by specific email
  - `Requestor = 'user@example.com'` - shorthand for email (works)
  - `Requestor.Name = 'jsmith'` - tickets requested by jsmith (correct)
  - `Requestor = 'jsmith'` - does NOT work (incorrect - use .Name subfield)
  - `Requestor.Name LIKE 'john'` - tickets requested by users matching "john"
  - `Requestor.RealName LIKE 'John Smith'` - tickets requested by users with matching real name
  - `Requestor.Name SHALLOW = 'alice'` - tickets where alice is directly requestor (not via group)
  - `Requestor IS NULL` - tickets with no requestor
- **Natural Language**: "tickets I requested", "tickets from john@example.com", "tickets requested by jsmith", "tickets requested by users named John"

#### Cc
- **Type**: User (watcherfield)
- **Operators**: Same as Requestor
- **Subfields**: Same as Requestor (EmailAddress, Name, RealName, etc.)
- **Shorthand Syntax**: Same rules as Requestor - email addresses work, usernames require `.Name` subfield
- **Examples**:
  - `Cc.EmailAddress = 'manager@example.com'` - tickets with manager on Cc
  - `Cc = 'manager@example.com'` - shorthand for email (works)
  - `Cc.Name = 'alice'` - tickets with alice on Cc (correct)
  - `Cc = 'alice'` - does NOT work (incorrect - use .Name subfield)
  - `Cc.Name LIKE 'team'` - tickets with team members on Cc
- **Natural Language**: "tickets where manager is Cc'd", "tickets with team members watching", "tickets where alice is Cc'd"

#### AdminCc
- **Type**: User (watcherfield)
- **Operators**: Same as Requestor
- **Subfields**: Same as Requestor (EmailAddress, Name, RealName, etc.)
- **Shorthand Syntax**: Same rules as Requestor - email addresses work, usernames require `.Name` subfield
- **Examples**:
  - `AdminCc.EmailAddress = 'admin@example.com'` - tickets with admin on AdminCc
  - `AdminCc = 'admin@example.com'` - shorthand for email (works)
  - `AdminCc.Name = 'admin'` - tickets with admin on AdminCc (correct)
  - `AdminCc = 'admin'` - does NOT work (incorrect - use .Name subfield)
  - `AdminCc.Name SHALLOW = 'staff1'` - tickets where staff1 is directly on AdminCc (not via group)
- **Natural Language**: "tickets where admin is AdminCc", "tickets adminned by staff1", "tickets where admin@example.com is AdminCc"

#### Watcher
- **Type**: User (any watcher role - Requestor, Cc, or AdminCc)
- **Operators**: Same as Requestor
- **Subfields**: Same as Requestor (EmailAddress, Name, RealName, etc.)
- **Shorthand Syntax**: Same rules as Requestor - email addresses work, usernames require `.Name` subfield
- **Examples**:
  - `Watcher.EmailAddress = 'user@example.com'` - tickets where user is any type of watcher
  - `Watcher = 'user@example.com'` - shorthand for email (works)
  - `Watcher.Name = 'alice'` - tickets where alice is any type of watcher (correct)
  - `Watcher = 'alice'` - does NOT work (incorrect - use .Name subfield)
- **Natural Language**: "tickets I'm watching", "tickets user@example.com is involved with", "tickets where alice is a watcher"

#### Queue Watchers (QueueCc, QueueAdminCc, QueueWatcher)
- **Type**: User (queue-level watchers)
- **Operators**: Same as Requestor
- **Examples**:
  - `QueueAdminCc.Name = 'queueadmin'` - tickets in queues where queueadmin is AdminCc
- **Natural Language**: "tickets in queues I admin"

#### Custom Roles
- **Type**: User (custom role)
- **Syntax**: `CustomRole.{RoleID}.Field` OR `'CustomRole.{RoleName}.Field'` (quoted)
- **Operators**: Same as Requestor (=, !=, LIKE, NOT LIKE, SHALLOW operators)
- **Subfield REQUIRED**: Must specify a subfield (.EmailAddress, .Name, .id, etc.)
- **Two Syntax Options**:
  1. **By Numeric ID**: `CustomRole.{5}.EmailAddress = 'user@example.com'` (no quotes needed)
  2. **By Role Name**: `'CustomRole.{Engineer}.EmailAddress' = 'user@example.com'` (must quote entire expression)
- **IMPORTANT**:
  - ✅ CORRECT: `CustomRole.{5}.EmailAddress = 'user@example.com'` (numeric ID)
  - ✅ CORRECT: `'CustomRole.{Engineer}.EmailAddress' = 'user@example.com'` (role name, quoted)
  - ❌ WRONG: `CustomRole.{Engineer}.EmailAddress = 'user@example.com'` (role name without quotes)
  - ❌ WRONG: `CustomRole.{5} = 'user@example.com'` (missing subfield)
- **Examples**:
  - `CustomRole.{5}.Name = 'alice'` - by numeric ID
  - `'CustomRole.{Engineer}.Name' = 'alice'` - by role name (quoted)
  - `CustomRole.{7}.EmailAddress LIKE '@example.com'` - by numeric ID
  - `'CustomRole.{Sales}.EmailAddress' LIKE '@example.com'` - by role name (quoted)
  - `CustomRole.{5}.EmailAddress IS NOT NULL` - check if role is filled
- **Natural Language**: "tickets where Engineer is alice", "tickets assigned to Sales department"

### Watcher Groups

#### OwnerGroup
- **Type**: Group name
- **Operators**: `=`
- **Examples**:
  - `OwnerGroup = 'Helpdesk'` - tickets where Helpdesk group is the owner
- **Natural Language**: "tickets owned by Helpdesk group"

#### RequestorGroup
- **Type**: Group name
- **Operators**: `=`
- **Examples**:
  - `RequestorGroup = 'Customers'` - tickets requested by members of Customers group
- **Natural Language**: "tickets from customer group"

#### CCGroup, AdminCCGroup, WatcherGroup
- **Type**: Group name
- **Operators**: `=`
- **Examples**:
  - `AdminCCGroup = 'SysAdmins'` - tickets with SysAdmins group on AdminCc
- **Natural Language**: "tickets watched by SysAdmins group"

#### Custom Role Groups
- **Type**: Group name (searched via .Name subfield)
- **Syntax**: `CustomRole.{RoleID}.Name = 'GroupName'` OR `'CustomRole.{RoleName}.Name' = 'GroupName'` (quoted)
- **Operators**: `=`, `!=`, `LIKE`, `NOT LIKE`
- **Description**: Search for tickets where a specific group is assigned to a custom role. Unlike core roles (which have dedicated `AdminCCGroup`, `RequestorGroup` fields), custom roles search for groups using the `.Name` subfield.
- **Examples**:
  - `CustomRole.{5}.Name = 'Engineering Team'` - by numeric role ID
  - `'CustomRole.{Engineer}.Name' = 'Engineering Team'` - by role name (quoted)
  - `CustomRole.{7}.Name = 'Support'` - by numeric role ID
  - `'CustomRole.{Sales}.Name' = 'Support'` - by role name (quoted)
  - `CustomRole.{5}.Name LIKE 'Engineering'` - tickets with groups/users matching 'Engineering'
- **Natural Language**: "tickets where Engineering Team is the engineer", "tickets with Support group in custom role"
- **Important Note**: The `.Name` search will match BOTH users and groups with the same name. If you have a user named 'Helpdesk' and a group named 'Helpdesk', searching `CustomRole.{5}.Name = 'Helpdesk'` will return tickets with either assigned to the custom role. To search only for group members, use the recursive search feature (default behavior) which will find tickets where members of the group are in the role.
### Dates

All date fields support:
- **Operators**: `=`, `!=`, `<`, `>`, `<=`, `>=`, `IS`, `IS NOT`
- **Absolute dates**: `'2023-11-29'`, `'2023-11-29 16:00:00'`
- **Relative dates**: `'today'`, `'yesterday'`, `'tomorrow'`, `'last week'`, `'next month'`, `'last Sunday'`, `'beginning of last month'`, `'1 week ago'`, `'2 days ago'`

#### Created
- **Type**: DateTime
- **Examples**:
  - `Created > '2023-01-01'` - tickets created after Jan 1, 2023
  - `Created = 'today'` - tickets created today
  - `Created > 'last Sunday'` - tickets created since last Sunday
  - `Created > '2023-11-01' AND Created < '2023-12-01'` - tickets created in November
- **Natural Language**: "tickets created today", "tickets from last week", "tickets created in November"

#### LastUpdated
- **Type**: DateTime
- **Examples**:
  - `LastUpdated > '1 week ago'` - tickets updated in the last week
  - `LastUpdated < 'yesterday'` - tickets not updated since yesterday
- **Natural Language**: "tickets updated recently", "stale tickets", "tickets updated this week"

#### Resolved
- **Type**: DateTime
- **Examples**:
  - `Resolved > '2023-01-01'` - tickets resolved after Jan 1
  - `Resolved IS NOT NULL` - tickets that have been resolved
  - `Resolved IS NULL` - tickets never resolved
- **Natural Language**: "tickets resolved this month", "resolved tickets", "unresolved tickets"

#### Starts
- **Type**: DateTime
- **Examples**:
  - `Starts > 'today'` - tickets starting in the future
  - `Starts < 'now'` - tickets that should have started
- **Natural Language**: "tickets starting today", "tickets that should have started"

#### Started
- **Type**: DateTime
- **Examples**:
  - `Started IS NOT NULL` - tickets that have been started
- **Natural Language**: "tickets that have been started", "tickets in progress"

#### Due
- **Type**: DateTime
- **Examples**:
  - `Due < 'tomorrow'` - tickets due before tomorrow
  - `Due > 'today' AND Due < 'next week'` - tickets due this week
  - `Due IS NULL` - tickets with no due date
- **Natural Language**: "tickets due today", "overdue tickets", "tickets due this week"

#### Told (Last Contact)
- **Type**: DateTime (last staff reply to ticket)
- **Displayed as**: "Last Contact" in the web interface
- **Examples**:
  - `Told > '1 week ago'` - tickets where staff recently replied
  - `Told IS NULL` - tickets where staff has never replied
- **Natural Language**: "tickets with recent staff response", "tickets needing staff reply"

#### Updated
- **Type**: DateTime (from transactions)
- **Examples**:
  - `Updated = '2023-11-29'` - tickets with updates on specific date
- **Natural Language**: "tickets updated on Nov 29"

#### TransactionDate
- **Type**: DateTime
- **Examples**:
  - `TransactionDate > '2023-01-01'` - tickets with transactions after Jan 1
- **Natural Language**: "tickets with recent activity"

### Date Comparisons with Column References

You can compare date fields to each other without quoting:

```ticketsql
LastUpdated > Resolved
Created > Due
LastUpdated > Created
```

**Examples**:
- `LastUpdated > Resolved` - tickets updated after being resolved
- `Created > Due` - tickets created after their due date

### Links and Relationships

**IMPORTANT - Link Field Limitations**:
- Link fields do NOT support subfield syntax for querying properties of linked tickets
- ❌ INVALID: `DependsOn.Status = 'resolved'` (cannot query status of the dependency)
- ❌ INVALID: `MemberOf.Subject LIKE 'Parent'` (cannot query subject of parent)
- ✅ VALID: `DependsOn IS NOT NULL AND Status = 'resolved'` (query current ticket's status)
- ✅ VALID: `MemberOf = 123` (query link existence by ticket ID)
- You can only query whether a link exists and the ID of the linked ticket
- To query properties of linked tickets, you must query the current ticket's properties

#### MemberOf
- **Type**: Ticket ID (Parent)
- **Operators**: `=`, `!=`, `IS`, `IS NOT`
- **Examples**:
  - `MemberOf = 123` - tickets that are children of ticket 123
  - `MemberOf IS NULL` - tickets with no parent
  - `MemberOf IS NOT NULL` - tickets that have a parent
  - `MemberOf IS NOT NULL AND Status = 'new'` - new tickets that are children (query child's status, not parent's)
- **Natural Language**: "child tickets of 123", "tickets under parent 123", "subtasks", "tickets with parents"

#### HasMember
- **Type**: Ticket ID (Child)
- **Operators**: `=`, `!=`, `IS`, `IS NOT`
- **Examples**:
  - `HasMember = 456` - tickets that have ticket 456 as a child
  - `HasMember IS NOT NULL` - tickets with children
  - `HasMember IS NULL` - tickets with no children
  - `HasMember IS NOT NULL AND Status = 'resolved'` - resolved tickets with children (query parent's status, not children's)
- **Natural Language**: "parent tickets", "tickets with subtasks", "tickets with children"

#### DependsOn
- **Type**: Ticket ID
- **Operators**: `=`, `!=`, `IS`, `IS NOT`
- **Examples**:
  - `DependsOn = 123` - tickets that depend on ticket 123
  - `DependsOn IS NULL` - tickets with no dependencies
  - `DependsOn IS NOT NULL` - tickets that have dependencies
  - `DependsOn IS NOT NULL AND Status = 'new'` - new tickets waiting on dependencies (query blocked ticket's status, not blocker's)
- **Natural Language**: "tickets depending on 123", "tickets blocked by 123", "tickets with dependencies", "blocked tickets"

#### DependedOnBy / DependentOn
- **Type**: Ticket ID
- **Operators**: `=`, `!=`, `IS`, `IS NOT`
- **Examples**:
  - `DependedOnBy = 456` - tickets that ticket 456 depends on (blockers)
  - `DependedOnBy IS NULL` - tickets not blocking anything
  - `DependedOnBy IS NOT NULL` - tickets that are blocking others
  - `DependedOnBy IS NOT NULL AND Status = 'resolved'` - resolved tickets that were blocking others (query blocker's status, not blocked ticket's)
- **Natural Language**: "tickets blocking 456", "tickets that 456 needs", "blocking tickets", "tickets being waited on"

#### RefersTo
- **Type**: Ticket ID or URI
- **Operators**: `=`, `!=`, `IS`, `IS NOT`, `LIKE`, `NOT LIKE`
- **Examples**:
  - `RefersTo = 123` - tickets that refer to ticket 123
  - `RefersTo IS NULL` - tickets not referring to anything
  - `RefersTo IS NOT NULL` - tickets with references
  - `RefersTo LIKE 'https://example.com'` - tickets linking to external URL
- **Natural Language**: "tickets referring to 123", "tickets linking to documentation", "tickets with references"

#### ReferredToBy
- **Type**: Ticket ID or URI
- **Operators**: `=`, `!=`, `IS`, `IS NOT`
- **Examples**:
  - `ReferredToBy = 456` - tickets referred to by ticket 456
  - `ReferredToBy IS NULL` - tickets not referred to by anything
  - `ReferredToBy IS NOT NULL` - tickets that are referenced
- **Natural Language**: "tickets referenced by 456", "tickets being referred to"

#### LinkedTo
- **Type**: Ticket ID (any link type)
- **Operators**: `=`, `!=`, `IS`, `IS NOT`
- **Examples**:
  - `LinkedTo = 123` - tickets with any type of link to ticket 123
  - `LinkedTo IS NOT NULL` - tickets with any links
  - `LinkedTo IS NULL` - tickets with no links
- **Natural Language**: "tickets linked to 123", "tickets with relationships"

#### LinkedFrom
- **Type**: Ticket ID (any link type)
- **Operators**: `=`, `!=`, `IS`, `IS NOT`
- **Examples**:
  - `LinkedFrom = 456` - tickets with any type of link from ticket 456
  - `LinkedFrom IS NOT NULL` - tickets linked from somewhere
- **Natural Language**: "tickets linked from 456", "tickets with incoming links"

### Custom Fields

Custom fields use the syntax `CF.{FieldName}` or `CF.FieldName` (without braces if no spaces).

#### Text/Freeform Custom Fields
- **Operators**: `=`, `!=`, `LIKE`, `NOT LIKE`, `<`, `>`
- **Examples**:
  - `CF.{Department} = 'Engineering'` - exact match
  - `CF.{Department} LIKE 'Eng'` - partial match
  - `'CF.{Custom Field}' = 'value'` - quoted when field name has spaces
  - `CF.Department != 'Sales'` - not equal
- **Natural Language**: "tickets in Engineering department", "tickets with department matching Eng"

#### Select/Dropdown Custom Fields
- **Operators**: `=`, `!=`
- **Special Values**: `NULL` for "(no value)"
- **Examples**:
  - `CF.{Priority Level} = 'High'` - select value "High"
  - `CF.{Category} = 'NULL'` - no value selected
  - `'CF.{Transport Type}' = 'Car'` - select value "Car"
  - `'CF.{Transport Type}' IS NULL` - no value set
  - `'CF.{Transport Type}' IS NOT NULL` - any value set
- **Natural Language**: "tickets with high priority level", "tickets without category"

#### Date/DateTime Custom Fields
- **Operators**: `=`, `<`, `>`, `<=`, `>=`
- **Supports**: Absolute and relative dates
- **Examples**:
  - `CF.{Due Date} < 'tomorrow'` - custom due date before tomorrow
  - `CF.{Start Date} > '2023-01-01'` - custom start after Jan 1
  - `'CF.{Beta Date}' > 'last Sunday'` - relative date comparison
- **Natural Language**: "tickets with beta date after last Sunday"

#### Numeric Custom Fields
- **Operators**: `=`, `!=`, `<`, `>`, `<=`, `>=`
- **Examples**:
  - `CF.{Budget} > 10000` - budget over 10000
  - `CF.{Count} = 5` - exact count
- **Natural Language**: "tickets with budget over 10000"

#### Multiple Value Custom Fields
- **Operators**: `=`, `!=`, `LIKE`
- **Examples**:
  - `CF.{Tags} LIKE 'urgent'` - tickets with "urgent" tag (among possibly others)
  - `CF.{Categories} = 'Bug'` - tickets with "Bug" category
- **Natural Language**: "tickets tagged urgent", "bug tickets"

#### Custom Field Behavioral Notes

**IMPORTANT - Understanding Custom Field Query Behavior**:

1. **Inequality operators include NULL values**:
   - ❌ `CF.{Department} != 'Engineering'` matches tickets WITH NO Department set
   - ✅ `CF.{Department} != 'Engineering' AND CF.{Department} IS NOT NULL` excludes NULL values
   - **Why**: Tickets without a CF value are treated as "not equal" to any specific value
   - **Best practice**: Always add `AND CF.{Field} IS NOT NULL` when using `!=` if you want to exclude empty values

2. **Freeform text fields don't support numeric comparison**:
   - FreeformSingle and FreeformMultiple store values as text, not numbers
   - ❌ `CF.{SLA Days} > 5` performs lexical comparison ("10" < "5" alphabetically)
   - ✅ `CF.{SLA Days} = '5'` works for equality
   - **Solution**: Use specialized custom field types (e.g., Integer) for numeric comparisons

3. **Case insensitivity**:
   - `CF.{Department} = 'engineering'` matches 'Engineering', 'ENGINEERING', 'engineering'
   - Consistent with other TicketSQL field matching

4. **Multiple syntax variations**:
   - `CF.{Department}` - with braces (required for spaces)
   - `CF.Department` - without braces (no spaces in name)
   - `'CF.{Department}'` - quoted syntax (for special characters)

#### Custom Field Column References
You can compare custom fields to other columns:

```ticketsql
Due < CF.{Beta Date}
CF.Foo = CF.Bar
CF.{Custom Start} < Created
```

**Examples**:
- `Due < CF.{Beta Date}` - tickets due before beta date
- `CF.Foo = CF.Bar` - tickets where two CFs have same value
- `CF.Foo = CF.Bar.Content` - explicit content comparison
- `CF.IP = CF.IPRange.LargeContent` - compare using LargeContent

### Queue Custom Fields

Queue custom fields use the syntax `QueueCF.{FieldName}`.

**Examples**:
- `QueueCF.{RTIR Constituency} = 'Team2'` - tickets in queues where constituency is Team2
- `QueueCF.{Department} LIKE 'Engineering'` - tickets in queues with Engineering department

### Transaction Custom Fields

Transaction custom fields use the syntax `TxnCF.{FieldName}` or `TransactionCF.{FieldName}`.

**Examples**:
- `TxnCF.{Response Type} = 'Email'` - tickets with email response transactions
- `TransactionCF.{Rating} > 3` - tickets with highly-rated transactions

### Full-Text Custom Field Content

With full-text indexing enabled, searches for "Content" include custom field values automatically. For cases where a user specifically wants to search for values in custom fields and not other fields, use `CustomFieldContent`.

**Examples**:
- `CustomFieldContent LIKE 'server'` - tickets with "server" in any CF
- `Content LIKE 'error' OR CustomFieldContent LIKE 'error'` - search both content and CFs
- **Natural Language**: "tickets where a custom field has the value avocado"

### Special Ticket Attributes

#### HasAttribute
- **Type**: Attribute name
- **Operators**: `=`, `!=`
- **Examples**:
  - `HasAttribute = 'SLA'` - tickets with SLA attribute set
- **Natural Language**: "tickets with SLA set"

#### HasNoAttribute
- **Type**: Attribute name
- **Operators**: `=`, `!=`
- **Examples**:
  - `HasNoAttribute = 'Bookmark'` - tickets not bookmarked
- **Natural Language**: "tickets not bookmarked"

#### HasUnreadMessages
- **Type**: Boolean (1 for true, 0 for false)
- **Examples**:
  - `HasUnreadMessages = 1` - tickets with unread messages
- **Natural Language**: "tickets with unread messages"

#### HasNoUnreadMessages
- **Type**: Boolean (1 for true, 0 for false)
- **Examples**:
  - `HasNoUnreadMessages = 1` - tickets without unread messages
- **Natural Language**: "tickets I've read"

## Operators

### Equality Operators
- `=` - equal to, is
- `!=` - not equal to, isn't

### Comparison Operators
- `<` - less than, before
- `>` - greater than, after
- `<=` - less than or equal to
- `>=` - greater than or equal to

### String Matching Operators
- `LIKE` - matches, contains (partial match)
- `NOT LIKE` - doesn't match, doesn't contain
- `STARTSWITH` - starts with
- `NOT STARTSWITH` - doesn't start with
- `ENDSWITH` - ends with
- `NOT ENDSWITH` - doesn't end with

### NULL Operators
- `IS` - is (for NULL comparisons)
- `IS NOT` - is not (for NULL comparisons)
- `IS NULL` - has no value
- `IS NOT NULL` - has a value

### Shallow Operators (Watcher Fields Only)
- `SHALLOW =` - is (direct membership only, not through groups)
- `SHALLOW !=` - isn't (direct membership only)
- `SHALLOW LIKE` - matches (direct membership only)
- `SHALLOW NOT LIKE` - doesn't match (direct membership only)

**When to use SHALLOW**: Use shallow operators when you want to find tickets where a user is directly assigned to a role, not indirectly through group membership.

## Special Values

### User Placeholders
- `__CurrentUser__` - The ID of the currently logged-in user
- `__CurrentUserName__` - The username of the currently logged-in user
- `__SelectedUser__` - Dynamic user selection (in dashboards)
- `Nobody` - Special value for Owner field (unowned tickets)

### Status Placeholders
- `__Active__` - All active statuses for the ticket's lifecycle (e.g., new, open, stalled)
- `__Inactive__` - All inactive statuses for the ticket's lifecycle (e.g., resolved, rejected, deleted)

### Bookmark Placeholder
- `__Bookmarked__` - All tickets bookmarked by the current user

### NULL Value
- `NULL` - Special value for empty/unset fields (in select dropdowns)

## Logical Operators

### AND
Combines conditions where both must be true:
```ticketsql
Queue = 'General' AND Status = 'open'
```

### OR
Combines conditions where at least one must be true:
```ticketsql
Status = 'new' OR Status = 'open'
```

**Internal Note**: RT internally optimizes OR clauses with the same field for performance. However, `IN` syntax is NOT valid TicketSQL - always use `OR` clauses:
- Write: `Status = 'new' OR Status = 'open'` (correct)
- Do NOT write: `Status IN ('new', 'open')` (invalid syntax)

### Parentheses for Grouping
Use parentheses to control evaluation order:
```ticketsql
(Queue = 'General' OR Queue = 'Support') AND Status = 'open'
(Status = 'new' OR Status = 'open') AND Priority > 50
```

### NOT (via !=)
TicketSQL uses `!=` rather than explicit NOT:
```ticketsql
Status != 'deleted'
Queue != 'Spam'
```

## Common Query Patterns

### My Tickets
```ticketsql
Owner = '__CurrentUser__' AND Status = '__Active__'
```
Natural language: "my open tickets", "tickets I own", "my active tickets"

### Unowned Tickets
```ticketsql
Owner = 'Nobody' AND Status = '__Active__'
```
Natural language: "unowned tickets", "tickets without owner", "available tickets"

### New Tickets in Queue
```ticketsql
Queue = 'Support' AND Status = 'new'
```
Natural language: "new Support tickets", "new tickets in Support queue"

### Tickets I Requested
```ticketsql
Requestor.EmailAddress = '__CurrentUser__'
```
Natural language: "tickets I requested", "my requests"

### Overdue Tickets
```ticketsql
Due < 'today' AND Status = '__Active__'
```
Natural language: "overdue tickets", "tickets past due", "late tickets"

### Recently Updated Tickets
```ticketsql
LastUpdated > '1 week ago'
```
Natural language: "tickets updated this week", "recently active tickets"

### High Priority Active Tickets
```ticketsql
Priority > 80 AND Status = '__Active__'
```
Natural language: "high priority open tickets", "urgent active tickets"

### Tickets in Multiple Queues
```ticketsql
Queue = 'Support' OR Queue = 'General'
```
Natural language: "tickets in Support or General", "Support and General tickets"

### Tickets Without Custom Field Value
```ticketsql
'CF.{Category}' IS NULL
```
Natural language: "tickets without category", "uncategorized tickets"

### Tickets Created and Resolved in Date Range
```ticketsql
Created > '2023-11-01' AND Created < '2023-12-01' AND Resolved > '2023-11-01' AND Resolved < '2023-12-01'
```
Natural language: "tickets created and resolved in November"

### Tickets with Attachments
```ticketsql
Filename IS NOT NULL
```
Natural language: "tickets with attachments", "tickets with files"

### Tickets Updated After Resolution
```ticketsql
LastUpdated > Resolved
```
Natural language: "tickets updated after being resolved", "reopened tickets"

### Bookmarked Active Tickets
```ticketsql
id = '__Bookmarked__' AND Status = '__Active__'
```
Natural language: "my bookmarked open tickets"

### Tickets Where Requestor is Also Owner
```ticketsql
Requestor.id = Owner
```
Natural language: "tickets where requestor owns ticket", "self-assigned tickets"

### Tickets With Dependencies
```ticketsql
DependsOn IS NOT NULL
```
Natural language: "tickets with dependencies" or "blocked tickets"

## Full-Text Search Specifics

### MySQL/MariaDB Boolean Mode

When using MySQL/MariaDB with full-text indexing:

- `Content LIKE 'word1 word2'` - matches either word
- `Content LIKE '+word1 +word2'` - matches both words (must contain both)
- `Content LIKE '"exact phrase"'` - matches exact phrase
- `Content LIKE '+required -excluded'` - must contain "required", must not contain "excluded"

### PostgreSQL Full-Text

When using PostgreSQL with full-text indexing:
- Uses tsquery syntax
- Automatically handles word stemming
- Case-insensitive by default

### Without Indexing

When full-text search is enabled but not indexed:
- Slower performance
- Simple LIKE matching on content
- Custom field content not supported

## Advanced Features

### Searching Custom Role Watchers with Subfields
```ticketsql
CustomRole.{5}.EmailAddress LIKE '@engineering.com'
# OR
'CustomRole.{Engineer}.EmailAddress' LIKE '@engineering.com'
```

### Comparing Two Custom Fields
```ticketsql
CF.{Start Date} < CF.{End Date}
```

### Multiple Custom Field Criteria
```ticketsql
CF.{Category} = 'Bug' AND CF.{Severity} = 'Critical' AND CF.{Version} LIKE '5.0'
```

### Queue and Custom Field Combined
```ticketsql
Queue = 'Support' AND 'CF.{Priority Level}' = 'High'
```

### Date Range with NULL Check
```ticketsql
Resolved > '2023-01-01' AND Resolved < '2023-12-31' AND Resolved IS NOT NULL
```

### Shallow Group Membership Search
```ticketsql
AdminCc.Name SHALLOW = 'alice'
```
Finds tickets where alice is directly on AdminCc, not through a group.

### Link Type Filtering
In display formats, you can filter link types:
```
__DependsOn.{Asset}__ - show only asset links
__DependsOn.{Ticket}__ - show only ticket links
```

## RT Concepts for AI Understanding

### Lifecycles
Lifecycles define the statuses available for tickets. Common lifecycles:
- **default**: new → open → stalled → resolved/rejected/deleted
- **approvals**: pending → approved/denied
- **incidents**: new → open → resolved
- Different queues can use different lifecycles

### Active vs Inactive Statuses
- **Active**: Tickets still being worked on (new, open, stalled)
- **Inactive**: Completed tickets (resolved, rejected, deleted)
- The specific statuses in each category are defined by the lifecycle

### Roles and Watchers
- **Requestor**: Person who requested/opened the ticket
- **Owner**: Person responsible for working on the ticket
- **Cc**: People who should receive copies of correspondence
- **AdminCc**: Administrative contacts, internal team members
- **Custom Roles**: Site-defined roles like Department, Manager, etc.

### Groups on Roles
Groups can be assigned to roles (except Owner). When searching:
- Default search is "deep" - includes users via group membership
- SHALLOW search - only direct role assignments, not via groups

### Queue Watchers
- Watchers defined at the queue level
- Apply to all tickets in that queue
- QueueCc, QueueAdminCc search these

### Time Units
- All time values are stored in minutes
- Can search using minutes or hours
- Display formats convert appropriately

### Date Storage
- All dates are stored with time (YYYY-MM-DD HH:MM:SS)
- When searching by date only, defaults to 00:00:00 of that day
- Timezone support varies by user settings

## Syntax Notes for AI Generation

### Quoting Rules
- **Queue names**: Usually quoted: `Queue = 'General'`
- **Status values**: Usually quoted: `Status = 'open'`
- **Usernames**: Usually quoted: `Owner = 'root'`
- **Custom field names**: Quoted when containing spaces: `'CF.{Custom Field}'`
- **Custom field names without spaces**: Can be unquoted: `CF.Department`
- **Special values**: Not quoted: `__Active__`, `__CurrentUser__`, `NULL`
- **Column references**: Not quoted: `Due`, `Resolved`, `CF.{Start Date}`
- **Dates**: Always quoted: `'2023-11-29'`, `'today'`, `'last week'`

### Case Sensitivity
- **Operators**: Case-insensitive (`AND`, `and`, `And` all work)
- **Field names**: Case-insensitive (`status`, `Status`, `STATUS` all work)
- **Values**: Usually case-sensitive for exact matches
- **LIKE operator**: Case-insensitive by default (database-dependent)

### Common Mistakes to Avoid
1. Don't quote column references: `Due < Resolved` not `Due < 'Resolved'`
2. Don't forget quotes on dates: `Created > '2023-01-01'` not `Created > 2023-01-01`
3. Use `IS NULL` not `= NULL`: `Owner IS NULL` not `Owner = NULL`
4. Use `!=` not `NOT`: `Status != 'deleted'` not `NOT Status = 'deleted'`
5. Remember `__Active__` not `'Active'`: `Status = '__Active__'` is a special value
6. Shallow searches only work on watcher fields
7. Time values are in minutes: `TimeWorked > 120` is 2 hours

## Natural Language to TicketSQL Mappings

### Common Phrases

| Natural Language | TicketSQL |
|-----------------|-----------|
| my tickets | `Owner = '__CurrentUser__'` |
| my open tickets | `Owner = '__CurrentUser__' AND Status = '__Active__'` |
| my new tickets | `Owner = '__CurrentUser__' AND Status = 'new'` |
| tickets I requested | `Requestor.EmailAddress = '__CurrentUser__'` or `Requestor = '__CurrentUserName__'` |
| unowned tickets | `Owner = 'Nobody'` |
| tickets without owner | `Owner = 'Nobody'` |
| new tickets | `Status = 'new'` |
| open tickets | `Status = 'open'` |
| active tickets | `Status = '__Active__'` |
| resolved tickets | `Status = 'resolved'` |
| closed tickets | `Status = '__Inactive__'` |
| high priority tickets | `Priority > 80` or `Priority = 'High'` |
| urgent tickets | `Priority > 80` |
| overdue tickets | `Due < 'today' AND Status = '__Active__'` |
| tickets due today | `Due = 'today'` |
| tickets created today | `Created = 'today'` |
| tickets from last week | `Created > 'last Sunday' AND Created < 'this Sunday'` |
| recently updated tickets | `LastUpdated > '1 week ago'` |
| stale tickets | `LastUpdated < '1 month ago' AND Status = '__Active__'` |
| tickets in General | `Queue = 'General'` |
| Support tickets | `Queue = 'Support'` |
| tickets containing "error" | `Content LIKE 'error'` |
| tickets about server | `Subject LIKE 'server' OR Content LIKE 'server'` |
| tickets with attachments | `Filename IS NOT NULL` |
| tickets without category | `'CF.{Category}' IS NULL` |
| bookmarked tickets | `id = '__Bookmarked__'` |

### Time-based Phrases

| Natural Language | TicketSQL |
|-----------------|-----------|
| today | `Created = 'today'` |
| yesterday | `Created = 'yesterday'` |
| this week | `Created > 'last Sunday'` |
| last week | `Created > 'last Sunday - 1 week' AND Created < 'last Sunday'` |
| this month | `Created > 'beginning of this month'` |
| last month | `Created > 'beginning of last month' AND Created < 'beginning of this month'` |
| in the last 7 days | `Created > '7 days ago'` |
| more than a week old | `Created < '1 week ago'` |

### Priority Phrases

| Natural Language | TicketSQL |
|-----------------|-----------|
| critical priority | `Priority > 90` |
| high priority | `Priority > 80` or `Priority = 'High'` |
| medium priority | `Priority = 50` or `Priority = 'Medium'` |
| low priority | `Priority < 30` or `Priority = 'Low'` |
| priority above 50 | `Priority > 50` |

### User Phrases

| Natural Language | TicketSQL |
|-----------------|-----------|
| owned by alice | `Owner = 'alice'` |
| created by bob | `Creator = 'bob'` |
| requested by customer@example.com | `Requestor.EmailAddress = 'customer@example.com'` |
| where alice is Cc'd | `Cc.Name = 'alice'` |
| adminned by team | `AdminCc.Name LIKE 'team'` |

## Example Complex Queries

### Support Queue Active High Priority Tickets
```ticketsql
Queue = 'Support' AND Status = '__Active__' AND Priority > 80
```

### My Overdue Tickets in Multiple Queues
```ticketsql
Owner = '__CurrentUser__' AND Due < 'today' AND (Queue = 'General' OR Queue = 'Support')
```

### Tickets Created Last Month and Still Open
```ticketsql
Created > 'beginning of last month' AND Created < 'beginning of this month' AND Status = '__Active__'
```

### High Priority Bugs Without Owner
```ticketsql
CF.{Category} = 'Bug' AND Priority > 80 AND Owner = 'Nobody'
```

### Tickets with Recent Activity but No Resolution
```ticketsql
LastUpdated > '1 week ago' AND Resolved IS NULL AND Status = '__Active__'
```

### Tickets Depending on My Tickets
```ticketsql
DependsOn.Owner = '__CurrentUser__'
```

### Engineering Tickets Due This Week
```ticketsql
CF.{Department} = 'Engineering' AND Due > 'today' AND Due < 'next Monday'
```

### Resolved Tickets Updated After Resolution
```ticketsql
Status = 'resolved' AND LastUpdated > Resolved
```

### Customer Tickets from Specific Domain
```ticketsql
Requestor.EmailAddress LIKE '@example.com' AND Queue = 'Support'
```

### Tickets with Multiple Criteria
```ticketsql
Queue = 'General' AND Status = '__Active__' AND (Priority > 80 OR CF.{Escalated} = 'Yes') AND Owner != 'Nobody' AND Due IS NOT NULL
```

### Tickets with Time Tracking
```ticketsql
TimeWorked > 480 AND Status = '__Active__'
```
Natural language: "active tickets with more than 8 hours worked"

### Tickets with Custom Role Assigned
```ticketsql
CustomRole.{5}.EmailAddress LIKE '@engineering.com' AND Status = '__Active__'
# OR
'CustomRole.{Engineer}.EmailAddress' LIKE '@engineering.com' AND Status = '__Active__'
```
Natural language: "active tickets with engineering team member as engineer"

### Tickets by Group in Custom Role
```ticketsql
CustomRole.{7}.Name = 'Sales Team' AND Queue = 'Support'
# OR
'CustomRole.{Department}.Name' = 'Sales Team' AND Queue = 'Support'
```
Natural language: "Support tickets where Sales Team is the department"

### Tickets with Description Containing Keyword
```ticketsql
Description LIKE 'urgent' AND Status = 'new'
```
Natural language: "new tickets with urgent in description"

### Unestimated Tickets with Time Worked
```ticketsql
TimeEstimated IS NULL AND TimeWorked > 0 AND Status = '__Active__'
```
Natural language: "active tickets with time worked but no estimate"

---

## Troubleshooting AI Translation Errors

This section helps AI systems avoid common translation mistakes when converting natural language to TicketSQL.

### Common Error #1: Confusing Status Values with Special Values

**Incorrect**:
```ticketsql
Status = 'Active'  # Wrong - 'Active' is not a status
```

**Correct**:
```ticketsql
Status = '__Active__'  # Correct - special value that expands to all active statuses
# OR
Status = 'open'  # Correct - specific status value
```

**Why**: `__Active__` and `__Inactive__` are special values that expand to lifecycle-appropriate status sets. 'Active' and 'Inactive' are not actual status values.

### Common Error #2: Using Bare CustomRole Without Subfield or Forgetting Quotes with Role Name

**Incorrect**:
```ticketsql
CustomRole.{5} = 'alice@example.com'  # Missing subfield
CustomRole.{Engineer}.EmailAddress = 'alice@example.com'  # Role name without quotes
```

**Correct**:
```ticketsql
CustomRole.{5}.EmailAddress = 'alice@example.com'  # Numeric ID with subfield
# OR
'CustomRole.{Engineer}.EmailAddress' = 'alice@example.com'  # Role name (must quote entire expression)
# OR
CustomRole.{5}.Name = 'alice'  # Numeric ID with .Name subfield
```

**Why**: Custom roles REQUIRE a subfield (`.EmailAddress`, `.Name`, `.id`, etc.). You can use either numeric role ID OR role name, but role names require quoting the entire `'CustomRole.{RoleName}.Field'` expression. Core roles like Owner, Requestor, Cc have shorthand syntax, but custom roles do not.

### Common Error #3: Quoting Column References

**Incorrect**:
```ticketsql
Due < 'Resolved'  # Wrong - quotes make it a literal string
LastUpdated > 'Due'  # Wrong - should reference Due column
```

**Correct**:
```ticketsql
Due < Resolved  # Correct - compares Due date to Resolved date
LastUpdated > Due  # Correct - compares LastUpdated to Due
CF.{Start Date} < CF.{End Date}  # Correct - compares two custom fields
```

**Why**: When comparing two fields/columns, don't quote the column name. Quotes indicate literal string values, not column references.

### Common Error #4: Using = NULL Instead of IS NULL

**Incorrect**:
```ticketsql
Owner = NULL  # Wrong - will not work
CF.{Category} = NULL  # Wrong
```

**Correct**:
```ticketsql
Owner IS NULL  # Correct
Owner = 'Nobody'  # Also correct for unowned tickets
CF.{Category} IS NULL  # Correct
```

**Why**: SQL semantics require `IS NULL` and `IS NOT NULL` operators, not `= NULL`.

### Common Error #5: Confusing Nobody with NULL

**Context**: For Owner field only:
- `Owner = 'Nobody'` - tickets explicitly assigned to Nobody (unowned)
- `Owner IS NULL` - tickets with no owner set (should not occur in normal RT usage)

**Typical Use**:
```ticketsql
Owner = 'Nobody' AND Status = '__Active__'  # Unowned active tickets
```

For other roles (Requestor, Cc, AdminCc):
- These roles can be empty (no members)
- Use `IS NULL` or `IS NOT NULL` to check for empty roles

### Common Error #6: Time Values in Hours vs Minutes

**Incorrect**:
```ticketsql
TimeWorked > 8  # Wrong - this is 8 MINUTES, not 8 hours
```

**Correct**:
```ticketsql
TimeWorked > 480  # Correct - 8 hours = 480 minutes
TimeWorked > 120  # Correct - 2 hours = 120 minutes
```

**Why**: RT stores all time values in minutes. When translating "8 hours worked", convert to 480 minutes.

**Conversion**: hours × 60 = minutes
- 1 hour = 60 minutes
- 2 hours = 120 minutes
- 8 hours = 480 minutes
- 40 hours = 2400 minutes

### Common Error #7: Forgetting Date Quotes

**Incorrect**:
```ticketsql
Created > 2023-01-01  # Wrong - interpreted as math expression
Due = today  # Wrong - today is treated as a column name
```

**Correct**:
```ticketsql
Created > '2023-01-01'  # Correct
Due = 'today'  # Correct
LastUpdated > 'last week'  # Correct
```

**Why**: All date values (absolute and relative) must be quoted. The only exception is when referencing a date column for comparison (e.g., `Due < Resolved`).

### Common Error #8: Using Priority as Number When String Mapping is Enabled

**Context**: If RT is configured with PriorityAsString, users can say "high priority" and it maps to numeric values.

**User Says**: "high priority tickets"

**Good Translation**:
```ticketsql
Priority = 'High'  # Best - works with PriorityAsString config
# OR
Priority > 80  # Also works - numeric threshold
```

**Why**: `Priority = 'High'` is more readable and automatically converts based on the configured mappings (High → 100, Medium → 50, Low → 0). However, numeric comparisons (`Priority > 80`) work everywhere.

### Common Error #9: Incorrect Custom Field Syntax

**Incorrect**:
```ticketsql
CustomField.{Category} = 'Bug'  # Wrong - should be CF not CustomField
'CF.Category' = 'Bug'  # Wrong - don't quote the entire field reference
CF.{My Field}' = 'value'  # Wrong - unmatched quotes
```

**Correct**:
```ticketsql
CF.{Category} = 'Bug'  # Correct
'CF.{My Category}' = 'Bug'  # Correct - quote when field name has spaces
CF.Category = 'Bug'  # Correct - no quotes needed when field name has no spaces
```

**Why**: The prefix is `CF` not `CustomField`. Quote the entire `'CF.{Field Name}'` only when the field name contains spaces.

### Common Error #10: Confusing SHALLOW with LIKE

**Incorrect**:
```ticketsql
Status SHALLOW = 'open'  # Wrong - SHALLOW only works on watcher fields
Priority SHALLOW > 50  # Wrong
```

**Correct**:
```ticketsql
Requestor.id SHALLOW = 123  # Correct - SHALLOW on watcher field
AdminCc.Name SHALLOW = 'alice'  # Correct
```

**Why**: The `SHALLOW` operator only applies to watcher/role fields (Owner, Requestor, Cc, AdminCc, CustomRole). It prevents group expansion, finding only direct role members.

### Common Error #11: Misunderstanding Queue Searches

**User Says**: "tickets in queues I admin" or "tickets in my queues"

**Incorrect Interpretation**:
```ticketsql
Queue.AdminCc = '__CurrentUser__'  # Wrong - no Queue.AdminCc
```

**Correct Approach**:
This requires searching for tickets where:
1. The queue has the current user as AdminCc (`QueueAdminCc = '__CurrentUser__'`)
2. Or, if they mean tickets they own: `Owner = '__CurrentUser__'`

```ticketsql
QueueAdminCc = '__CurrentUser__'  # Tickets in queues where I'm an admin
```

**Why**: Queue watchers (QueueCc, QueueAdminCc) are searched with dedicated fields, not as subfields of Queue.

### Common Error #12: Relative Date Syntax Errors

**Incorrect**:
```ticketsql
Created > last week  # Wrong - missing quotes
Due < tomorrow  # Wrong - missing quotes
Created > 'one week ago'  # Wrong - should be '1 week ago' with number
```

**Correct**:
```ticketsql
Created > 'last week'  # Correct
Due < 'tomorrow'  # Correct
Created > '1 week ago'  # Correct - number before unit
LastUpdated > 'last Sunday'  # Correct
```

**Common Relative Dates**:
- `'today'`, `'yesterday'`, `'tomorrow'`
- `'1 week ago'`, `'2 days ago'`, `'3 months ago'`
- `'last Sunday'`, `'next Monday'`
- `'beginning of last month'`, `'beginning of this month'`

### Common Error #13: Searching for Reminders as Regular Tickets

**User Says**: "show tickets" or "all tickets"

**Incorrect**:
```ticketsql
Status = '__Active__'  # Will include reminders (Type = 'reminder')
```

**Better** (if reminders should be excluded):
```ticketsql
Type = 'ticket' AND Status = '__Active__'  # Excludes reminders
```

**Why**: By default, RT searches may include reminders. The `Type` field filters to only tickets (`Type = 'ticket'`) or only reminders (`Type = 'reminder'`).

**Note**: In most cases, you should NOT add `Type = 'ticket'` unless the user specifically wants to exclude reminders, as RT's default behavior typically filters appropriately.

### Common Error #14: Incorrect Link Field Usage

**User Says**: "tickets depending on open tickets"

**Incorrect**:
```ticketsql
DependsOn.Status = 'open'  # Wrong - link fields do NOT support subfield syntax
DependsOn = 'open'  # Wrong - DependsOn is a ticket ID, not a status
```

**Correct**:
```ticketsql
DependsOn IS NOT NULL  # Only way to query - check that dependency exists
# You CANNOT filter by properties of the linked ticket in the same query
```

**Why**: Link fields (DependsOn, RefersTo, etc.) do NOT support subfield syntax. You can only query whether a link exists (`IS NOT NULL`) or query by ticket ID (`DependsOn = 123`). To find tickets depending on open tickets, you would need two queries: first find open tickets, then search for tickets depending on those IDs.

### Translation Decision Tree for AI Systems

When translating natural language to TicketSQL, follow this decision tree:

1. **Identify the field**:
   - Core field? (id, Subject, Status, Queue, Priority, etc.)
   - User field? (Owner, Creator, Requestor, Cc, etc.)
   - Date field? (Created, Due, Resolved, etc.)
   - Custom field? (CF.{Name})
   - Custom role? (CustomRole.{ID}.subfield OR 'CustomRole.{Name}.subfield')
   - Link field? (DependsOn, RefersTo, etc.)

2. **Identify special values**:
   - Current user? → `__CurrentUser__` or `__CurrentUserName__`
   - Active/Inactive? → `__Active__` or `__Inactive__`
   - Bookmarked? → `id = '__Bookmarked__'`
   - Nobody/Unowned? → `Owner = 'Nobody'`

3. **Identify operator**:
   - Equality? → `=` or `!=`
   - Comparison? → `<`, `>`, `<=`, `>=`
   - Pattern matching? → `LIKE`, `NOT LIKE`
   - NULL check? → `IS NULL`, `IS NOT NULL`
   - Multiple values? → `OR` (or use IN syntax)

4. **Handle special cases**:
   - Custom role? → Add required subfield (.EmailAddress, .Name, .id)
   - Time values? → Convert hours to minutes (× 60)
   - Relative dates? → Use quoted keywords ('today', '1 week ago')
   - Column comparisons? → Don't quote the column reference
   - Priority strings? → Use Priority = 'High' (if configured) or Priority > 80

5. **Validate syntax**:
   - Dates quoted? ✓
   - Column references unquoted? ✓
   - IS NULL not = NULL? ✓
   - Custom role has subfield? ✓
   - Time in minutes not hours? ✓
   - SHALLOW only on watchers? ✓

---

## Version Information

This grammar is for RT 6.0.x and newer.

## References

- RT Source: `lib/RT/Tickets.pm` (FIELD_METADATA hash)
- RT Source: `lib/RT/SQL.pm` (query parser)
- RT Source: `share/html/Search/Build.html` (Query Builder UI)
- Documentation: `docs/query_builder.pod`

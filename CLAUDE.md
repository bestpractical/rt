# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is **RT (Request Tracker) 6.0.0**, an enterprise-grade ticket tracking system written in Perl. RT is developed by Best Practical Solutions and is used by organizations worldwide for issue tracking, customer support, and project management.

## Development Commands

### Build and Setup
```bash
# Configure the build (run from repository root)
./configure --with-db-type=SQLite --with-my-user-group

# Check dependencies
make testdeps

# Install missing dependencies
make fixdeps

# Initialize database (first time setup)
make initialize-database

# Start development server
make start-server
# or
./sbin/rt-server
```

### Testing
```bash
# Run all tests
make test

# Run tests in parallel (faster)
make test-parallel

# Run specific test categories
prove t/api/
prove t/web/
prove t/security/
prove t/mail/
prove t/rest2/


# Run a single test file
prove -l t/web/ticket_create.t

# Run with verbose output
prove -lv t/web/ticket_create.t
```

### Database Management
```bash
# Initialize fresh database
make initialize-database

# Upgrade database schema
make upgrade-database

# Drop database (destructive)
make dropdb

# Reset database for testing
make regression-reset-db
```

### Development Tools
```bash
# Start standalone HTTP server for testing
make start-httpd

# Code quality checks
make critic

# Clean Mason template cache
make clean-mason-cache

# Extract translatable strings
make regenerate-catalogs
```

### Environment Variables for Testing

- **`RT_TEST_PARALLEL_NUM=N`** - Set number of parallel test jobs (default: 5)
- **`RT_TEST_DEVEL=1`** - Enable development mode during tests
- **`RT_TEST_PLUGINS="Plugin1 Plugin2"`** - Load specific plugins during tests
- **`RT_TEST_DB_HOST=host`** - Override database host for tests
- **`RT_TEST_DB_SID=sid`** - Override database SID for Oracle tests

```bash
# Example: Fast parallel testing with 8 jobs
RT_TEST_PARALLEL_NUM=8 make test-parallel
```

## Code Architecture

### Core Directory Structure

- **`lib/RT/`** - Core Perl modules and business logic
- **`share/html/`** - Web interface templates (Mason framework)
- **`etc/`** - Configuration files and database schemas
- **`sbin/`** - System administration scripts
- **`bin/`** - User-facing command-line tools
- **`t/`** - Test suite organized by component
- **`docs/`** - Documentation and upgrade guides

### Key Components

**Core Data Models** (`lib/RT/`):
- `Ticket.pm` - Central ticket object with workflow
- `Queue.pm` - Ticket containers with rules and permissions
- `User.pm` / `Group.pm` - User and group management
- `Transaction.pm` - Audit trail and ticket history
- `Attachment.pm` - File attachments and email content
- `Article.pm` - Knowledge base articles
- `Asset.pm` - Asset management (hardware, software, etc.)

**Business Rules Engine**:
- `Scrip.pm` - Event-driven business rules
- `Action/` - Automated actions (email, field updates)
- `Condition/` - Trigger conditions for scrips
- `Lifecycle.pm` - Ticket workflow definitions

**Web Interface** (`share/html/`):
- **Mason Framework**: Template-based web application
- `autohandler` - Main request dispatcher
- `Admin/` - Administrative interface
- `Ticket/` - Ticket management interface
- `Search/` - Query builder and results
- `SelfService/` - Customer portal
- `REST/` - REST API endpoints

**Security Model**:
- `Principal.pm` - Security principals (users/groups)
- `ACE.pm` - Access Control Entries
- `RightsInspector.pm` - Permission debugging
- Role-based access control with granular permissions

### Database Schema

**Core Tables**:
- `Tickets` - Main ticket records
- `Queues` - Ticket containers with workflow rules  
- `Users` / `Groups` / `Principals` - User management and security
- `Transactions` - Complete audit trail
- `Attachments` - File storage and email content
- `Links` - Ticket relationships (depends on, refers to, etc.)
- `CustomFields` - Extensible field definitions
- `Scrips` - Business rules configuration

**Multi-Database Support**: MySQL, MariaDB, PostgreSQL, Oracle, SQLite

### Testing Framework

**Test Organization** (`t/`):
- `api/` - Core functionality and business logic
- `web/` - Web interface and user interactions
- `security/` - Security tests and CVE regression tests
- `mail/` - Email processing and mail gateway
- `rest2/` - REST API testing
- `selenium/` - Browser automation tests

**Test Utilities**:
- `RT::Test` - Test framework with database fixtures
- Temporary test databases created per test run
- Email testing with mock mail systems
- Web testing with simulated HTTP requests

### Configuration System

**Configuration Files**:
- `etc/RT_Config.pm` - Default settings (never edit directly)
- `etc/RT_SiteConfig.pm` - Local customizations
- `etc/RT_SiteConfig.d/` - Modular configuration directory

**Key Configuration Areas**:
- Database connection parameters
- Email settings (SMTP, mail gateway)
- Authentication (LDAP, external auth)
- Security settings (encryption, CSRF protection)
- Customization (themes, custom fields)
- Performance tuning (caching, logging)

## Development Workflow

### Making Changes

1. **Create feature branch**: Use git flow or similar branching strategy
2. **Write tests first**: Add tests in appropriate `t/` subdirectory
3. **Make changes**: Modify code in `lib/RT/` or `share/html/`
4. **Run tests**: `make test` or `prove t/path/to/test.t`
5. **Test in browser**: `make start-server` for manual testing
6. **Check code quality**: `make critic` for Perl::Critic analysis

### Code Conventions

- **Perl Style**: Follow existing code style in the codebase
- **Indentation**: Use 4 spaces for standard Perl code. In Mason templates with HTML, use 2 spaces for indentation due to the many levels of nesting in HTML structures
- **Whitespace**: When writing code, if a new line is blank, it should have no spaces
- **Mason Templates**: Use consistent indentation and component structure
- **Database Changes**: Always provide upgrade scripts in `etc/upgrade/`
- **Documentation**: Update POD documentation for API changes
- **POD Validation**: When making any changes to POD in a file, run `perldoc` and `podchecker` on the file to confirm the POD structure is correct and there are no errors
- **Security**: Never commit sensitive data, use RT::Config for secrets
- **Bootstrap 5**: RT 6 uses Bootstrap 5. When possible, use standard Bootstrap classes and utilities when implementing
- **CSS and JavaScript**: When adding any custom CSS or JavaScript not provided by Bootstrap, both go in separate files, not inline

### Testing Conventions

**Warning Testing**:
RT uses the `Test::Warn` module for testing expected warnings. Never suppress warnings with `local $SIG{__WARN__}` unless absolutely necessary.

```perl
# Import Test::Warn functions
use Test::Warn qw(warning_like warnings_like);

# Test for a single expected warning
warning_like {
    $object->method_that_warns('bad_input');
} qr/Expected warning pattern/, 'Description of expected warning';

# Test for multiple expected warnings
warnings_like {
    $object->method_with_multiple_warnings();
} [ qr/First warning pattern/,
    qr/Second warning pattern/
  ], 'Description of expected warnings';
```

Examples can be found in `t/api/date.t`. This approach:
- Validates that warnings occur as expected
- Documents expected behavior in the test
- Fails if warnings change unexpectedly
- Follows RT's established testing patterns

### Extension Development

**Plugin System**:
- Create plugins in `local/plugins/`
- Extend base classes in `lib/RT/`
- Use RT's callback system for hooks
- Register custom fields, scrips, and templates

**Custom Fields**:
- Define in RT's web interface or initial data
- Support multiple render types (text, select, date, etc.)
- Searchable and reportable

**REST API**:
- REST 2.0 at `/REST/2.0/` (modern JSON API)
- REST 1.0 at `/REST/1.0/` (legacy text-based API)
- Use for external integrations

### Debugging

**Common Issues**:
- Mason template errors: Check `var/log/rt.log`
- Database connection: Verify `RT_SiteConfig.pm` settings
- Permission errors: Use RT's Rights Inspector
- Email problems: Check mail gateway configuration

**Debugging Tools**:
- `RT::Logger` for application logging
- `$RT::Handle->dbh` for database debugging
- Mason's `<%init>` blocks for template debugging
- `RT::Test` for isolated testing

### Production Considerations

**Deployment**:
- Use `make install` for production deployment
- Configure web server (Apache/nginx) with FastCGI or mod_perl
- Set up proper database with adequate resources
- Configure mail gateway for email processing
- Set up cron jobs for maintenance tasks

**Security**:
- Change default password immediately
- Use TLS/SSL for web access
- Configure proper file permissions
- Regular security updates and CVE monitoring
- Enable audit logging for compliance

This RT codebase represents a mature, enterprise-grade application with extensive customization capabilities. The architecture supports high-scale deployments while maintaining flexibility for custom business requirements.

## Release Notes Creation

### Overview

RT release notes document all changes between versions, organized by category and target audience. They follow a specific format for consistency and are distributed as plain text for easy copying and pasting.

### Process

1. **Get Complete Commit List**
   ```bash
   # Get all commits excluding merge commits since last release
   git log rt-6.0.0..HEAD --reverse --oneline --no-merges
   ```

2. **Verify Commit Count**
   ```bash
   # Count total commits to ensure complete coverage
   git log rt-6.0.0..HEAD --reverse --oneline --no-merges | wc -l
   ```

3. **Identify External Contributors**
   ```bash
   # Find commits from contributors outside Best Practical
   git log rt-6.0.0..HEAD --reverse --format="%H %ae" | grep -v bestpractical
   ```
   
   For any external contributors found, add "(thanks username!)" to their
   corresponding entries in the release notes to acknowledge their contributions.

4. **Categorize All Commits**
   Systematically review each commit and assign to appropriate category:
   
   - **General User Features**: User-facing interface improvements, fixes, and enhancements
   - **Documentation**: Updates to documentation
   - **Administration**: Configuration management, admin interface, security settings
   - **Internals**: Code quality, architecture changes, performance improvements
   - **Testing**: Test additions, test framework improvements, test fixes

5. **Create Release Notes Structure**
   ```
   RT X.Y.Z -- YYYY-MM-DD
   ======================

   [Brief description paragraph]

   https://download.bestpractical.com/rt/release/rt-X.Y.Z.tar.gz

   SHA-256 sums

   [TBD]
   [TBD]

   [Categories with bullet points]

   Complete Changelog
   ------------------
   [Git references]
   ```

### Formatting Requirements

- **Plain Text**: No HTML, Markdown, or rich formatting
- **80-Column Wrapping**: All lines wrapped at 80 characters maximum
- **ASCII Characters Only**: Use asterisks (*) for bullets, not Unicode bullets
- **Consistent Indentation**: Continuation lines indented with 2 spaces
- **Clear Categories**: Each section clearly separated with headings

### Quality Assurance

1. **Complete Coverage**: Verify bullet count matches commit count
   ```bash
   grep -c '^\*' release_notes_XYZ.txt
   ```

2. **Meaningful Descriptions**: Each bullet should be user-focused, not just commit message
3. **Proper Categorization**: Commits grouped logically by function and audience
4. **No Duplicates**: Each commit represented exactly once
5. **Plain Text Validation**: No non-ASCII characters that could cause copy/paste issues

### Example Categories

**General User UI** (29 items):
- Interface improvements users will see directly
- Bug fixes affecting user workflows
- New UI features and enhancements

**Administration** (16 items):
- Configuration option changes
- Admin interface improvements
- Security-related changes
- System administration features

**Internals** (13 items):
- Code refactoring and cleanup
- Performance improvements
- Architecture changes
- Developer-focused improvements

**Testing** (16 items):
- New test coverage
- Test framework improvements
- Test fixes and updates

### Historical Reference

- Review previous release notes: https://docs.bestpractical.com/release-notes/rt/index.html
- Focus on previous release notes from RT version 5 and 6
- Follow established tone and style
- Maintain consistency with RT release note conventions

### Commands Reference

```bash
# Get changes since last release
git log rt-6.0.0..HEAD --reverse --no-merges

# Count commits (excluding merges)
git log rt-6.0.0..HEAD --reverse --oneline --no-merges | wc -l

# Find external contributors (non-bestpractical email addresses)
git log rt-6.0.0..HEAD --reverse --format="%H %ae" | grep -v bestpractical

# Count release note entries
grep -c '^\*' release_notes_601.txt

# Verify formatting (no non-ASCII)
file release_notes_601.txt  # Should show "ASCII text"
```
---
name: rt-extensions
description: Use when working with RT extensions/plugins - creating new extensions, installing extensions, understanding callbacks, modifying menus, or any extension-related development tasks
---

# RT Extensions Development

This skill provides comprehensive guidance for working with RT's extension infrastructure, including creating, installing, and developing RT extensions (also called plugins).

## IMPORTANT: Extension Directory Setup

**When this skill is activated, you MUST first ask the user for the extension directory path.**

Extension development happens in a separate directory from the RT installation. All commands (make, perl Makefile.PL, etc.) and file operations must be run from or reference the extension directory.

### Two Scenarios for Path Collection

**Scenario A: User explicitly mentions creating a NEW extension**
- Keywords: "create a new extension", "create an extension", "new extension", "make an extension"
- **Prompt:** "Sure, give me the full path to the directory where you want to create the extension files, including the name of the extension (e.g., /home/user/RT-Extension-Demo) and I'll create the initial files for the new extension."
- When user provides path:
  - Extract the extension name from the path (e.g., `/path/to/RT-Extension-Demo` → `RT-Extension-Demo`)
  - Extract the parent directory (e.g., `/path/to/RT-Extension-Demo` → `/path/to`)
  - cd to the parent directory
  - Run: `dzil new -P RTx RT-Extension-Demo` (using the extracted name)
  - Verify the extension directory was created
  - Proceed with the extension directory

**Scenario B: General extension work (modify, test, build existing extension)**
- **Prompt:** "What is the path to the extension directory you're working on?"
- When user provides path:
  - Verify the directory exists
  - **If directory does NOT exist:**
    - Ask: "The directory doesn't exist. Would you like me to create a new extension with this name?"
    - If yes, follow the creation steps from Scenario A
  - **If directory exists:**
    - Proceed with the existing extension directory

### After Path is Established

Remember this path for all subsequent operations in this session. Use this path when:
- Running bash commands (cd to the extension directory or use absolute paths)
- Reading/editing extension files
- Running make, perl, or test commands

**Example Scenario A (Explicit Create):**
```
User: "I want to create a new extension for custom fields"
You: "Sure, give me the full path to the directory where you want to create the extension files, including the name of the extension (e.g., /home/user/RT-Extension-Demo) and I'll create the initial files for the new extension."
User: "/home/user/RT-Extension-CustomField"
Action: cd /home/user && dzil new -P RTx RT-Extension-CustomField
Result: Extension scaffolding created at /home/user/RT-Extension-CustomField
```

**Example Scenario B (Existing Extension):**
```
User: "Help me work on my extension"
You: "What is the path to the extension directory you're working on?"
User: "/home/user/RT-Extension-Existing"
Check: Directory exists
Result: Proceed with /home/user/RT-Extension-Existing
```

## When to Use This Skill

Use this skill when:
- Creating a new RT extension
- Installing or configuring existing extensions
- Working with RT callbacks
- Modifying RT menus or UI through extensions
- Understanding RT's extension directory structure
- Testing extensions
- Preparing extensions for distribution

## Expected Development Environment Configuration

This skill assumes you have a **development RT setup**, which is typically a git checkout of RT configured for development.

### Prerequisites

**Development RT Installation**
- Git checkout of RT or development installation
- See `docs/hacking.pod` (Development tips section) for setup instructions
- RTHOME environment variable pointing to your RT installation (e.g., `/Users/jbrandt/rts/astound-rt6`)

**Extension Directory**
- Separate directory from RT installation for extension development
- You'll be prompted for the full path when the skill activates

**Development Web Server**
- In development mode, use: `sbin/rt-server`
- This is the standard RT development server
- After reinstalling extensions, restart with: `sbin/rt-server --restart` or stop/start

**Required Tools**
- Perl with RT dependencies installed
- `dzil` (Dist::Zilla) for creating new extensions: `cpan Dist::Zilla::MintingProfile::RTx`
- `make` for building extensions
- Git for version control (recommended)

**For more details on setting up a development RT environment, consult `docs/hacking.pod` in your RT installation.**

## Creating a New Extension

### Prerequisites

Install these CPAN modules:
- `Module::Install::RTx` - Sets up extension installation
- `Dist::Zilla::MintingProfile::RTx` - Distribution management tools

### Initialize Extension

1. Set up Dist::Zilla (first time only):
   ```bash
   dzil setup
   ```

2. Create new extension (replace "Demo" with your extension name):
   ```bash
   dzil new -P RTx RT-Extension-Demo
   ```

### Naming Conventions

- Extensions use the format: `RT-Extension-YourName`
- Module name: `RT::Extension::YourName`
- Check existing extensions on CPAN for naming ideas
- Ask on IRC (#rt on irc.perl.org) if unsure about naming

## Extension Directory Structure

```
RT-Extension-Demo/
├── lib/                          # Perl module code
│   └── RT/Extension/Demo.pm      # Main module
├── html/                         # Mason templates and new pages
│   └── Callbacks/                # Callback implementations
│       └── RT-Extension-Demo/    # Organized by extension name
├── static/                       # RT 4.2+ static files
│   ├── css/                      # Stylesheets
│   └── js/                       # JavaScript files
├── html/NoAuth/                  # RT 4.0 static files (legacy)
│   ├── css/
│   └── js/
├── etc/                          # Configuration and initial data
│   ├── *_Config.pm               # Auto-loaded config files
│   └── initialdata               # Database objects (optional)
├── xt/                           # Extension tests (not 't/')
├── patches/                      # RT core patches (if needed)
├── Makefile.PL                   # Build configuration
└── README                        # Auto-generated installation docs
```

### Key Directories Explained

**lib/**: Standard Perl modules. Can use all RT libraries since extension runs in RT's context.

**html/**: Mason templates for callbacks and new pages. Follow RT's directory structure for proper callback execution.

**static/** (RT 4.2+) or **html/NoAuth/** (RT 4.0): CSS and JavaScript files.

**etc/**: Configuration files ending in `_Config.pm` are auto-loaded. Include `initialdata` file for automated object creation.

**xt/**: Tests go here (not standard `t/`) to prevent users from accidentally running them without proper RT development setup.

## Working with Callbacks

Callbacks are hooks throughout RT's Mason templates that allow extensions to add functionality without modifying core RT code.

### Callback Directory Structure

```
html/Callbacks/[extension-name]/[rt-mason-path]/[callback-name]
```

Example for modifying ticket update page:
```
html/Callbacks/RT-Extension-Demo/Ticket/Update.html/AfterWorked
```

### Finding Available Callbacks

Search RT's Mason templates for callback invocations:
```bash
find share/html/ | xargs grep '\->callback'
```

### Callback Example

In RT's `share/html/Ticket/Update.html`:
```perl
$m->callback( %ARGS, CallbackName => 'AfterWorked', Ticket => $TicketObj );
```

Your callback file at `html/Callbacks/RT-Extension-Demo/Ticket/Update.html/AfterWorked`:
```perl
<%args>
$Ticket
%ARGS
</%args>

<%init>
# Your code here - can modify ticket, add UI elements, etc.
</%init>
```

### Callback Parameters

- Parameters other than `CallbackName` are passed to your callback
- Often passed by reference, allowing you to modify them
- Common uses:
  - Add `Limit` calls to modify search results
  - Set flags like `$skip_update` to control flow
  - Access objects like `$TicketObj` to read/modify data

### Default Callbacks

If a callback has no `CallbackName` parameter, name your file `Default`.

## Adding CSS and JavaScript

**CRITICAL: NEVER use inline CSS or JavaScript in extension templates. ALL CSS and JavaScript MUST be in external files.**

### Why No Inline CSS/JS

- Violates best practices for RT extensions
- Makes code harder to maintain and debug
- Breaks content security policies
- Creates inconsistency with RT's architecture
- **You must ALWAYS create external files for any CSS or JavaScript**

### How to Add External CSS and JavaScript

**Step 1: Create the files in the proper directory**

Place files in:
- RT 4.2+: `static/css/` and `static/js/`
- RT 4.0: `html/NoAuth/css/` and `html/NoAuth/js/`

**Step 2: Register files in your main module** (`lib/RT/Extension/Demo.pm`):

```perl
RT->AddStyleSheets('myextension.css');
RT->AddJavaScript('myextension.js');
```

### Important

- If you find yourself writing `<style>` tags or `<script>` tags in Mason templates, STOP
- Create external files instead
- Even for small amounts of CSS/JS, use external files
- This is a hard requirement for RT extensions

## Modifying Menus

Use the Tabs callback to modify RT's menus:

Callback location: `html/Callbacks/RT-Extension-Demo/Elements/Tabs/Privileged` (or `SelfService`)

```perl
<%init>
# Add new root menu item
my $custom = Menu()->child(
    'custom',
    title => 'Custom Menu',
    path  => '/Custom/Index.html'
);

# Add submenu item
$custom->child(
    'item1',
    title => 'First Item',
    path  => '/Custom/Item1.html',
);

# Modify existing page menu
if (my $actions = PageMenu->child('actions')) {
    $actions->child(
        'newaction',
        title => loc('New Action'),
        path => '/Path/To/Action',
    );
}
</%init>
```

Menu objects are `RT::Interface::Web::Menu` instances - see that module's documentation for all available options.

## Creating Database Objects

Use an `initialdata` file in the `etc/` directory to create queues, scrips, templates, groups, etc.

Users install these with:
```bash
make initdb
```

## Configuration

- Create `etc/*_Config.pm` files for extension configuration options
- These are automatically loaded by RT
- Document all configuration options in your README

## Testing Extensions

### Setup

1. Set `RTHOME` environment variable to your RT instance:
   ```bash
   export RTHOME=/path/to/rt
   ```

2. Create `lib/RT/Extension/Demo/Test.pm.in` (note the `.in` suffix)

3. Add substitution to `Makefile.PL` to generate `Test.pm` with proper paths

4. Subclass from `RT::Test` in your test module

### Writing Tests

In test files under `xt/`:
```perl
use RT::Extension::Demo::Test tests => undef;

# Now you have full RT context with test database
# Helper methods available from RT::Test
```

See `RT::Test` documentation and other extensions like `RT::Extension::RepeatTicket` for examples.

### Command-line Component Testing

Use the Modulino approach with a `run` method. See `RT::Extension::RepeatTicket` for examples.

## Patches to RT Core

If your extension requires changes to RT itself:

1. Create a `patches/` directory
2. Name patches by RT version: `4.0.7-description.diff`
3. Only provide patches that will be merged into RT
4. Document patch requirements in README
5. Generally, patches adding new callbacks are accepted

Submit patches to RT following the `hacking` document guidelines.

## Installing Extension to Development RT

**CRITICAL: When the user asks to install an extension to their development RT, you MUST follow ALL of these steps in order.**

This process installs the extension from the extension directory into the local development RT installation for testing. Developers work with a test RT checkout they own, so sudo is NOT required.

### ⚠️ MANDATORY PRE-REQUISITE: SET RTHOME FIRST ⚠️

**BEFORE running ANY installation commands, you MUST ALWAYS set the RTHOME environment variable:**

```bash
export RTHOME=/path/to/rt/installation
```

**THIS IS NOT OPTIONAL. THIS MUST BE THE VERY FIRST COMMAND YOU RUN.**

**CRITICAL: ALWAYS SET RTHOME, EVEN IF IT ALREADY HAS A VALUE!**

The user may have RTHOME set in their shell to a default value, but it might point to a DIFFERENT RT installation than the one you're working with. You must ALWAYS explicitly set RTHOME to the current dev RT directory before installing extensions.

**DO NOT check if RTHOME is already set and skip setting it. ALWAYS set it explicitly to the correct path.**

Without RTHOME set correctly, the installation will install to the wrong RT location. The current working directory is typically the RT installation directory from the environment configuration, so use that exact path.

**DO NOT PROCEED TO ANY OTHER INSTALLATION STEPS UNTIL RTHOME IS SET TO THE CORRECT PATH.**

### Required Installation Steps

**Step 1: Set RTHOME Environment Variable**
```bash
export RTHOME=/path/to/rt/installation
```
This tells the extension where RT is installed. **ALWAYS run this first.**

**Step 2: Run perl Makefile.PL**
```bash
cd /path/to/extension
perl Makefile.PL
```
This configures the extension for installation. Uses RTHOME to find RT. **REQUIRED - do not skip.**

**Step 3: Build the Extension**
```bash
make
```
Prepares the extension files for installation.

**Step 4: Install to RT**
```bash
make install
```
Copies extension files to RT's local/plugins directory.

**Step 5: Clear Mason Cache**
```bash
rm -rf $RTHOME/var/mason_data/obj
```
Required to pick up HTML/template changes.

**Step 6: Restart Web Server**
Restart method depends on the development environment setup.

### Optional Steps (First Install Only)

These steps are only needed on the **initial installation** of the extension:

**Enable Plugin in RT Configuration**

Add to `etc/RT_SiteConfig.pm` or create a file in `etc/RT_SiteConfig.d/`:
```perl
Plugin( 'RT::Extension::Name' );
```
Only needed once. Do NOT repeat on subsequent reinstalls.

**HELPFUL: After first-time installation, provide the Plugin line formatted for easy copy-paste:**
```perl
Plugin('RT::Extension::Name');
```
This makes it easy for the user to add to their configuration file. Do NOT provide this during reinstalls when actively working on an extension - only on first installation.

**Initialize Database Objects**

If the extension has database objects (queues, scrips, custom fields, etc.) defined in `etc/initialdata`:
```bash
cd /path/to/extension
make initdb
```
Check if `etc/initialdata` exists before offering this step. Only run on first installation unless specifically requested.

### Efficient Reinstall After Changes (Most Common Development Loop)

**When the user asks to reinstall or update the extension after making changes, use this efficient single-command approach:**

```bash
export RTHOME=/path/to/rt && cd /path/to/extension && perl Makefile.PL && make && make install && rm -rf $RTHOME/var/mason_data/obj
```

This chains all required steps together in one command. Note:
- **The command INCLUDES setting RTHOME first - ALWAYS include this even if RTHOME is already set!**
- Plugin must already be configured in RT config (from first install)
- Mason cache clear is included (safe to always run)

**When to use this:**
- After any code changes to the extension
- User says "reinstall", "update", "install my changes", etc.
- This is the MOST EFFICIENT approach - use it by default for reinstalls

**After running the reinstall command:**
- Remind the user they need to restart their web server
- Do NOT provide the Plugin line again (it's already in their config from first install)

### Important Notes for Development Installation

- **ALWAYS set RTHOME first, even if it already has a value!** The user may have it set to a different RT installation in their shell
- **NEVER skip Step 1 (RTHOME) or Step 2 (perl Makefile.PL)** - these are absolutely required
- Steps 1-4 must be run every time you reinstall during development
- Step 5 (clear cache) only needed if extension has HTML/Mason templates
- After code changes, use the efficient reinstall command above (which includes setting RTHOME)
- Working with dev RT checkout - no sudo required
- Plugin configuration and initdb only needed on first install

## Preparing for Release

### Generate Distribution Files

```bash
perl Makefile.PL      # Creates inc/.author directory
make manifest         # Creates MANIFEST
make distcheck        # Validates everything is ready
make dist             # Creates tarball
```

### Upload to CPAN

Use `cpan-upload` utility from `CPAN::Uploader` or your preferred upload method.

### What Gets Included

- All files listed in MANIFEST
- `inc/` directory with Module::Install code
- Auto-generated README

## Installing Extensions (End User Reference)

This information helps you test installation and document your extension:

1. Extract extension tarball
2. `perl Makefile.PL` (set RTHOME if RT in non-standard location)
3. `make`
4. `make install` (may need root/sudo)
5. `make initdb` (if extension has database changes)
6. Enable in RT configuration:
   - RT 4.2+: `Plugin( 'RT::Extension::Demo' );`
7. Configure extension-specific settings
8. Clear Mason cache: `rm -rf /opt/rt6/var/mason_data/obj`
9. Restart webserver

### Important Notes

- Never use `cpan` or `cpanm` to install RT extensions (skips critical steps)
- Always read the extension's README - it takes precedence
- Cache clearing may not be needed for non-display extensions

## Version Compatibility

RT extensions typically support:
- RT 5.0 (check for any breaking changes)
- RT 6.0 (current version - verify compatibility)

Always document which RT versions your extension supports.

## Best Practices

1. **Use callbacks whenever possible** - Don't modify core RT code
2. **No inline CSS or JavaScript** - Always use external files in `static/css/` and `static/js/`
3. **Follow naming conventions** - Consistent with existing extensions
4. **Document everything** - Clear README, inline comments
5. **Version control** - Use git, include `.gitignore`
6. **Community engagement** - Discussion forum at forum.bestpractical.com

## Common Extension Patterns

### Adding Custom Fields Automatically
Use `initialdata` to create custom fields when extension is installed.

### Modifying Display
Use callbacks in existing pages or create new pages under `html/`.

### Adding Business Logic
Implement in Perl modules under `lib/`, expose via callbacks or new pages.

### Integration with External Systems
Create modules that interface with external APIs, trigger via scrips or callbacks.

## Resources

### Primary Documentation

**If you need more detail or encounter something not covered in this skill, consult the source documentation:**

- `docs/writing_extensions.pod` - Comprehensive extension development guide (use Read tool to access)
- `docs/extensions.pod` - Extension installation and management

**When to consult the docs:**
- User asks about something not detailed in this skill
- Need more examples or edge cases
- Troubleshooting unusual extension issues

### Other Resources

- CPAN: Search for `RT::Extension::` to see existing extensions
- Example extensions: `RT::Extension::RepeatTicket` and others on CPAN

## Quick Reference

**REMINDER: All commands below must be run from the extension directory path provided by the user.**

### Create Extension
```bash
# Run from parent directory where you want to create the extension
dzil setup
dzil new -P RTx RT-Extension-YourName
cd RT-Extension-YourName  # This becomes your extension directory
```

### Find Callbacks
```bash
# Run from RT installation directory (not extension directory)
find share/html/ | xargs grep '\->callback'
```

### Test Extension
```bash
# Run from extension directory
export RTHOME=/path/to/rt
perl Makefile.PL
make
prove -lv xt/
```

### Build Distribution
```bash
# Run from extension directory
make manifest
make distcheck
make dist
```

### Installation Commands
```bash
# Run from extension directory
perl Makefile.PL
make
make install
make initdb  # if needed
# Configure in RT_SiteConfig.pm
rm -rf /opt/rt6/var/mason_data/obj
# Restart webserver
```

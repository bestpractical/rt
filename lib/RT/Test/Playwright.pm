# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2025 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
#
# (Except where explicitly superseded by other copyright notices)
#
#
# LICENSE:
#
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
#
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
#
#
# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
#
# END BPS TAGGED BLOCK }}}

package RT::Test::Playwright;

use strict;
use warnings;

=head1 NAME

RT::Test::Playwright - Playwright-based browser testing for RT

=head1 SYNOPSIS

    use RT::Test tests => undef, playwright => 1;

    my ($url, $p) = RT::Test->started_ok;
    $p->login('root', 'password');
    $p->get_ok('/Ticket/Create.html?Queue=1');
    $p->text_contains('Create a new ticket');
    $p->logout();

=head1 DESCRIPTION

This module provides Playwright-based browser testing for RT, replacing
the Selenium implementation with modern, reliable browser automation.

=head1 ENVIRONMENT VARIABLES

=over 4

=item RT_TEST_PLAYWRIGHT_HEADLESS

Set to 0 to run browser in non-headless mode for debugging. Default: 1

When set to 0, you can see the browser window and watch tests execute, which
is helpful for debugging test failures or understanding page interactions.

=item RT_TEST_PLAYWRIGHT_BROWSER

Browser type to use: 'firefox', 'chromium', or 'webkit'. Default: firefox

Firefox is the default as it has been tested most extensively with RT.
Chromium and WebKit should also work but may require additional testing.

=back

=head1 METHODS

=cut

sub Init {
    # Check if Playwright module is available
    if ( RT::StaticUtil::RequireModule('Playwright') ) {
        # Check if Node.js is available
        require File::Which;
        if ( File::Which::which('node') ) {
            return 1;
        }
    }
    RT::Test::plan( skip_all => 'Playwright not installed or Node.js not found' );
    return 0;
}

=head2 new

Constructor. Creates new Playwright instance with browser, context, and page.

=cut

sub new {
    my $class = shift;
    my %args = (
        headless => $ENV{RT_TEST_PLAYWRIGHT_HEADLESS} // 1,
        browser_type => $ENV{RT_TEST_PLAYWRIGHT_BROWSER} // 'firefox',
        @_,
    );

    my $self = bless {
        handle => undef,
        browser => undef,
        context => undef,
        page => undef,
        %args,
    }, $class;

    $class->Init() or return;
    $self->_init();

    return $self;
}

sub _init {
    my $self = shift;

    # Initialize Playwright, using a free port selected through RT's coordination
    # mechanism to make sure we track that it is taken
    require Playwright;
    my $playwright_port = RT::Test->find_idle_port;
    $self->{handle} = Playwright->new( port => $playwright_port, cleanup => 1 );

    # Launch browser
    $self->{browser} = $self->{handle}->launch(
        type => $self->{browser_type},
        headless => $self->{headless},
    );

    # Create context with viewport (standard laptop width, extra height for testing)
    $self->{context} = $self->{browser}->newContext({
        viewport => { width => 1920, height => 1920 },
    });

    # Create page
    $self->{page} = $self->{context}->newPage();
}

=head2 rt_base_url

Return the base URL for the RT test server.

=cut

sub rt_base_url {
    return $RT::Test::existing_server if $RT::Test::existing_server;
    return "http://localhost:" . RT->Config->Get('WebPort') . RT->Config->Get('WebPath') . "/";
}

=head2 get_ok

Navigate to URL with test assertion. Handles relative URLs and waits for HTMX to complete.

    $p->get_ok('/Ticket/Display.html?id=1');
    $p->get_ok($base_url . '/path');

=cut

sub get_ok {
    my $self = shift;
    my $url = shift;
    my $description = shift || $url;

    if ( $url =~ s!^/!! ) {
        $url = $self->rt_base_url . $url;
    }

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $page = $self->{page};
    my $response = $page->goto($url);

    # Wait for HTMX to complete before reporting success
    $self->wait_for_htmx();

    Test::More::ok($response && $response->ok(), $description);

    return 1;
}

=head2 wait_for_htmx

Wait for HTMX requests to complete. Called automatically by get_ok.

=cut

sub wait_for_htmx {
    my $self = shift;
    my $page = $self->{page};

    # Ensure page is loaded
    my $async = $page->waitForLoadState('domcontentloaded', { timeout => 5000 });
    $self->{handle}->await($async);

    # Scroll to load any delayed elements (hx-trigger="revealed once")
    $page->mouse->wheel(0,600);

    # Wait a bit so htmx can fire requests
    my $async_delay = $page->waitForTimeout(300);
    $self->{handle}->await($async_delay);

    $async_delay = $page->waitForLoadState('networkidle', { timeout => 5000 });
    $self->{handle}->await($async_delay);

    $self->wait_for_element('.refreshing', { state => 'hidden' });
    $self->wait_for_element('.spinner', { state => 'hidden' });
}

=head2 wait_for_element

Wait for the element to show up.

=cut

sub wait_for_element {
    my $self     = shift;
    my $selector = shift;
    my $options  = shift || {};
    $options->{timeout} //= 5000;

    my $page  = $self->{page};
    my $delay = $page->locator($selector)->first->waitFor($options);
    $self->{handle}->await($delay);
}

=head2 wait_for_notifications

Wait for jGrowl notifications to show up.

=cut

sub wait_for_notifications {
    my $self  = shift;
    my $count = ( shift || 1 ) + 1; # there is always an extra empty .jGrowl-notification in dom
    $self->wait_for_element(".jGrowl-notification:nth-child($count)");
}

=head2 title_is

Assert page title matches expected value.

    $p->title_is('RT at a glance');

=cut

sub title_is {
    my $self = shift;
    my $expected = shift;
    my $description = shift || "Title is '$expected'";

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $title = $self->{page}->title();
    Test::More::is($title, $expected, $description);
}

=head2 text_contains

Assert page contains text.

    $p->text_contains('Ticket created', 'Success message appears');

=cut

sub text_contains {
    my $self = shift;
    my $text = shift;
    my $description_or_page = shift;
    my $description;
    my $page;

    # Support optional page parameter for popup windows
    if (ref($description_or_page) && $description_or_page->can('content')) {
        $page = $description_or_page;
        $description = shift || "Page contains '$text'";
    } else {
        $description = $description_or_page || "Page contains '$text'";
        $page = $self->{page};
    }

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    # Use content() instead of textContent() to get HTML with text
    my $content = $page->content();
    Test::More::like($content, qr/\Q$text\E/, $description);
}

=head2 text_lacks

Assert page does not contain text.

    $p->text_lacks('Error', 'No errors on page');

=cut

sub text_lacks {
    my $self = shift;
    my $text = shift;
    my $description_or_page = shift;
    my $description;
    my $page;

    # Support optional page parameter for popup windows
    if (ref($description_or_page) && $description_or_page->can('content')) {
        $page = $description_or_page;
        $description = shift || "Page lacks '$text'";
    } else {
        $description = $description_or_page || "Page lacks '$text'";
        $page = $self->{page};
    }

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    # Use content() instead of textContent() to get HTML with text
    my $content = $page->content();
    Test::More::unlike($content, qr/\Q$text\E/, $description);
}

=head2 get_body

Get page body content as text.

    my $text = $p->get_body();

=cut

sub get_body {
    my $self = shift;
    my $page = $self->{page};

    # Check if this is a plain text file wrapped in <pre> tags
    # (Firefox wraps .js, .txt, .json, etc. files in HTML with a <pre> tag)
    my $pre = $page->locator('body > pre')->first();
    if ( $pre && $pre->count() > 0 ) {
        # Return just the text content from the <pre> tag
        my $content = $pre->textContent();
        # Strip trailing newline to match Selenium behavior
        $content =~ s/\n$//;
        return $content;
    }

    # Otherwise return full HTML content for normal pages
    return $page->content();
}

=head2 content_like

Assert page content matches regex pattern. Provided for compatibility.

    $p->content_like(qr/some pattern/, 'Pattern found');

=cut

sub content_like {
    my $self = shift;
    my $pattern = shift;
    my $description = shift || "Content matches pattern";

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $content = $self->{page}->content();
    Test::More::like($content, $pattern, $description);
}

=head2 content_unlike

Assert page content does not match regex pattern. Provided for compatibility.

    $p->content_unlike(qr/some pattern/, 'Pattern not found');

=cut

sub content_unlike {
    my $self = shift;
    my $pattern = shift;
    my $description = shift || "Content doesn't match pattern";

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $content = $self->{page}->content();
    Test::More::unlike($content, $pattern, $description);
}

=head2 login

Log in as user. Defaults to root/password.

    $p->login();
    $p->login('alice', 'password123');

=cut

sub login {
    my $self = shift;
    my $user = shift || 'root';
    my $pass = shift || 'password';
    my %args = @_;

    $self->logout() if $args{logout};

    local $Test::Builder::Level = $Test::Builder::Level + 1;
    $self->get_ok( $self->rt_base_url );
    $self->logged_in_as( $user, $pass );
    return 1;
}

=head2 logged_in_as

Perform login with given credentials. Used by login().

=cut

sub logged_in_as {
    my $self = shift;
    my $user = shift || '';
    my $pass = shift || '';

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $page = $self->{page};

    # Fill login form (generate Clear/Type tests like Selenium)
    # Order: pass, user (alphabetical like Selenium's sorted field loop)
    $page->fill('input[name="pass"]', '');
    Test::More::pass("Clear pass");
    $page->fill('input[name="pass"]', $pass);
    Test::More::pass("Type pass");

    $page->fill('input[name="user"]', '');
    Test::More::pass("Clear user");
    $page->fill('input[name="user"]', $user);
    Test::More::pass("Type user");

    # Submit by pressing Enter
    $page->press('input[name="pass"]', 'Enter');

    # Wait for page to load
    my $async = $page->waitForLoadState('domcontentloaded', { timeout => 30000 });
    $self->{handle}->await($async);

    # Homepage may have HTMX content, wait for it to load
    $self->wait_for_htmx();

    Test::More::pass("Login as $user");

    # Verify we're logged in by checking we're not on login page anymore
    # and the page contains the user's name
    my $title = $page->title();
    my $is_logged_in = ($title ne 'Login') && $page->content() =~ /\Q$user\E/i;
    Test::More::ok($is_logged_in, 'Logged in');

    return 1;
}

=head2 logout

Log out current user.

    $p->logout();

=cut

sub logout {
    my $self = shift;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $page = $self->{page};

    # Find logout link and get its href
    my $logout_link = $page->locator('a:has-text("Logout")')->first();
    if ($logout_link && $logout_link->count() > 0) {
        my $href = $logout_link->getAttribute('href');

        # Convert relative URL to absolute if needed
        if ( $href =~ s!^/!! ) {
            $href = $self->rt_base_url . $href;
        }

        # Navigate directly without wait_for_htmx since logout redirects to login
        my $response = $page->goto($href, {
            waitUntil => 'domcontentloaded',
            timeout => 30000
        });
        Test::More::ok($response && $response->ok(), $href);
    }

    # Wait for redirect to complete (logout redirects to login page)
    my $async = $page->waitForLoadState('domcontentloaded', { timeout => 5000 });
    $self->{handle}->await($async);

    $self->content_unlike( qr/id="preferences"/, 'Logged out' );
    return 1;
}

=head2 submit_form_ok

Submit a form with specified fields and button.

    $p->submit_form_ok(
        {
            form_name => 'BuildQuery',
            fields    => {
                ValueOfAttachment => 'ticket foo',
            },
            button => 'DoSearch',
        },
        'Search tickets'
    );

=cut

sub submit_form_ok {
    my $self = shift;
    my $args = shift;
    my $desc = shift || 'Submit form';

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $page = $self->{page};

    # Build form selector
    my $form_selector = $args->{form} ||
                       ($args->{form_name} ? "form[name='$args->{form_name}']" : 'form');

    # Fill in fields
    for my $field ( sort keys %{ $args->{fields} || {} } ) {
        my $field_selector = "$form_selector [name='$field']";
        my $value = $args->{fields}{$field};

        # Convert value to string (Playwright requires strings)
        $value = defined $value ? "$value" : '';

        # Check if this is a richtext/CKEditor field before trying to fill
        # This avoids the 30-second timeout waiting for a hidden textarea
        my $is_richtext = 0;

        my $locator = $page->locator($field_selector)->first();
        if ($locator && $locator->count() > 0) {
            my $class_attr = $locator->getAttribute('class') || '';
            $is_richtext = $class_attr =~ /\brichtext\b/;
        }

        if ($is_richtext) {
            # Handle CKEditor field directly (no Clear/Type tests like Selenium)
            my $ckeditor_selector = "$field_selector + .ck-editor .ck-editor__editable";
            my $async = $page->waitForSelector($ckeditor_selector, {
                state => 'visible',
                timeout => 5000
            });
            $self->{handle}->await($async);

            # Fill the field without generating tests (like Selenium's set_richtext_field)
            $page->fill($ckeditor_selector, $value);
            next;
        }

        # Determine field type to handle appropriately
        # NOTE: Like Selenium, only generate Clear/Type tests for regular text inputs,
        # not for select, radio, checkbox, or richtext fields

        # Reuse locator from above to get the tag name
        my $tag_name = $locator->evaluate('return arguments[0].tagName.toLowerCase()');

        # Handle different field types
        if ( $tag_name eq 'select' ) {
            # Select element, use selectOption (no test like Selenium)
            $page->selectOption($field_selector, $value);
        }
        elsif ( $tag_name eq 'input' ) {
            my $input_type = $locator->getAttribute('type') || 'text';

            if ( $input_type eq 'radio' ) {
                # Radio button, click the one with matching value (no test like Selenium)
                my $radio_selector = "$field_selector\[value='$value'\]";
                $page->click($radio_selector);
            }
            elsif ( $input_type eq 'checkbox' ) {
                # Checkbox, use check() or uncheck() (no test like Selenium)
                if ( $value ) {
                    $page->check($field_selector);
                }
                else {
                    $page->uncheck($field_selector);
                }
            }
            else {
                # Regular text input
                # Generate Clear/Type tests like Selenium
                $page->fill($field_selector, '');
                Test::More::pass("Clear $field");

                $page->fill($field_selector, $value);
                Test::More::pass("Type $field");
            }
        }
        elsif ( $tag_name eq 'textarea' ) {
            # Check if this is a richtext/CKEditor field
            my $class_attr = $locator->getAttribute('class') || '';
            if ( $class_attr =~ /\brichtext\b/ ) {
                # CKEditor field - fill the contenteditable element (no tests)
                my $ckeditor_selector = "$field_selector + .ck-editor .ck-editor__editable";
                my $async = $page->waitForSelector($ckeditor_selector, {
                    state => 'visible',
                    timeout => 5000
                });
                $self->{handle}->await($async);
                $page->fill($ckeditor_selector, $value);
            }
            else {
                # Regular textarea
                # Generate Clear/Type tests like Selenium
                $page->fill($field_selector, '');
                Test::More::pass("Clear $field");

                $page->fill($field_selector, $value);
                Test::More::pass("Type $field");
            }
        }
        else {
            die "Unknown field type for '$field': tag=$tag_name";
        }
    }

    # Find and click submit button
    my $button_selector;
    if ( $args->{button} ) {
        # If button contains non-word characters, treat as CSS selector (like Selenium)
        # Otherwise treat as name attribute
        if ( $args->{button} =~ /\W/ ) {
            $button_selector = "$form_selector $args->{button}";
        }
        else {
            $button_selector = "$form_selector input[name='$args->{button}']";
        }
    }
    else {
        # Default to any submit button in the form
        $button_selector = "$form_selector input[type='submit']";
    }

    $page->click($button_selector);

    # Wait for HTMX to complete after form submission
    $self->wait_for_htmx();

    Test::More::ok(1, $desc);
    return 1;
}

=head2 close_jgrowl

Close jGrowl notification messages.

    $p->close_jgrowl();

=cut

sub close_jgrowl {
    my $self = shift;
    my $page = $self->{page};

    # Try to click the "close all" button first
    my $close_all = $page->locator('div.jGrowl-closer');
    if ( $close_all->count() > 0 ) {
        $close_all->click();
    }
    else {
        # Try individual close button
        my $close_button = $page->locator('button.jGrowl-close');
        if ( $close_button->count() > 0 ) {
            $close_button->first()->click();
        }
    }

    # Wait for animation to complete
    my $async = $page->waitForTimeout(2000);
    $self->{handle}->await($async);
}

=head2 current_url_is

Assert current URL matches expected value.

    $p->current_url_is($url, 'On expected page');

=cut

sub current_url_is {
    my $self = shift;
    my $expected = shift;
    my $description = shift || "Current URL is '$expected'";

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $current = $self->{page}->url();
    Test::More::is($current, $expected, $description);
}

=head2 current_url_isnt

Assert current URL does not match expected value.

    $p->current_url_isnt($url, 'Not on that page');

=cut

sub current_url_isnt {
    my $self = shift;
    my $unexpected = shift;
    my $description = shift || "Current URL is not '$unexpected'";

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $current = $self->{page}->url();
    Test::More::isnt($current, $unexpected, $description);
}

=head2 current_url_like

Assert current URL matches regex pattern.

    $p->current_url_like(qr/Ticket\/Display/, 'On ticket display page');

=cut

sub current_url_like {
    my $self = shift;
    my $pattern = shift;
    my $description = shift || "Current URL matches pattern";

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $current = $self->{page}->url();
    Test::More::like($current, $pattern, $description);
}

=head2 content_contains

Assert page content contains text. Alias for text_contains.

    $p->content_contains('Success message');

=cut

sub content_contains {
    my $self = shift;
    # Just delegate to text_contains
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    $self->text_contains(@_);
}

=head2 get

Navigate to URL without test assertion.

    $p->get($url);

=cut

sub get {
    my $self = shift;
    my $url = shift;

    if ( $url =~ s!^/!! ) {
        $url = $self->rt_base_url . $url;
    }

    my $page = $self->{page};
    $page->goto($url, {
        waitUntil => 'domcontentloaded',
        timeout => 30000
    });

    # Wait for HTMX to complete
    $self->wait_for_htmx();
}

=head2 text_like

Assert page text matches regex pattern.

    $p->text_like(qr/Ticket \d+ created/, 'Ticket created message found');

=cut

sub text_like {
    my $self = shift;
    my $pattern = shift;
    my $description = shift || "Page text matches pattern";

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $content = $self->{page}->content();
    Test::More::like($content, $pattern, $description);
}

=head2 text_unlike

Assert page text does not match regex pattern.

    $p->text_unlike(qr/Error/, 'No error messages');

=cut

sub text_unlike {
    my $self = shift;
    my $pattern = shift;
    my $description = shift || "Page text doesn't match pattern";

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $content = $self->{page}->content();
    Test::More::unlike($content, $pattern, $description);
}

=head2 goto_create_ticket

Navigate to ticket create page for specified queue.

    $p->goto_create_ticket(1);              # Queue ID
    $p->goto_create_ticket($queue_obj);     # Queue object
    $p->goto_create_ticket('General');      # Queue name

=cut

sub goto_create_ticket {
    my $self = shift;
    my $queue = shift;

    my $id;
    if ( ref $queue ) {
        $id = $queue->id;
    }
    elsif ( $queue =~ /^\d+$/ ) {
        $id = $queue;
    }
    else {
        my $queue_obj = RT::Queue->new( RT->SystemUser );
        my ( $ok, $msg ) = $queue_obj->Load($queue);
        die "Unable to load queue '$queue': $msg" if !$ok;
        $id = $queue_obj->id;
    }

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $page = $self->{page};

    # Check if we're on a page with the create button
    my $button = $page->locator('input[value="Create new ticket"]');
    $self->get_ok( $self->rt_base_url ) unless $button->count() > 0;

    # Click create new ticket button (generate test like Selenium)
    $page->click('input[value="Create new ticket"]');
    Test::More::pass('Click create new ticket');
    $self->wait_for_htmx();

    # Select the queue
    my $queue_selector = 'form[name=TicketCreate] [name=Queue]';
    $page->selectOption($queue_selector, "$id");
    $self->wait_for_htmx();

    return 1;
}

=head2 goto_ticket

Navigate to a ticket display page.

    $p->goto_ticket($ticket_id);
    $p->goto_ticket($ticket_id, 'Update');  # Go to update page instead

=cut

sub goto_ticket {
    my $self = shift;
    my $id   = shift;
    my $view = shift || 'Display';
    unless ( $id && int $id ) {
        Test::More::diag( "error: wrong id " . (defined $id ? $id : '(undef)') );
        return 0;
    }

    my $url = $self->rt_base_url;
    $url .= "Ticket/${ view }.html?id=$id";
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    $self->get_ok($url);
    return 1;
}

=head2 find_element

Find element by XPath. Returns first matching locator or dies if not found.

    my $elem = $p->find_element('//div[@class="foo"]');

=cut

sub find_element {
    my $self = shift;
    my $xpath = shift;

    my $page = $self->{page};

    # Convert XPath to CSS selector if possible, or use xpath= prefix
    my $selector = "xpath=$xpath";
    my $locator = $page->locator($selector)->first();

    # Wait for element to exist using proper async/await
    my $async = $locator->waitFor({ state => 'attached', timeout => 5000 });
    $self->{handle}->await($async);

    return $locator;
}

=head2 dom

Get Mojo::DOM object for HTML parsing. Provided for compatibility.

    my $dom = $p->dom();
    my $text = $dom->at('div.ticket-info')->text;

=cut

sub dom {
    my $self = shift;
    require Mojo::DOM;
    return Mojo::DOM->new( $self->{page}->content() );
}

sub DESTROY {
    my $self = shift;

    # Clean up resources
    $self->{page}->close() if $self->{page};
    $self->{context}->close() if $self->{context};
    $self->{browser}->close() if $self->{browser};
}

require RT::Base;
RT::Base->_ImportOverlays();

1;

=head1 AUTHOR

Best Practical Solutions, LLC <modules@bestpractical.com>

=head1 LICENSE

This software is Copyright (c) 1996-2025 Best Practical Solutions, LLC

See the LICENSE file for full license details.

=cut

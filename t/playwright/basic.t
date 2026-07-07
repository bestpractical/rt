
use strict;
use warnings;

use RT::Test tests => undef, playwright => 1;

my ( $url, $p ) = RT::Test->started_ok;

$p->login();

{
    $p->goto_create_ticket(1);
    $p->text_contains( 'RT Version', 'RT Version found, footer loaded' );

    my $subject = Encode::decode( "UTF-8", "I18N Web Testing Subject æøå" );
    my $content = Encode::decode( "UTF-8", "I18N Web Testing Content æøå" );
    $p->submit_form_ok(
        {
            form_name => 'TicketCreate',
            fields    => {
                Subject => $subject,
                Content => $content,
            },
            button => 'SubmitTicket',
        },
        'Create ticket'
    );

    # Find an element in history to implicitly wait for the delayed history load
    $p->find_element(q{//div[contains(@class, 'transaction')]});
    $p->text_contains( $content, 'Found the content' );

    {
        my $ticket  = RT::Test->last_ticket;
        my $content = $ticket->Transactions->First->Content;
        like( $content, qr{$content}, 'content is there, API check' );
        is( $ticket->Subject, $subject, 'subject is correct, API check' );

        # Set status to open for clone test
        $ticket->SetStatus('open');
        is( $ticket->Status, 'open', 'Ticket status set to open' );
    }

    # Test ticket clone via Create link in Links section
    {
        my $ticket = RT::Test->last_ticket;
        my $ticket_id = $ticket->id;

        # Go to the ticket display page
        $p->get_ok( $url . "/Ticket/Display.html?id=$ticket_id" );

        # Wait for the Links widget to load
        $p->find_element(q{//div[contains(@class, 'ticket-info-links')]});

        # Get the Status value displayed on the ticket page
        my $status_elem = $p->find_element(q{//div[contains(@class, 'ticket-info-basics')]//div[contains(@class, 'status')]//span[contains(@class, 'current-value')]});
        my $display_status = $status_elem->textContent();
        diag "Status displayed on ticket #$ticket_id: $display_status";
        is( $display_status, 'open', 'Ticket display shows status as open' );

        # Click the "Create" link in the Links section (RefersTo-new)
        my $create_link = $p->find_element(q{//div[contains(@class, 'ticket-info-links')]//a[text()='Create' and contains(@href, 'RefersTo-new')]});
        $create_link->click();

        # Wait for the create page to load
        $p->find_element(q{//form[@name='TicketCreate']});

        # Wait for HTMX to finish loading the page content
        $p->wait_for_htmx();

        # Get the Status value on the create page
        my $create_status_elem = $p->find_element(q{//select[@name='Status']//option[@selected]});
        my $create_status = $create_status_elem->textContent();
        is( $create_status, 'new', 'Create page shows cloned status as new' );
    }

    $p->get_ok( $url . '/Ticket/Create.html?Requestors=root@localhost,alice@localhost' );
    $p->submit_form_ok(
        {   form_name => 'TicketCreate',
            fields    => { Subject => 'Test multiple requestors', },
            button    => 'SubmitTicket',
        },
        'Create ticket'
    );

    my $ticket     = RT::Test->last_ticket;
    my @requestors = $ticket->Requestors->MemberEmailAddresses;
    is_deeply( \@requestors, [ 'alice@localhost', 'root@localhost' ], 'Correct requestors' );
}


{
    # Test that static files are served correctly and not processed by Mason
    my $response = $p->{page}->goto( $url . "/static/images/test.png" );
    my $file = RT::Test::get_relocatable_file( File::Spec->catfile(qw(.. .. share static images test.png)) );
    my $body_ref = $response->body();

    # body() returns { type => 'Buffer', data => [byte, byte, ...] }
    # Convert byte array to binary string
    my $body = pack('C*', @{$body_ref->{data}});

    is( length( $body ), -s $file, "got a file of the correct size ($file)", );
}

{
    my $queue = RT::Test->load_or_create_queue( Name => 'foo&bar' );
    $p->goto_create_ticket( $queue->id );
    $p->title_is('Create a new ticket in foo&bar');
}


diag "test custom field unique values";
{
    my $queue = RT::Test->load_or_create_queue( Name => 'General' );
    ok $queue && $queue->id, 'loaded or created queue';

    my $cf = RT::Test->load_or_create_custom_field(
        Name         => 'External ID',
        Queue        => 'General',
        Type         => 'FreeformSingle',
        UniqueValues => 1,
    );
    my $cf_id = $cf->Id;
    $p->goto_create_ticket($queue);
    $p->title_is('Create a new ticket in General');
    $p->submit_form_ok(
        {
            form_name => 'TicketCreate',
            fields    => { Subject => 'Test unique values', "Object-RT::Ticket--CustomField-$cf_id-Value" => '123' },
            button    => 'SubmitTicket',
        },
        'Create ticket with cf value 123',
    );

    $p->text_like(qr/Ticket \d+ created in queue/);

    my $ticket = RT::Test->last_ticket;
    is( $ticket->FirstCustomFieldValue($cf), 123, 'CF value is set' );

    $p->goto_create_ticket($queue);
    $p->submit_form_ok(
        {
            form_name => 'TicketCreate',
            fields    => { Subject => 'Test unique values', "Object-RT::Ticket--CustomField-$cf_id-Value" => '123' },
            button    => 'SubmitTicket',
        },
        'Create ticket with cf value 123',
    );
    $p->text_contains("'123' is not a unique value");
    $p->text_unlike(qr/Ticket \d+ created in queue/);

    $p->submit_form_ok(
        {
            form_name => 'TicketCreate',
            fields    => { Subject => 'Test unique values', "Object-RT::Ticket--CustomField-$cf_id-Value" => '456' },
            button    => 'SubmitTicket',
        },
        'Create ticket with cf value 456'
    );
    $p->text_like(qr/Ticket \d+ created in queue/);
    $ticket = RT::Test->last_ticket;
    is( $ticket->FirstCustomFieldValue($cf), 456, 'CF value is set' );
}

{
    $p->get_ok('/Prefs/AboutMe.html');
    $p->submit_form_ok(
        {
            form_name => 'EditAboutMe',
            fields    => { Lang => 'zh-cn' },
        },
        'Update Language'
    );

    $p->text_contains( Encode::decode( 'UTF-8', '主页' ), 'Menu has changed to Chinese' );
    $p->get_ok('/');
    $p->text_contains( Encode::decode( 'UTF-8', '我拥有的前10份待处理申请单' ), 'Chinese title is correct' );

    $p->get_ok('/Prefs/AboutMe.html');
    $p->submit_form_ok(
        {
            form_name => 'EditAboutMe',
            fields    => { Lang => '' },
        },
        'Update Language'
    );
    $p->text_contains(q{Lang changed from 'zh-cn' to (no value)});

}

# On an htmx history-cache miss (what historyCacheError causes in production) the
# browser Back button runs htmx's loadHistoryFromServer and swaps the response into
# the history element. With .main-container marked hx-history-elt, only the content
# area is swapped, so the top navigation menu (outside .main-container) survives.
diag 'Top navigation menu survives a browser Back that hits a history-cache miss';
{
    my $page = $p->{page};

    $p->get_ok('/');
    my $home_url = $page->url;
    ok( $p->dom->at('#main-navigation #app-nav'), 'homepage renders the top navigation menu' );
    ok( $p->dom->at('#page-edit'),                'homepage has the page-edit link to navigate with' );

    # Marker to prove the Back is an htmx restore, not a full page reload; a reload
    # would also show the menu and so hide a regression.
    $page->evaluate('window.__historyProbe = "start"; return true');

    # Boosted navigation to a second page so the Back button is htmx-managed.
    $page->evaluate('return document.querySelector("#page-edit").click()');
    $p->wait_for_htmx;
    $p->current_url_like( qr{/Prefs/MyRT\.html}, 'boosted navigation reached the second page' );
    ok( $p->dom->at('#main-navigation #app-nav'), 'second page also renders the menu' );

    # Drop the cached snapshot so the Back is a cache miss (loadHistoryFromServer),
    # the same path a historyCacheError puts users on in production.
    $page->evaluate('localStorage.removeItem("htmx-history-cache"); return true');

    $page->goBack;
    $p->wait_for_htmx;

    is( $page->url, $home_url, 'Back returned to the homepage' );
    ok( $p->dom->at('#main-navigation #app-nav'), 'menu still present after Back through a history-cache miss' );
    is( $page->evaluate('return window.__historyProbe'), 'start', 'Back was an htmx restore, not a full page reload' );
    is( $page->evaluate('return document.querySelectorAll(".main-container").length'),
        1, 'exactly one .main-container after restore (no double-nesting)' );
}

$p->logout;

done_testing;

use strict;
use warnings;
use Test::Deep;

use RT::Test tests => undef, playwright => 1, config => q{
    Set($AutocompleteOwners, 1);
    Set(%InlineEditPanelBehavior,
        'RT::Ticket' => {
            '_default' => 'link',
            'Dates' => 'always',
            'People' => 'click',
            'Foo' => 'hide',
            'Links' => 'click',
        },
    );

    Set(
        %CustomFieldGroupings,
        'RT::Ticket' => {
            'General' => {
                'Basics' => [ 'basics' ],
                'People' => [ 'people' ],
                'Dates'  => [ 'dates' ],
                'Links'  => [ 'links' ],
                'Foo'    => ['foo'],
                'Bar' => ['bar1', 'bar2'],
            },
        },
    );

    Set(
        %PageLayouts,
        'RT::Ticket' => {
            'Display' => {
                Default => [
                    {
                        Layout   => 'col-md-6',
                        Title    => 'Ticket metadata',
                        Elements => [
                            [ 'Basics', 'Description', 'Times', 'CustomFieldCustomGroupings', 'People', 'Attachments', 'Requestors' ],
                            [ 'Reminders', 'Articles', 'Dates', 'LinkedQueues', 'Assets', 'Links' ],
                        ],
                    },
                    {
                        Layout   => 'col-12',
                        Elements => ['History'],
                    }
                ],
            },
        },
    );
};

my ( $url, $p ) = RT::Test->started_ok;

my $cf_basics = RT::Test->load_or_create_custom_field( Name => 'basics', Type => 'FreeformSingle', Queue => 0 );
my $cf_people = RT::Test->load_or_create_custom_field( Name => 'people', Type => 'FreeformSingle', Queue => 0 );
my $cf_dates  = RT::Test->load_or_create_custom_field( Name => 'dates',  Type => 'Date',           Queue => 0 );
my $cf_links  = RT::Test->load_or_create_custom_field( Name => 'links',  Type => 'FreeformSingle', Queue => 0 );
my $cf_foo    = RT::Test->load_or_create_custom_field( Name => 'foo',    Type => 'FreeformSingle', Queue => 0 );
my $cf_bar1   = RT::Test->load_or_create_custom_field( Name => 'bar1',   Type => 'FreeformSingle', Queue => 0 );
my $cf_bar2   = RT::Test->load_or_create_custom_field( Name => 'bar2',   Type => 'SelectSingle',   Queue => 0 );
my $cf_baz    = RT::Test->load_or_create_custom_field( Name => 'baz',    Type => 'SelectMultiple', Queue => 0 );

ok( $cf_bar2->AddValue( Name => $_ ), "Added value $_ to bar2" ) for 'A' .. 'C';
ok( $cf_baz->AddValue( Name => $_ ),  "Added value $_ to baz" )  for 'A' .. 'F';

my $queue_foo = RT::Test->load_or_create_queue( Name => 'Foo' );

$p->login();

my $root = RT::Test->load_or_create_user( Name => 'root' );
my $ticket
    = RT::Test->create_ticket( Queue => 'General', Subject => 'Test inline edit', Requestor => 'root@localhost' );
my $ticket_id = $ticket->Id;

$p->goto_ticket($ticket_id);

my $dom = $p->dom;
is( $dom->at('#li-page-actions-open-it a')->text, 'Open It', 'Got "Open It" page menu' );
is( $dom->at('#li-page-actions-take a')->text, 'Take', 'Got "Take" page menu' );

diag "Testing basics inline edit";
{
    $p->{page}->click('div.ticket-info-basics a.inline-edit-toggle');
    $p->submit_form_ok(
        {
            form   => 'div.ticket-info-basics form.inline-edit',
            fields => {
                Subject    => 'Test inline edit updated',
                Status     => 'open',
                RT::Interface::Web::GetCustomFieldInputName(
                    CustomField => $cf_basics,
                    Object      => $ticket,
                    Grouping    => 'Basics'
                ) => 'b1',
            },
        },
        'Submit basics inline edit'
    );
    $p->wait_for_notifications(3);
    $p->wait_for_element('div.ticket-info-basics .inline-edit-display div.status:has-text("open")');

    $p->title_is("#$ticket_id: Test inline edit updated");

    my $dom = $p->dom;
    is( $dom->at('#header h1')->text, "#$ticket_id: Test inline edit updated", 'Got updated subject in header' );
    is( $dom->at('div.status div.col div.rt-value .current-value')->all_text, 'open',         'Got updated status' );
    like( $dom->at('div.custom-field-basics div.col div.rt-value .current-value')->text, qr/^\s*b1\s*$/, 'Got updated cf basics' );
    cmp_deeply(
        $dom->find('.jGrowl-message')->map('text')->to_array,
        bag(
            qq{Ticket $ticket_id: Subject changed from 'Test inline edit' to 'Test inline edit updated'},
            qq{Ticket $ticket_id: Status changed from 'new' to 'open'},
            qq{basics b1 added},
        ),
        'Got notification of changes'
    );
    ok( !$dom->at('#li-page-actions-open-it'), 'No "Open It" page menu' );

    $p->close_jgrowl;
}

diag "Testing time inline edit";
{
    $p->{page}->click('div.ticket-info-times a.inline-edit-toggle');
    $p->submit_form_ok(
        {
            form   => 'div.ticket-info-times form.inline-edit',
            fields => {
                TimeEstimated => 10,
                TimeWorked => 5,
                TimeLeft => 15,
            },
        },
        'Submit time inline edit'
    );

    $p->wait_for_notifications(3);
    $p->wait_for_element('div.ticket-info-times .inline-edit-display:has-text("10 minutes")');

    $p->title_is("#$ticket_id: Test inline edit updated");
    my $dom = $p->dom;
    like( $dom->at('div.time.estimated div.col div.rt-value .current-value')->text, qr/^10 minutes\s*$/, 'Got updated timeestimated' );
    like( $dom->at('div.time.worked div.col div.rt-value .current-value')->text, qr/^5 minutes\s*$/, 'Got updated timeworked' );
    like( $dom->at('div.time.left div.col div.rt-value .current-value')->text, qr/^15 minutes\s*$/, 'Got updated timeleft' );

    my $test_date = RT::Date->new(RT->SystemUser);
    $test_date->SetToNow;

    cmp_deeply(
        $dom->find('.jGrowl-message')->map('text')->to_array,
        bag(
            qq{Ticket 1: TimeEstimated changed from (no value) to '10'},
            qq{Ticket 1: TimeLeft changed from (no value) to '15'},
            'Worked 5 minutes on ' . $test_date->AsString( Time => 0, Timezone => 'user' ),
        ),
        'Got notification of changes'
    );

    $p->close_jgrowl;

    # Verify the edit form inputs are refreshed with updated values
    $p->{page}->click('div.ticket-info-times a.inline-edit-toggle');
    $p->wait_for_element('div.ticket-info-times form.inline-edit input[name="TimeEstimated"][value="10"]');
    $dom = $p->dom;
    is(
        $dom->at('div.ticket-info-times form.inline-edit input[name="TimeEstimated"]')->attr('value'),
        '10',
        'TimeEstimated input has updated value'
    );
    is(
        $dom->at('div.ticket-info-times form.inline-edit input[name="TimeWorked"]')->attr('value'),
        '5',
        'TimeWorked input has updated value'
    );
    is(
        $dom->at('div.ticket-info-times form.inline-edit input[name="TimeLeft"]')->attr('value'),
        '15',
        'TimeLeft input has updated value'
    );
}

diag "Testing people inline edit";
{
    $p->{page}->click('div.ticket-info-people div.inline-edit-display');
    $p->submit_form_ok(
        {
            form   => 'div.ticket-info-people form.inline-edit',
            fields => {
                WatcherTypeEmail1                                            => 'Cc',
                WatcherAddressEmail1                                         => 'alice@example.com',
                WatcherTypeEmail2                                            => 'Requestor',
                WatcherAddressEmail2                                         => 'bob@example.com',
                Owner                                                        => $root->Name,
                'Ticket-DeleteWatcher-Type-Requestor-Principal-' . $root->Id => 1,
                RT::Interface::Web::GetCustomFieldInputName(
                    CustomField => $cf_people,
                    Object      => $ticket,
                    Grouping    => 'People'
                ) => 'p1',
            },
        },
        'Submit people inline edit'
    );

    $p->wait_for_notifications(5);
    $p->wait_for_element('div.ticket-info-people .inline-edit-display div.owner:has-text("' . $root->Format . '")');

    my $dom = $p->dom;
    is( $dom->at('div.owner div.col div.rt-value .current-value span.user a:last-child')->text, $root->Format, 'Got updated owner' );
    is( $dom->at('div.requestors div.col div.rt-value .current-value span.user a:last-child')->text,
        '<bob@example.com>', 'Got updated requestor' );
    is( $dom->at('div.cc div.col div.rt-value .current-value span.user a:last-child')->text, '<alice@example.com>', 'Got updated cc' );
    ok( !$dom->at('#li-page-actions-take'), 'No "Take" page menu' );

    cmp_deeply(
        $dom->find('.jGrowl-message')->map('text')->to_array,
        bag(
            'Owner changed from Nobody to root',
            'Added bob@example.com as Requestor for this ticket',
            'Added alice@example.com as Cc for this ticket',
            'root is no longer Requestor for this ticket',
            'people p1 added'
        ),
        'Got notification of changes'
    );
    $p->close_jgrowl;
}


diag "Testing dates inline edit";
{
    $p->submit_form_ok(
        {
            form   => 'div.ticket-info-dates form.inline-edit',
            fields => {
                Starts_Date  => '2024-05-01 00:00:00',
                Started_Date => '2024-05-01 08:00:00',
                Due_Date     => '2024-05-14 12:00:00',
                Told_Date    => '2024-05-04 01:23:45',
                RT::Interface::Web::GetCustomFieldInputName(
                    CustomField => $cf_dates,
                    Object      => $ticket,
                    Grouping    => 'Dates'
                ) => '2024-05-06',
            },
        },
        'Submit dates inline edit'
    );

    $p->wait_for_notifications(5);
    my $dom = $p->dom;

    cmp_deeply(
        $dom->find('.jGrowl-message')->map('text')->to_array,
        bag(
            'Told changed from Not set to Sat May 04 01:23:45 2024',
            'Starts changed from Not set to Wed May 01 00:00:00 2024',
            re('Started changed from .+ to Wed May 01 08:00:00 2024'),
            'Due changed from Not set to Tue May 14 12:00:00 2024',
            '2024-05-06 added as a value for dates',
        ),
        'Got notification of changes'
    );
    $p->close_jgrowl;
}

diag "Testing links inline edit (new add-form + removal UI)";
{
    # The body is rendered eagerly inside one inline-edit form; the add rows and delete
    # checkboxes are present at all times and become visible only when the titlebox carries
    # .editing. Exercise add + remove end-to-end; the field-name matrix for all six relationship
    # types is covered at the web/unit level by ticket_links{,_edit}.t.

    my $refers_to = RT::Test->create_ticket( Queue => 'General', Subject => 'RefersTo target' );

    # --- Add a link via the add-form -------------------------------------------
    # Clicking the pencil only flips the .editing class (a pure CSS toggle, no fetch).
    $p->{page}->click('div.ticket-info-links a.inline-edit-toggle.edit');
    $p->wait_for_element('div.ticket-info-links.editing');
    $p->wait_for_element('div.ticket-info-links .edit-ticket-links .add-link-row');

    # The first add row defaults to link-type "Refers to" + object-type "Ticket", so its value
    # field submits as "<id>-RefersTo". The Ticket object-type binds a tom-select autocomplete;
    # drive its visible control input.
    my $value_input = $p->{page}->locator(
        'div.ticket-info-links .add-link-row:first-child .link-value + .ts-wrapper .ts-control input'
    );
    $value_input->click;
    $value_input->fill( '' . $refers_to->Id );

    $p->{page}->locator(q{div.ticket-info-links form.inline-edit input.links-edit-save})->click;
    $p->wait_for_htmx;
    $p->wait_for_notifications(1);

    # After save, ticketLinksChanged refreshes the unified list (.links-edit-target). The
    # display is a CollectionList table whose linked rows carry data-record-id="<linked id>".
    $p->wait_for_element(
        qq{div.ticket-info-links .links-edit-target tr[data-record-id="@{[$refers_to->Id]}"]}
    );

    DBIx::SearchBuilder::Record::Cachable->FlushCache;
    my $reloaded = RT::Ticket->new( RT->SystemUser );
    $reloaded->Load($ticket_id);
    my @refers_ids = map { $_->TargetObj->Id } @{ $reloaded->RefersTo->ItemsArrayRef };
    ok( ( grep { $_ == $refers_to->Id } @refers_ids ),
        'RefersTo link added from the new add-form on Save' );

    my $dom = $p->dom;
    ok(
        $dom->at(qq{div.ticket-info-links .links-edit-target tr[data-record-id="@{[$refers_to->Id]}"]}),
        'new display table has a row for the linked ticket (data-record-id)'
    );
    like(
        $dom->at('div.ticket-info-links .links-edit-target')->all_text,
        qr/RefersTo target/,
        "linked ticket's subject shown in the display"
    );
    $p->close_jgrowl;

    # --- Remove a link via the per-row trash link (immediate delete) -----------
    $p->{page}->click('div.ticket-info-links a.inline-edit-toggle.edit');
    $p->wait_for_element('div.ticket-info-links.editing');
    $p->wait_for_element('div.ticket-info-links .edit-ticket-links a.delete-link');

    my $del_link = $p->{page}->locator(
        qq{div.ticket-info-links .edit-ticket-links tr[data-record-id="@{[$refers_to->Id]}"] a.delete-link}
    );
    $del_link->first->click;
    $p->wait_for_htmx;

    $p->wait_for_element(
        qq{div.ticket-info-links .links-edit-target tr[data-record-id="@{[$refers_to->Id]}"]},
        { state => 'detached' }
    );

    DBIx::SearchBuilder::Record::Cachable->FlushCache;
    my $after = RT::Ticket->new( RT->SystemUser );
    $after->Load($ticket_id);
    my @after_ids = map { $_->TargetObj->Id } @{ $after->RefersTo->ItemsArrayRef };
    ok( !( grep { $_ == $refers_to->Id } @after_ids ),
        'RefersTo link removed immediately via the per-row trash link' );
    $p->close_jgrowl;
}

diag "Testing tom-select createOnBlur: paste a value and click Save without pressing Enter";
{
    # When a user types or pastes a value into a tom-select autocomplete and
    # clicks Save before selecting from the dropdown (or pressing Enter), the
    # typed text should be committed as an item.

    my $blur_target = RT::Test->create_ticket( Queue => 'General', Subject => 'createOnBlur target' );

    diag "Add-form Links value field (tom-select): type ticket id and click Save";
    {
        # The add-form value field is a tom-select autocomplete when the object-type is "Ticket".
        # Set the first add row's link-type to "Depends on", type the target id, and Save without
        # pressing Enter or picking from the dropdown: the typed value must still be committed.
        # Reload first: the previous block's immediate trash delete leaves the widget in edit mode.
        $p->goto_ticket($ticket_id);
        $p->{page}->click('div.ticket-info-links a.inline-edit-toggle.edit');
        $p->wait_for_element('div.ticket-info-links .edit-ticket-links .add-link-row');

        my $first_row = 'div.ticket-info-links .add-link-row:first-child';
        $p->wait_for_element("$first_row .link-type-select.tomselected");
        $p->{page}->evaluate(qq{document.querySelector("$first_row .link-type-select").tomselect.setValue("$ticket_id-DependsOn")});

        # The original <input> gets the ts-hidden-accessible class; the user-visible
        # input is inside the sibling .ts-wrapper .ts-control.
        my $depends_input = $p->{page}->locator(
            "$first_row .link-value + .ts-wrapper .ts-control input"
        );
        $depends_input->click;
        $depends_input->fill( '' . $blur_target->Id );

        $p->{page}->locator(q{div.ticket-info-links form.inline-edit input.links-edit-save})->click;
        $p->wait_for_htmx;

        DBIx::SearchBuilder::Record::Cachable->FlushCache;
        my $reloaded = RT::Ticket->new( RT->SystemUser );
        $reloaded->Load($ticket_id);
        my @dep_ids = map { $_->TargetObj->Id } @{ $reloaded->DependsOn->ItemsArrayRef };
        ok( ( grep { $_ == $blur_target->Id } @dep_ids ),
            'New DependsOn link committed from typed value on Save (no Enter, no dropdown selection)' );
        $p->close_jgrowl;
    }

    diag "Single-select Owner field: paste username and click Save";
    {
        # The People inline edit above already set Owner to root, so reset to
        # Nobody first to ensure typing root and saving is a real change.
        my $reset = RT::Ticket->new( RT->SystemUser );
        $reset->Load($ticket_id);
        $reset->SetOwner( RT->Nobody->id );
        $p->{page}->reload;
        $p->wait_for_htmx;

        $p->{page}->locator('div.ticket-info-people')->first->scrollIntoViewIfNeeded;
        $p->{page}->click('div.ticket-info-people div.inline-edit-display');
        $p->wait_for_htmx;

        # Drive the visible tom-select control input via tom-select directly. The
        # variable-width visible input (size="1") doesn't play well with
        # playwright's click/fill flow when empty.
        $p->{page}->evaluate(
            'return document.querySelector("div.ticket-info-people form.inline-edit #Owner").tomselect.control_input.focus()'
        );
        $p->{page}->keyboard->type( $root->Name );

        $p->{page}->locator('div.ticket-info-people form.inline-edit input[type=submit]')->click;
        $p->wait_for_htmx;

        # Flush the SearchBuilder cache so we read the row the server just wrote,
        # not the stale cached Ticket from earlier in the test.
        DBIx::SearchBuilder::Record::Cachable->FlushCache;
        my $reloaded = RT::Ticket->new( RT->SystemUser );
        $reloaded->Load($ticket_id);
        is( $reloaded->OwnerObj->Name, $root->Name,
            'Owner committed from typed username on Save (no Enter, no dropdown selection)' );
        $p->close_jgrowl;
    }

    diag "Single-select Owner field: focus and blur without typing leaves value unchanged";
    {
        # Regression check: createOnBlur must not interfere with the existing
        # behavior where focusing and blurring without typing restores the
        # field's prior value (so users who change their mind don't lose it).
        DBIx::SearchBuilder::Record::Cachable->FlushCache;
        my $before = RT::Ticket->new( RT->SystemUser );
        $before->Load($ticket_id);
        my $original_owner = $before->OwnerObj->Name;

        $p->{page}->locator('div.ticket-info-people')->first->scrollIntoViewIfNeeded;
        $p->{page}->click('div.ticket-info-people div.inline-edit-display');

        my $owner_wrapper = $p->{page}->locator(
            'div.ticket-info-people form.inline-edit input#Owner + .ts-wrapper .ts-control'
        );
        $owner_wrapper->scrollIntoViewIfNeeded;
        $owner_wrapper->click;    # focus only, no typing
        $p->{page}->locator('body')->click; # click somewhere harmless to blur

        # Cancel the inline edit rather than submitting (no change intended)
        $p->{page}->click('div.ticket-info-people a.inline-edit-toggle.cancel');

        DBIx::SearchBuilder::Record::Cachable->FlushCache;
        my $after = RT::Ticket->new( RT->SystemUser );
        $after->Load($ticket_id);
        is( $after->OwnerObj->Name, $original_owner,
            'Owner unchanged after focus + blur with no typing (restore behavior preserved)' );
    }
}

diag "Testing custom fields grouping inline edit";
{
    # Check that Foo grouping does not have inline edit
    my $foo_form = $p->{page}->locator('div.ticket-info-cfs-Foo form')->first();
    ok( $foo_form->count() == 0, 'Foo grouping does not have inline edit' );

    $p->{page}->click('div.ticket-info-cfs-Bar a.inline-edit-toggle');
    $p->submit_form_ok(
        {
            form   => 'div.ticket-info-cfs-Bar form.inline-edit',
            fields => {
                RT::Interface::Web::GetCustomFieldInputName(
                    CustomField => $cf_bar1,
                    Object      => $ticket,
                    Grouping    => 'Bar'
                ) => 'B',
                RT::Interface::Web::GetCustomFieldInputName(
                    CustomField => $cf_bar2,
                    Object      => $ticket,
                    Grouping    => 'Bar'
                ) => 'C',
            },
        },
        'Submit Bar inline edit'
    );

    $p->wait_for_notifications(2);
    $p->wait_for_element('div.ticket-info-cfs-Bar .inline-edit-display div.custom-field-bar1:has-text("B")');

    my $dom = $p->dom;
    like( $dom->at('div.custom-field-bar1 div.col div.rt-value .current-value')->text, qr/^\s*B\s*$/, 'Got updated cf bar1' );
    like( $dom->at('div.custom-field-bar2 div.col div.rt-value .current-value')->text, qr/^\s*C\s*$/, 'Got updated cf bar2' );
    cmp_deeply(
        $dom->find('.jGrowl-message')->map('text')->to_array,
        bag( qq{bar1 B added}, qq{bar2 C added}, ),
        'Got notification of changes'
    );
    $p->close_jgrowl;
}

diag "Testing custom fields inline edit";
{
    $p->{page}->click('div.ticket-info-cfs:not(.ticket-info-cfs-Bar) a.inline-edit-toggle');
    $p->submit_form_ok(
        {
            form   => 'div.ticket-info-cfs:not(.ticket-info-cfs-Bar) form.inline-edit',
            fields => {
                RT::Interface::Web::GetCustomFieldInputName(
                    CustomField => $cf_baz,
                    Object      => $ticket,
                ) => 'E',
            },
        },
        'Submit cf inline edit'
    );

    $p->wait_for_notifications();
    $p->wait_for_element('div.custom-field-baz .current-value:has-text("E")');

    my $dom = $p->dom;
    like( $dom->at('div.custom-field-baz div.col div.rt-value .current-value')->text, qr/^\s*E\s*$/, 'Got updated cf baz' );
    is_deeply(
        $dom->find('.jGrowl-message')->map('text')->to_array,
        [ qq{E added as a value for baz}, ],
        'Got notification of changes'
    );
    $p->close_jgrowl;

    $p->{page}->click('div.ticket-info-cfs:not(.ticket-info-cfs-Bar) a.inline-edit-toggle');
    $p->submit_form_ok(
        {
            form   => 'div.ticket-info-cfs:not(.ticket-info-cfs-Bar) form.inline-edit',
            fields => {
                RT::Interface::Web::GetCustomFieldInputName(
                    CustomField => $cf_baz,
                    Object      => $ticket,
                ) => 'F',
            },
        },
        'Submit cf inline edit'
    );
    $p->wait_for_notifications(2);
    $p->wait_for_element('div.custom-field-baz .current-value:has-text("F")');

    $dom = $p->dom;
    like( $dom->at('div.custom-field-baz div.col div.rt-value .current-value')->text, qr/^\s*F\s*$/, 'Got updated cf baz' );
    cmp_deeply(
        $dom->find('.jGrowl-message')->map('text')->to_array,
        bag( qq{E is no longer a value for custom field baz}, qq{F added as a value for baz}, ),
        'Got notification of changes'
    );
    $p->close_jgrowl;
}

diag "Testing description inline edit refresh";
{
    $p->{page}->click('div.ticket-info-description a.inline-edit-toggle');
    $p->submit_form_ok(
        {
            form   => 'div.ticket-info-description form.inline-edit',
            fields => {
                Description => 'Updated description',
            },
        },
        'Submit description inline edit'
    );
    $p->wait_for_notifications(1);

    # Wait for the inline-edit-display to refresh via its htmx GET request
    # (triggered by ticketBasicsChanged event) before reading the DOM
    $p->wait_for_element('div.ticket-info-description .inline-edit-display:has-text("Updated description")');

    my $dom = $p->dom;
    like( $dom->at('div.ticket-info-description .inline-edit-display')->all_text, qr/Updated description/, 'Display shows updated description' );

    $p->close_jgrowl;

    # Reopen inline edit — CKEditor should show the new value
    $p->{page}->click('div.ticket-info-description a.inline-edit-toggle');
    my $ck_content = $p->{page}->evaluate('return RT.CKEditor?.instances?.Description?.getData()');
    like( $ck_content, qr/Updated description/, 'CKEditor shows updated description (not stale value)' );
}

diag "Testing basics inline edit";
{
    $p->{page}->click('div.ticket-info-basics a.inline-edit-toggle');

    # Mark before submit so we can detect the mainContainerChanged reload
    $p->{page}->evaluate('document.querySelector("div.main-container").dataset.old = "1"');

    $p->submit_form_ok(
        {
            form   => 'div.ticket-info-basics form.inline-edit',
            fields => {
                Queue => $queue_foo->Id,
            },
        },
        'Submit basics inline edit with queue change'
    );

    $p->wait_for_notifications();
    $p->wait_for_element('div.ticket-info-basics .inline-edit-display div.queue:has-text("Foo")');

    my $dom = $p->dom;
    is( $dom->at('div.queue div.col div.rt-value .current-value a')->text, 'Foo', 'Got updated queue' );
    is_deeply(
        $dom->find('.jGrowl-message')->map('text')->to_array,
        [ qq{Ticket $ticket_id: Queue changed from General to Foo}, ],
        'Got notification of changes'
    );

    # Wait for mainContainerChanged to fully reload (outerHTML swap replaces the node)
    $p->wait_for_element('div.main-container:not([data-old])');
    $p->wait_for_htmx;

    # Check that Foo grouping is not set in queue Foo
    my $foo_grouping = $p->{page}->locator('div.ticket-info-cfs-Foo')->first();
    ok( $foo_grouping->count() == 0, 'Foo grouping is not set in queue Foo' );
}

diag "Testing inline edit on list page";
{
    $p->get_ok('/Search/Results.html?Query=id>0');

    # Hover over the editable element to show the edit icon
    my $subject_edit = $p->{page}->locator('div.editable')->first();
    $subject_edit->hover();

    # Click the edit icon
    my $edit_icon = $p->{page}->locator('div.editable .edit-icon')->first();
    $edit_icon->click();

    $p->submit_form_ok(
        {
            form   => 'div.editable form.editor',
            fields => {
                Subject => 'Test search result page',
            },
            button => '.submit',
        },
        'Submit subject change'
    );

    $p->wait_for_notifications();
    $p->wait_for_element(qq{div.editable a[href="/Ticket/Display.html?id=$ticket_id"]:has-text("Test search result page")});

    my $dom = $p->dom;
    is(
        $dom->at(qq{div.editable a[href="/Ticket/Display.html?id=$ticket_id"]})->text,
        'Test search result page',
        'Got updated subject'
    );

    is_deeply(
        $dom->find('.jGrowl-message')->map('text')->to_array,
        [qq{Ticket $ticket_id: Subject changed from 'Test inline edit updated' to 'Test search result page'}],
        'Got notification of changes'
    );
}

diag "Testing CF widget ColumnWidth configuration";
{
    # The test config uses legacy string format 'CustomFieldCustomGroupings'
    # Verify default rendering has no cf-columns class
    $p->goto_ticket($ticket_id);
    my $dom = $p->dom;
    my $show_cf = $dom->at('.show-custom-fields');
    ok($show_cf, 'Found show-custom-fields element');
    unlike($show_cf->attr('class'), qr/cf-columns-/, 'Legacy string config has no cf-columns class');

    # Navigate to page layout editor and verify Column Width dropdown exists
    $p->get_ok("$url/Admin/PageLayouts/Modify.html?Class=RT::Ticket&Page=Display&Name=Default");

    $dom = $p->dom;
    my $cw_select = $dom->at('select[name=ColumnWidth]');
    ok($cw_select, 'Column Width select exists in CF widget modal');

    my @options = $cw_select->find('option')->map(sub { { value => $_->attr('value'), text => $_->text } })->each;
    ok(scalar @options >= 5, 'Column Width has at least 5 options');
    ok((grep { $_->{value} eq 'xs' } @options), 'Has extra narrow option');
    ok((grep { $_->{value} eq 'sm' } @options), 'Has narrow option');
    ok((grep { $_->{value} eq '__empty_value__' } @options), 'Has default (medium) option');
    ok((grep { $_->{value} eq 'lg' } @options), 'Has wide option');
    ok((grep { $_->{value} eq 'xl' } @options), 'Has extra wide option');
}


diag "merged from ticket_links_click_edit.t";
{
    my $target = RT::Test->create_ticket( Queue => 'General', Subject => 'click-edit refers target' );
    my $ticket = RT::Test->create_ticket(
        Queue    => 'General',
        Subject  => 'click-edit links main',
        RefersTo => $target->id
    );
    is( $ticket->RefersTo->Count, 1, 'main ticket refers to the target' );

    $p->goto_ticket( $ticket->id );

    # Inline-editing a linked ticket's field in display mode must open that cell's own editor,
    # NOT hijack the click into the portlet's links-edit mode (init.js's click-to-edit handler
    # must skip clicks inside an inline-editable cell).
    my $cell = $p->{page}->locator('div.ticket-info-links .links-edit-target div.editable')->first();
    $cell->hover();
    $p->{page}->locator('div.ticket-info-links .links-edit-target div.editable .edit-icon')->first()->click();
    $p->wait_for_element('div.ticket-info-links .links-edit-target div.editable.editing form.editor');
    is( $p->{page}->locator('div.ticket-info-links.editing')->count(),
        0, 'editing a linked ticket cell does not toggle the portlet into links-edit mode' );

    # Verify the filter funnel's labels toggle their checkboxes, and that clicking inside the
    # filter does not trigger the portlet's click-to-edit.
    $p->goto_ticket( $ticket->id );
    $p->{page}->click('div.ticket-info-links a.links-filter');
    # One bar serves both display and edit; EditLinks renders it with Mode => 'edit', so the
    # filter-checkbox ids carry the '-edit' suffix (see Elements/LinksFilter).
    my $refers_cb = 'lf-rel-RefersTo-' . $ticket->id . '-edit';
    $p->wait_for_element(qq{div.ticket-info-links .links-filter-dropdown label[for="$refers_cb"]});
    is( $p->{page}->locator(qq{div.ticket-info-links #$refers_cb:checked})->count(),
        1, 'link-type checkbox starts checked' );
    $p->{page}->click(qq{div.ticket-info-links .links-filter-dropdown label[for="$refers_cb"]});
    is( $p->{page}->locator(qq{div.ticket-info-links #$refers_cb:checked})->count(),
        0, 'clicking the link-type label toggles its checkbox off' );
    is( $p->{page}->locator('div.ticket-info-links.editing')->count(),
        0, 'clicking a filter label does not enter links-edit mode' );

    # Reload to reset, then verify clicking a non-editable area still enters links-edit mode.
    $p->goto_ticket( $ticket->id );

    # Click a non-link, non-editable area of the portlet body (the relationship section label).
    $p->{page}->click('div.ticket-info-links .links-edit-target .links-section .label');

    # Clicking the body enters edit mode (the portlet is in 'click' behavior) via a pure .editing
    # CSS flip; the add-link form is already in the DOM (no fetch) and becomes visible.
    $p->wait_for_element('div.ticket-info-links.editing');
    $p->wait_for_element('div.ticket-info-links .edit-ticket-links .add-link-row');
    ok( 1, 'click-to-edit entered edit mode and revealed the eager add-link form' );

    # The single funnel lives in the title bar and still toggles its own checkbox while editing (the
    # bar is not re-rendered across the display<->edit flip, so its Mode-scoped ids are stable).
    $p->{page}->click('div.ticket-info-links a.links-filter');
    $p->wait_for_element(qq{div.ticket-info-links .links-filter-dropdown label[for="$refers_cb"]});
    is( $p->{page}->locator(qq{div.ticket-info-links #$refers_cb:checked})->count(),
        1, 'funnel link-type checkbox starts checked in edit mode' );
    $p->{page}->click(qq{div.ticket-info-links .links-filter-dropdown label[for="$refers_cb"]});
    is( $p->{page}->locator(qq{div.ticket-info-links #$refers_cb:checked})->count(),
        0, 'clicking the funnel label toggles its checkbox in edit mode' );

}

diag "merged from ticket_links_edit_js.t";
{
    my $ticket    = RT::Test->create_ticket( Queue => 'General', Subject => 'links edit js' );
    my $ticket_id = $ticket->Id;

    my $dep_target = RT::Test->create_ticket( Queue => 'General', Subject => 'exclude dep target' );
    my $dep_base   = RT::Test->create_ticket( Queue => 'General', Subject => 'exclude dep base' );
    $ticket->AddLink( Type => 'DependsOn', Target => $dep_target->id );    # DependsOn direction
    $ticket->AddLink( Type => 'DependsOn', Base   => $dep_base->id );      # DependedOnBy direction
    my ( $dt_id, $db_id ) = ( $dep_target->id, $dep_base->id );

    # EditLinks is a bare HTML fragment served by /Views/Component; in production the Links portlet
    # swaps it in via htmx, which fires htmx.onLoad and runs the links-editor init in util.js.
    # Reproduce that: load a real RT page (full JS bundle present), then htmx-swap the fragment in.
    $p->goto_ticket($ticket_id);

    my $component_url = "/Views/Component/EditLinks?ObjectType=RT::Ticket&ObjectId=$ticket_id";
    $p->{page}->evaluate(<<JS);
return (function() {
    const box = document.createElement('div');
    box.id = 'tle-test-host';
    document.querySelector('div.main-container').appendChild(box);
    htmx.ajax('GET', '$component_url', { target: '#tle-test-host', swap: 'innerHTML' });
})();
JS

    # Wait until htmx has swapped the fragment in and htmx.onLoad ran the add-links init in util.js
    # (initAddLinkRows sets the data-alr-init flag to "1" once it has bound its handlers).
    $p->wait_for_element('#tle-test-host .add-link-row');
    $p->{handle}->await( $p->{page}
            ->waitForFunction('document.querySelector("#tle-test-host .add-links-section")?.dataset.alrInit === "1"')
    );

    # The editor renders its Save right after the add-links rows.
    ok( $p->{page}->locator('#tle-test-host .links-edit-save')->count(),
        'editor renders the inline Save after the add-links rows' );

    diag "Testing autocomplete exclusion: a DependsOn/Ticket row excludes both-direction family members";
    {
        # Switch the first row to "Depends on" (canonical DependsOn, Target mode), then read its
        # data-autocomplete-exclude.
        $p->{page}->evaluate(<<'JS');
return (function() {
    const row = document.querySelector('#tle-test-host .add-link-row');
    const typeSel = row.querySelector('.link-type-select');
    const opt = Array.from(typeSel.options).find(function(o){ return o.dataset.type === 'DependsOn' && o.dataset.mode === 'Target'; });
    typeSel.value = opt.value;
    if (typeSel.tomselect) typeSel.tomselect.setValue(opt.value);
    else typeSel.dispatchEvent(new Event('change', { bubbles: true }));
})();
JS
        $p->{handle}->await( $p->{page}->waitForFunction(
            "(document.querySelector('#tle-test-host .add-link-row .link-value').getAttribute('data-autocomplete-exclude') || '').split(' ').indexOf('$dt_id') >= 0"
        ) );
        my $exclude = $p->{page}->evaluate(
            'return document.querySelector("#tle-test-host .add-link-row .link-value").getAttribute("data-autocomplete-exclude") || ""'
        );
        my %ids = map { $_ => 1 } split /\s+/, $exclude;
        ok( $ids{$dt_id}, "DependsOn row excludes the DependsOn target ($dt_id)" );
        ok( $ids{$db_id}, "DependsOn row excludes the DependedOnBy base ($db_id) -- both directions" );
    }

    diag "Testing dynamic update: switching the row to an unrelated family drops the exclusions";
    {
        # Switch to "Child of"/"Parent of" (canonical MemberOf) -- there are no member links, so
        # the DependsOn-family ids must no longer be excluded.
        $p->{page}->evaluate(<<'JS');
return (function() {
    const row = document.querySelector('#tle-test-host .add-link-row');
    const typeSel = row.querySelector('.link-type-select');
    const opt = Array.from(typeSel.options).find(function(o){ return o.dataset.type === 'MemberOf'; });
    typeSel.value = opt.value;
    if (typeSel.tomselect) typeSel.tomselect.setValue(opt.value);
    else typeSel.dispatchEvent(new Event('change', { bubbles: true }));
})();
JS
        $p->{handle}->await( $p->{page}->waitForFunction(
            "(document.querySelector('#tle-test-host .add-link-row .link-value').getAttribute('data-autocomplete-exclude') || '').split(' ').indexOf('$dt_id') < 0"
        ) );
        my $exclude = $p->{page}->evaluate(
            'return document.querySelector("#tle-test-host .add-link-row .link-value").getAttribute("data-autocomplete-exclude") || ""'
        );
        my %ids = map { $_ => 1 } split /\s+/, $exclude;
        ok( !$ids{$dt_id}, "MemberOf row no longer excludes the DependsOn target ($dt_id)" );
        ok( !$ids{$db_id}, "MemberOf row no longer excludes the DependedOnBy base ($db_id)" );
    }

    diag "Testing auto-append: typing in the last row appends a new blank row";
    {
        my $before = $p->{page}->evaluate('return document.querySelectorAll("#tle-test-host .add-link-row").length');
        ok( $before >= 2, "starts with at least two add rows (got $before)" );

        # Fill the last row's value field and fire an 'input' event so the JS runs.
        $p->{page}->evaluate(<<'JS');
return (function() {
    const rows = document.querySelectorAll('#tle-test-host .add-link-row');
    const input = rows[rows.length - 1].querySelector('.link-value');
    input.value = '1';
    input.dispatchEvent(new Event('input', { bubbles: true }));
})();
JS

        $p->{handle}->await( $p->{page}
                ->waitForFunction("document.querySelectorAll('#tle-test-host .add-link-row').length > $before") );
        my $after = $p->{page}->evaluate('return document.querySelectorAll("#tle-test-host .add-link-row").length');
        ok( $after > $before, "a new add row was appended ($before -> $after)" );
    }

    diag "Testing shorthand sync: typing 'a:7' switches the object-type dropdown to article";
    {
        # Use the first row so it's unaffected by the auto-append above.
        $p->{page}->evaluate(<<'JS');
return (function() {
    const row = document.querySelector('#tle-test-host .add-link-row');
    const input = row.querySelector('.link-value');
    input.value = 'a:7';
    input.dispatchEvent(new Event('input', { bubbles: true }));
})();
JS

        $p->{handle}->await(
            $p->{page}->waitForFunction(
                'document.querySelector("#tle-test-host .add-link-row .link-object-type-select").value === "article"')
        );
        my $object_type = $p->{page}
            ->evaluate('return document.querySelector("#tle-test-host .add-link-row .link-object-type-select").value');
        is( $object_type, 'article', "shorthand 'a:' switched the object-type dropdown to article" );
    }
}

diag "merged from links_children_tree_edit.t";
{
    my $q = RT::Test->load_or_create_queue( Name => 'General' );

    my $root  = RT::Test->create_ticket( Queue => 'General', Subject => 'tree root' );
    my $child = RT::Test->create_ticket( Queue => 'General', Subject => 'tree child' );
    my $grand = RT::Test->create_ticket( Queue => 'General', Subject => 'tree grandchild' );
    {
        my $t = RT::Ticket->new( RT->SystemUser );
        $t->Load( $root->id );
        $t->AddLink( Type => 'MemberOf', Base => $child->id );
        $t->Load( $child->id );
        $t->AddLink( Type => 'MemberOf', Base => $grand->id );
    }
    my $grand_id = $grand->id;

    $p->goto_ticket( $root->id );
    $p->wait_for_element( 'div.ticket-info-links .links-tree tr[data-record-id="' . $grand_id . '"][data-depth="2"]' );

    # Inline-edit the grandchild's Status field in the tree row. The tree table renders with
    # InlineEdit=1, so each editable cell is a div.editable.
    my $grand_row = 'div.ticket-info-links .links-tree tr[data-record-id="' . $grand_id . '"]';

    # Find the Status cell: the editable div that contains a form with select[name=Status].
    # (The Subject cell also has a form.editor but with a text input, not a select.)
    my $status_cell = $p->{page}->locator("$grand_row div.editable:has(form.editor select[name=Status])");
    $status_cell->hover();
    $status_cell->locator('.edit-icon')->click();
    $p->wait_for_element("$grand_row div.editable.editing form.editor");

    # Status uses TomSelect, which renders its dropdown outside the form (appended to body), so
    # locate the option there. Clicking it fires a change event that marks the editor changed and
    # auto-submits.
    $p->wait_for_element('.ts-dropdown .option[data-value=resolved]');
    $p->{page}->locator('.ts-dropdown .option[data-value=resolved]')->first()->click();
    $p->wait_for_htmx;

    $p->wait_for_element( 'div.ticket-info-links .links-tree tr[data-record-id="' . $grand_id . '"][data-depth="2"]' );
    is( $p->{page}
            ->locator( 'div.ticket-info-links .links-tree tr[data-record-id="' . $grand_id . '"] .links-tree-guide' )
            ->count(),
        1,
        'edited grandchild row keeps its tree guide'
      );
    is( $p->{page}
            ->locator( 'div.ticket-info-links .links-tree tr[data-record-id="' . $grand_id . '"].record-inactive' )
            ->count(),
        1,
        'edited grandchild row is marked inactive after resolving'
      );

    DBIx::SearchBuilder::Record::Cachable->FlushCache;
    my $reload = RT::Ticket->new( RT->SystemUser );
    $reload->Load($grand_id);
    is( $reload->Status, 'resolved', 'grandchild status persisted via inline edit in the tree' );

    # Regression: the delete control is a trash link (a.delete-link) in a separate trailing column
    # (each tree row's LAST <td>). The whole column is hidden in display mode; only depth-1 rows show
    # it in edit mode.
    my $child_id  = $child->id;
    my $child_uri = $child->URI;
    my $child_row = 'div.ticket-info-links .links-tree tr[data-record-id="' . $child_id . '"]';
    my $child_cb  = "$child_row td:last-child a.delete-link";

    my $is_visible = sub {
        my $sel = shift;
        return $p->{page}->evaluate(
            qq{return (function(){ const el = document.querySelector('$sel'); return el ? (el.offsetParent !== null) : null; })()} );
    };

    # Display mode (default): the trash-link column exists in the DOM but is hidden.
    $p->wait_for_element( qq{${child_row}[data-depth="1"]} );
    ok( !$is_visible->($child_cb), 'depth-1 child trash link is hidden in display mode' );

    my $grand_cb = 'div.ticket-info-links .links-tree tr[data-record-id="' . $grand_id . '"] td:last-child a.delete-link';
    ok( !$is_visible->($grand_cb), 'depth-2 grandchild trash link is hidden in display mode' );

    $p->{page}->click('div.ticket-info-links a.inline-edit-toggle.edit');
    $p->wait_for_element('div.ticket-info-links.editing');
    $p->wait_for_element($child_cb);
    ok( $is_visible->($child_cb), 'depth-1 child trash link is visible in edit mode' );

    # The trash link sits in the row's LAST <td>, a separate column from the id cell (.links-tree-id
    # lives on the column's content <div>, so locate its enclosing <td>).
    my $col_layout = $p->{page}->evaluate(<<JS);
return (function(){
    const row = document.querySelector('$child_row');
    if (!row) return null;
    const cells = Array.from(row.querySelectorAll(':scope > td'));
    const cb = row.querySelector('a.delete-link');
    const cbTd = cb ? cb.closest('td') : null;
    const idDiv = row.querySelector('.links-tree-id');
    const idTd = idDiv ? idDiv.closest('td') : null;
    return { cbTdIndex: cbTd ? cells.indexOf(cbTd) : -1, idTdIndex: idTd ? cells.indexOf(idTd) : -1 };
})();
JS
    is( $col_layout->{idTdIndex}, 0, 'depth-1 id cell is the leading column (td index 0)' );
    ok( $col_layout->{cbTdIndex} > $col_layout->{idTdIndex},
        'depth-1 trash link is a separate, trailing column after the id' );

    # In edit mode the depth-2 grandchild row is hidden entirely (only depth-1 children edit), so its
    # trash link is not visible even though the column exists.
    ok( !$is_visible->( 'div.ticket-info-links .links-tree tr[data-record-id="' . $grand_id . '"]' ),
        'depth-2 grandchild row is hidden in edit mode' );
    ok( !$is_visible->($grand_cb), 'depth-2 grandchild trash link is not visible in edit mode' );

    # The depth-1 trash link posts the child's DeleteLink param (the delete rides TicketUpdate).
    # hx-vals is JSON, which escapes '/' as '\/'; drop backslashes before matching the URI.
    ( my $hx_vals = $p->{page}->evaluate(
        qq{return (function(){ const el = document.querySelector('$child_cb'); return el ? el.getAttribute('hx-vals') : ''; })()} ) ) =~ s{\\}{}g;
    like( $hx_vals, qr/DeleteLink-\Q$child_uri\E-MemberOf-/,
        'depth-1 trash link hx-vals carries DeleteLink-<childURI>-MemberOf-' );
}

$p->logout;

done_testing;

use strict;
use warnings;
use Test::Deep;

use RT::Test tests => undef, selenium => 1, config => q{
    Set(%InlineEditPanelBehavior,
        'RT::Ticket' => {
            '_default' => 'link',
            'Dates' => 'always',
            'People' => 'click',
            'Foo' => 'hide',
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
};

my ( $url, $s ) = RT::Test->started_ok;

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

$s->login();

my $root = RT::Test->load_or_create_user( Name => 'root' );
my $ticket
    = RT::Test->create_ticket( Queue => 'General', Subject => 'Test inline edit', Requestor => 'root@localhost' );
my $ticket_id = $ticket->Id;

$s->goto_ticket($ticket_id);

my $dom = $s->dom;
is( $dom->at('#li-page-actions-open-it a')->text, 'Open It', 'Got "Open It" page menu' );
is( $dom->at('#li-page-actions-take a')->text, 'Take', 'Got "Take" page menu' );

diag "Testing basics inline edit";
{
    $s->click('div.ticket-info-basics a.inline-edit-toggle');
    $s->submit_form_ok(
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

    sleep 1.5;
    $s->title_is("#$ticket_id: Test inline edit updated");
    my $dom = $s->dom;
    is( $dom->at('#header h1')->text, "#$ticket_id: Test inline edit updated", 'Got updated subject in header' );
    is( $dom->at('div.status div.col div.rt-value .current-value')->text, 'open',         'Got updated status' );
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

    $s->close_jgrowl;
}

diag "Testing time inline edit";
{
    $s->click('div.ticket-info-times a.inline-edit-toggle');
    $s->submit_form_ok(
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

    sleep 1.5;
    $s->title_is("#$ticket_id: Test inline edit updated");
    my $dom = $s->dom;
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

    $s->close_jgrowl;
}

diag "Testing people inline edit";
{
    $s->click('div.ticket-info-people div.inline-edit-display');
    $s->submit_form_ok(
        {
            form   => 'div.ticket-info-people form.inline-edit',
            fields => {
                WatcherTypeEmail1                                            => 'Cc',
                WatcherAddressEmail1                                         => 'alice@example.com',
                WatcherTypeEmail2                                            => 'Requestor',
                WatcherAddressEmail2                                         => 'bob@example.com',
                Owner                                                        => $root->Id,
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

    sleep 1.5;
    my $dom = $s->dom;
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
    $s->close_jgrowl;
}


diag "Testing dates inline edit";
{
    $s->submit_form_ok(
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

    sleep 1.5;
    my $dom = $s->dom;

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
    $s->close_jgrowl;
}

diag "Testing links inline edit";
{
    my $depends_on1    = RT::Test->create_ticket( Queue => 'General', Subject => 'DependsOn 1' );
    my $depends_on2    = RT::Test->create_ticket( Queue => 'General', Subject => 'DependsOn 2' );
    my $depended_on_by = RT::Test->create_ticket( Queue => 'General', Subject => 'DependedOnby' );
    my $refers_to      = RT::Test->create_ticket( Queue => 'General', Subject => 'RefersTo' );
    my $referred_to_by = RT::Test->create_ticket( Queue => 'General', Subject => 'ReferredToBy' );
    my $parent         = RT::Test->create_ticket( Queue => 'General', Subject => 'Parent' );
    my $child          = RT::Test->create_ticket( Queue => 'General', Subject => 'Child' );

    $s->click('div.ticket-info-links a.inline-edit-toggle');
    $s->submit_form_ok(
        {
            form   => 'div.ticket-info-links form.inline-edit',
            fields => {
                "$ticket_id-DependsOn" => join( ' ', map { $_->Id } $depends_on1, $depends_on2 ),
                "DependsOn-$ticket_id" => $depended_on_by->Id,
                "$ticket_id-RefersTo"  => $refers_to->Id,
                "RefersTo-$ticket_id"  => $referred_to_by->Id,
                "$ticket_id-MemberOf"  => $parent->Id,
                "MemberOf-$ticket_id"  => $child->Id,
            },
        },
        'Submit links inline edit'
    );

    sleep 2;
    my $dom = $s->dom;
    is_deeply(
        $dom->find('div.DependsOn div.value .current-value a')->map( attr => 'href' ),
        [ "/Ticket/Display.html?id=@{[$depends_on1->Id]}", "/Ticket/Display.html?id=@{[$depends_on2->Id]}" ],
        'DependsOn ticket links'
    );

    is(
        $dom->at('div.DependedOnBy div.value .current-value a')->attr('href'),
        "/Ticket/Display.html?id=@{[$depended_on_by->Id]}",
        'DependedOnBy ticket link'
    );

    is(
        $dom->at('div.RefersTo div.value .current-value a')->attr('href'),
        "/Ticket/Display.html?id=@{[$refers_to->Id]}",
        'RefersTo ticket link'
    );

    is(
        $dom->at('div.ReferredToBy div.value .current-value a')->attr('href'),
        "/Ticket/Display.html?id=@{[$referred_to_by->Id]}",
        'ReferredToBy ticket link'
    );

    is(
        $dom->at('div.MemberOf div.value .current-value a')->attr('href'),
        "/Ticket/Display.html?id=@{[$parent->Id]}",
        'MemberOf ticket link'
    );

    is(
        $dom->at('div.Members div.value .current-value a')->attr('href'),
        "/Ticket/Display.html?id=@{[$child->Id]}",
        'Members ticket link'
    );

    is( $dom->at('div.dependency-status .summary')->all_text(), 'Pending 2 tickets.', 'Dependency status summary' );
    is(
        $dom->at('div.dependency-status .summary a')->attr('href'),
        q{/Search/Results.html?Query=Status%3D'__Active__'+AND+DependedOnBy+%3D+1},
        'Dependency status summary link'
    );

    cmp_deeply(
        $dom->find('.jGrowl-message')->map('text')->to_array,
        bag(
            "Ticket $ticket_id depends on Ticket @{[$depends_on1->Id]}.",
            "Ticket $ticket_id depends on Ticket @{[$depends_on2->Id]}.",
            "Ticket @{[$depended_on_by->Id]} depends on Ticket $ticket_id.",
            "Ticket $ticket_id member of Ticket @{[$parent->Id]}.",
            "Ticket @{[$child->Id]} member of Ticket $ticket_id.",
            "Ticket $ticket_id refers to Ticket @{[$refers_to->Id]}.",
            "Ticket @{[$referred_to_by->Id]} refers to Ticket $ticket_id.",
        ),
        'Got notification of changes'
    );
    $s->close_jgrowl;
}

diag "Testing custom fields grouping inline edit";
{
    $s->find_no_element_ok( selector_to_xpath('div.ticket-info-cfs-Foo form'),
        'Foo grouping does not have inline edit' );

    $s->click('div.ticket-info-cfs-Bar a.inline-edit-toggle');
    $s->submit_form_ok(
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

    sleep 1;
    my $dom = $s->dom;
    like( $dom->at('div.custom-field-bar1 div.col div.rt-value .current-value')->text, qr/^\s*B\s*$/, 'Got updated cf bar1' );
    like( $dom->at('div.custom-field-bar2 div.col div.rt-value .current-value')->text, qr/^\s*C\s*$/, 'Got updated cf bar2' );
    cmp_deeply(
        $dom->find('.jGrowl-message')->map('text')->to_array,
        bag( qq{bar1 B added}, qq{bar2 C added}, ),
        'Got notification of changes'
    );
    $s->close_jgrowl;
}

diag "Testing custom fields inline edit";
{
    my $edit_button = $s->click('div.ticket-info-cfs:not(.ticket-info-cfs-Bar) a.inline-edit-toggle');
    $s->submit_form_ok(
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

    sleep 1;
    my $dom = $s->dom;
    like( $dom->at('div.custom-field-baz div.col div.rt-value .current-value')->text, qr/^\s*E\s*$/, 'Got updated cf baz' );
    is_deeply(
        $dom->find('.jGrowl-message')->map('text')->to_array,
        [ qq{E added as a value for baz}, ],
        'Got notification of changes'
    );
    $s->close_jgrowl;

    $edit_button->click;
    $s->submit_form_ok(
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
    sleep 1;
    $dom = $s->dom;
    like( $dom->at('div.custom-field-baz div.col div.rt-value .current-value')->text, qr/^\s*F\s*$/, 'Got updated cf baz' );
    cmp_deeply(
        $dom->find('.jGrowl-message')->map('text')->to_array,
        bag( qq{E is no longer a value for custom field baz}, qq{F added as a value for baz}, ),
        'Got notification of changes'
    );
    $s->close_jgrowl;
}

diag "Testing basics inline edit";
{
    $s->click('div.ticket-info-basics a.inline-edit-toggle');
    $s->submit_form_ok(
        {
            form   => 'div.ticket-info-basics form.inline-edit',
            fields => {
                Queue => $queue_foo->Id,
            },
        },
        'Submit basics inline edit with queue change'
    );

    sleep 1;
    my $dom = $s->dom;
    is( $dom->at('div.queue div.col div.rt-value .current-value a')->text, 'Foo', 'Got updated queue' );
    is_deeply(
        $dom->find('.jGrowl-message')->map('text')->to_array,
        [ qq{Ticket $ticket_id: Queue changed from General to Foo}, ],
        'Got notification of changes'
    );
    sleep 4;    # wait for the page reload
    $s->find_no_element_ok( selector_to_xpath('div.ticket-info-cfs-Foo'), 'Foo grouping is not set in queue Foo' );
}

diag "Testing inline edit on list page";
{
    $s->get_ok('/Search/Results.html?Query=id>0');
    my $subject_edit = $s->find_element( selector_to_xpath('div.editable') );
    $s->move_to( element => $subject_edit );
    $subject_edit->click;    # this lets mouse really move to the element

    my $edit_icon = $s->find_element( selector_to_xpath('div.editable .edit-icon') );
    $edit_icon->click;

    $s->submit_form_ok(
        {
            form   => 'div.editable form.editor',
            fields => {
                Subject => 'Test search result page',
            },
            button => '.submit',
        },
        'Submit subject change'
    );

    sleep 1;
    my $dom = $s->dom;
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

$s->logout;

done_testing;

use strict;
use warnings;

use RT::Test tests => undef;
use RT::Interface::Web;

# Create two queues
my $queue1 = RT::Test->load_or_create_queue(Name => 'TestQueue1');
my $queue2 = RT::Test->load_or_create_queue(Name => 'TestQueue2');

# Create a custom field applied only to Queue1
my $cf = RT::CustomField->new(RT->SystemUser);
my ($cf_id, $msg) = $cf->Create(
    Name       => 'State',
    Type       => 'Select',
    LookupType => RT::Ticket->CustomFieldLookupType,
);
ok($cf_id, "Created custom field: $msg");

$cf->AddValue(Name => 'New York');
$cf->AddValue(Name => 'Massachusetts');
$cf->AddValue(Name => 'Pennsylvania');

# Apply CF only to Queue1
my ($status, $apply_msg) = $cf->AddToObject($queue1);
ok($status, "Applied CF to Queue1: $apply_msg");

my $mapping = RT->Config->Get('PageLayoutMapping') || {};
push @{ $mapping->{'RT::Ticket'}{'Display'} },
    {
        Type   => 'CustomField.{State}',
        Layout => {
            'New York'   => 'NY Layout',
        }
    };

my ($ret, $update_msg) = HTML::Mason::Commands::UpdateConfig(
    Name => 'PageLayoutMapping',
    Value => $mapping,
    CurrentUser => RT->SystemUser
);
ok($ret, "Updated PageLayoutMapping config");

my ($baseurl, $m) = RT::Test->started_ok( disable_config_cache => 1 );
ok $m->login, 'logged in as root';

{
    my $ticket1 = RT::Test->create_ticket(
        Queue   => $queue1->Name,
        Subject => 'Test ticket in Queue1',
    );
    $m->goto_ticket($ticket1->Id);
}

{
    my $ticket2 = RT::Test->create_ticket(
        Queue   => $queue2->Name,
        Subject => 'Test ticket in Queue2',
    );
    $m->goto_ticket($ticket2->Id);
}

diag "Testing CF widget ColumnWidth rendering";
{
    # Default layout with no ColumnWidth — should have no cf-columns class
    my $ticket = RT::Test->create_ticket(
        Queue   => $queue1->Name,
        Subject => 'Test CF column width',
    );
    $m->goto_ticket($ticket->Id);
    $m->content_like(qr/class="show-custom-fields"/, 'Default layout has show-custom-fields class');
    $m->content_unlike(qr/cf-columns-/, 'Default layout has no cf-columns class');

    # Update PageLayouts to include ColumnWidth => 'sm'
    my ($ret2, $msg2) = HTML::Mason::Commands::UpdateConfig(
        Name => 'PageLayouts',
        Value => {
            'RT::Ticket' => {
                'Display' => {
                    Default => [
                        {
                            Layout   => 'col-md-6',
                            Title    => 'Ticket metadata',
                            Elements => [
                                [ 'Basics', { Name => 'CustomFieldCustomGroupings', ColumnWidth => 'sm' } ],
                                [ 'Dates', 'Links' ],
                            ],
                        },
                        {
                            Layout   => 'col-12',
                            Elements => ['History'],
                        },
                    ],
                },
            },
        },
        CurrentUser => RT->SystemUser,
    );
    ok($ret2, "Updated PageLayouts with ColumnWidth");

    $m->goto_ticket($ticket->Id);
    $m->content_like(qr/class="show-custom-fields cf-columns-sm"/, 'ColumnWidth sm renders cf-columns-sm class');
    $m->content_unlike(qr/class="show-custom-fields[^"]*cf-columns-(?!sm)/, 'No other cf-columns classes present');
}

diag "Links widget applies a configured default filter (ticket)";
{
    my $q = RT::Test->load_or_create_queue( Name => 'General' );
    my $active   = RT::Test->create_ticket( Queue => $q->Name, Subject => 'lw active dep' );
    my $resolved = RT::Test->create_ticket( Queue => $q->Name, Subject => 'lw resolved dep' );
    $resolved->SetStatus('resolved');
    my $main = RT::Test->create_ticket( Queue => $q->Name, Subject => 'lw main' );
    $main->AddLink( Type => 'DependsOn', Target => $active->id );
    $main->AddLink( Type => 'DependsOn', Target => $resolved->id );

    my ($ok, $msg) = HTML::Mason::Commands::UpdateConfig(
        Name  => 'PageLayouts',
        Value => {
            'RT::Ticket' => {
                'Display' => {
                    Default => [
                        { Layout => 'col-12', Elements => [ { Name => 'Links', HideInactive => 1 } ] },
                    ],
                },
            },
        },
        CurrentUser => RT->SystemUser,
    );
    ok( $ok, "configured Links HideInactive default" ) or diag $msg;

    $m->goto_ticket( $main->id );
    $m->content_contains( 'lw active dep', 'active dependency is shown' );

    # With LinksListCount set, the first render applies the default on the server and marks the
    # list partial; the client loads the resolved row if the filter is cleared (util.js). The
    # funnel pre-checks Hide-inactive to reflect the configured default.
    $m->content_lacks( 'lw resolved dep', 'resolved dependency is held back by the default' );
    $m->content_like( qr/data-links-partial="1"/, 'links list is marked partial' );
    $m->content_like( qr/name="HideInactive"[^>]*\bchecked/, 'funnel Hide-inactive box reflects the default' );
}

diag "Links widget ListCount overrides LinksListCount";
{
    my $q    = RT::Test->load_or_create_queue( Name => 'General' );
    my $main = RT::Test->create_ticket( Queue => $q->Name, Subject => 'lw list count main' );
    for my $n ( 1 .. 4 ) {
        my $dep = RT::Test->create_ticket( Queue => $q->Name, Subject => "lw list count dep $n" );
        $main->AddLink( Type => 'DependsOn', Target => $dep->id );
    }

    my ($ok, $msg) = HTML::Mason::Commands::UpdateConfig(
        Name  => 'PageLayouts',
        Value => {
            'RT::Ticket' => {
                'Display' => {
                    Default => [
                        { Layout => 'col-12', Elements => [ { Name => 'Links', ListCount => 2 } ] },
                    ],
                },
            },
        },
        CurrentUser => RT->SystemUser,
    );
    ok( $ok, "configured Links ListCount" ) or diag $msg;

    $m->goto_ticket( $main->id );
    my $section = $m->dom->at('#links-section-DependsOn');
    is( $section->find('tbody tr')->size, 2, 'the layout ListCount caps the section' );
    like( $section->at('button.links-show-all')->text, qr/Show all \(4\)/, 'and offers all of them' );
    $m->content_like( qr{hx-get="[^"]*/Views/Component/ShowLinks\?[^"]*ListCount=2}, 'the refresh URL keeps the cap' );
}

diag "Add links default type: user preference, then page layout, then LinksDefaultType";
{
    my $main = RT::Test->create_ticket( Queue => 'General', Subject => 'lw default type main' );
    my $selected = sub {
        [ map { $_->attr('value') } $m->dom->find('.add-link-row .link-type-select option[selected]')->each ];
    };
    my $create_selected = sub {
        my $option = $m->dom->at('#create-linked-ticket select[name="LinkType"] option[selected]');
        return $option ? $option->attr('value') : '';
    };
    my $id = $main->id;

    $m->goto_ticket($id);
    is_deeply( $selected->(), [ "$id-RefersTo", "$id-RefersTo" ], 'both add rows default to Refers to' );
    is( $create_selected->(), 'RefersTo-new', 'Create new defaults to Refers to too' );
    is( $m->dom->find('.add-link-row .link-type-select option[data-default]')->map( attr => 'value' )->join(',')->to_string,
        "$id-RefersTo,$id-RefersTo", 'each row marks the default for rows added in the browser' );

    my ($ok, $msg) = HTML::Mason::Commands::UpdateConfig(
        Name  => 'PageLayouts',
        Value => {
            'RT::Ticket' => {
                'Display' => {
                    Default => [
                        { Layout => 'col-12', Elements => [ { Name => 'Links', DefaultType => 'DependsOn' } ] },
                    ],
                },
            },
        },
        CurrentUser => RT->SystemUser,
    );
    ok( $ok, "configured Links DefaultType" ) or diag $msg;

    $m->goto_ticket($id);
    is_deeply( $selected->(), [ "$id-DependsOn", "$id-DependsOn" ], 'the page layout DefaultType selects Depends on' );
    is( $create_selected->(), 'DependsOn-new', 'Create new follows the page layout DefaultType' );
    $m->content_like( qr{hx-get="[^"]*/Views/Component/EditLinks\?[^"]*DefaultType=DependsOn}, 'the refresh URL keeps the default' );

    $m->get_ok( "$baseurl/Prefs/Other.html", 'load preferences' );
    $m->submit_form_ok( { form_name => 'ModifyPreferences', fields => { LinksDefaultType => 'MemberOf' }, button => 'Update' },
        'set a Child of preference' );

    $m->goto_ticket($id);
    is_deeply( $selected->(), [ "$id-MemberOf", "$id-MemberOf" ], 'the user preference wins over the page layout' );
    is( $create_selected->(), 'MemberOf-new', 'Create new follows the preference: the new ticket is the parent' );
    $m->submit_form_ok( { form_name => 'SpawnLinkedTicket', button => 'SpawnLinkedTicket' }, 'create a linked ticket with the default' );
    $m->submit_form_ok( { form_name => 'TicketCreate', fields => { Subject => 'lw default type parent' }, button => 'SubmitTicket' },
        'create the new ticket' );
    my $parents = $main->MemberOf;
    my $parent  = $parents->First;
    is( $parent && $parent->TargetObj->Subject, 'lw default type parent', 'the new ticket is the parent, matching a Child of default' );

    $m->get_ok( "$baseurl/Ticket/ModifyAll.html?id=$id", 'load the Jumbo page' );
    is_deeply( $selected->(), [ "$id-MemberOf", "$id-MemberOf" ], 'the preference applies outside the page layout too' );

    $m->get_ok( "$baseurl/Prefs/Other.html", 'load preferences' );
    $m->submit_form_ok( { form_name => 'ModifyPreferences', fields => { LinksDefaultType => '__empty_value__' }, button => 'Update' },
        'clear the preference' );

    $m->goto_ticket($id);
    is_deeply( $selected->(), [ "$id-DependsOn", "$id-DependsOn" ], 'without a preference the page layout applies again' );
    is( $create_selected->(), 'DependsOn-new', 'Create new follows the page layout again' );
}

diag "EditPageLayout renders the Links widget edit modal reflecting config";
{
    my ($ok, $msg) = HTML::Mason::Commands::UpdateConfig(
        Name  => 'PageLayouts',
        Value => {
            'RT::Ticket' => {
                'Display' => {
                    Default => [
                        { Layout => 'col-12',
                          Elements => [ { Name => 'Links', HideInactive => 1, ShowObjectType => ['Ticket'], ListCount => 7, DefaultType => 'ReferredToBy' } ] },
                    ],
                },
                'Create' => {
                    Default => [ { Layout => 'col-12', Elements => ['Links'] } ],
                },
            },
        },
        CurrentUser => RT->SystemUser,
    );
    ok( $ok, "configured Links widget for the editor" ) or diag $msg;

    $m->get_ok( "$baseurl/Admin/PageLayouts/Modify.html?Class=RT::Ticket&Page=Display&Name=Default",
        'load the ticket Display page-layout editor' );

    # The placed (configured) widget is element index 0; its modal checkboxes carry the -0 suffix,
    # which distinguishes it from the always-all-checked palette modal (suffixed -Links).
    $m->content_like( qr/id="pagelayout-links-hide-inactive-0"[^>]*\bchecked/, 'placed modal Hide-inactive reflects config' );
    $m->content_like( qr/id="pagelayout-links-ot-Ticket-0"[^>]*\bchecked/, 'placed modal Ticket object-type checked' );
    $m->content_unlike( qr/id="pagelayout-links-ot-Asset-0"[^>]*\bchecked/, 'placed modal Asset object-type unchecked' );
    ok( $m->dom->at('#pagelayout-widget-0-modal input[name="ListCount"][value="7"]'), 'placed modal ListCount reflects config' );
    ok( $m->dom->at('#pagelayout-widget-Links-modal input[name="ListCount"][value=""][placeholder="Default: 10"]'),
        'palette modal ListCount is empty, showing the LinksListCount default' );
    ok( $m->dom->at('#pagelayout-widget-0-modal select[name="DefaultType"] option[value="ReferredToBy"][selected]'),
        'placed modal DefaultType reflects config' );
    ok( $m->dom->at('#pagelayout-widget-Links-modal select[name="DefaultType"] option[value="__empty_value__"][selected]'),
        'palette modal DefaultType uses the default' );
    like( $m->dom->at('#pagelayout-widget-Links-modal select[name="DefaultType"] option[value="__empty_value__"]')->text,
        qr/Default: Refers to/, 'and names the LinksDefaultType default' );

    # The Links item in "Available Widgets" carries the edit pencil so a dragged-in widget is configurable.
    $m->content_like( qr{data-bs-target="#pagelayout-widget-Links-modal"},
        'Links palette item has the edit pencil' );

    # The default filter applies to the Display layout only -- the Create editor offers no Links config.
    $m->get_ok( "$baseurl/Admin/PageLayouts/Modify.html?Class=RT::Ticket&Page=Create&Name=Default",
        'load the ticket Create page-layout editor' );
    $m->content_lacks( 'pagelayout-links-hide-inactive', 'Create: no Links default-filter modal' );
    $m->content_lacks( 'pagelayout-widget-Links-modal', 'Create: no Links edit pencil' );
}

done_testing;

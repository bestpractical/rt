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

    # Filtering is now client-side (util.js): the resolved row IS in the server HTML (the client
    # hides it), and the funnel pre-checks Hide-inactive to reflect the configured default.
    $m->content_contains( 'lw resolved dep', 'resolved dependency is rendered (hidden client-side)' );
    $m->content_like( qr/name="HideInactive"[^>]*\bchecked/, 'funnel Hide-inactive box reflects the default' );
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
                          Elements => [ { Name => 'Links', HideInactive => 1, ShowObjectType => ['Ticket'] } ] },
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

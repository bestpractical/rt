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

diag "Testing Assets widget visibility: driven by page layout, hidden when completely empty";
{
    ( $ret, $msg ) = HTML::Mason::Commands::UpdateConfig(
        Name  => 'PageLayouts',
        Value => {
            'RT::Ticket' =>
                { Display => { Default => [ { Layout => 'col-12', Elements => [ [ 'Basics', 'Assets' ] ] } ] } }
        },
        CurrentUser => RT->SystemUser,
    );
    ok( $ret, "Set a layout that includes the Assets widget" );

    my $asset = RT::Asset->new( RT->SystemUser );
    ( $ret, $msg ) = $asset->Create( Catalog => 'General assets', Name => 'PageLayout Asset Widget Test' );
    ok( $ret, "Created an asset: $msg" );

    my $ticket = RT::Test->create_ticket(
        Queue   => $queue1->Name,
        Subject => 'Ticket for Assets widget visibility',
    );

    # root can ModifyTicket, so the widget shows (with the add form) even with no linked assets
    $m->goto_ticket( $ticket->Id );
    $m->content_contains( 'ticket-assets', 'Assets widget shows for a user who can add assets, even with none linked' );
    $m->content_contains( 'Add an asset to this ticket', 'Add-asset form present for a ModifyTicket user' );

    # a user who can see the ticket but not modify it
    my $viewer = RT::Test->load_or_create_user( Name => 'asset_viewer', Password => 'password' );
    ok( $viewer->id, "Created a read-only user" );
    RT::Test->add_rights(
        { Principal => $viewer, Right => [qw/SeeQueue ShowTicket/],   Object => $queue1 },
        { Principal => $viewer, Right => [qw/ShowCatalog ShowAsset/], Object => $asset->CatalogObj },
    );

    my $viewer_m = RT::Test::Web->new;
    ok( $viewer_m->login( 'asset_viewer', 'password' ), 'logged in as the read-only user' );

    $viewer_m->get_ok( "/Ticket/Display.html?id=" . $ticket->Id );
    $viewer_m->content_lacks( 'ticket-assets',
        'Assets widget is hidden for a read-only user when the ticket has no linked assets' );

    ok( $ticket->AddLink( Type => 'RefersTo', Target => $asset->URI ), 'Linked the asset to the ticket' );

    $viewer_m->get_ok( "/Ticket/Display.html?id=" . $ticket->Id );
    $viewer_m->content_contains( 'ticket-assets', 'Assets widget shows to the read-only user once an asset is linked' );
    $viewer_m->content_contains( 'PageLayout Asset Widget Test', 'Linked asset appears for the read-only user' );
    $viewer_m->content_lacks( 'Add an asset to this ticket', 'No add-asset form without ModifyTicket' );

    # removing the widget from the layout hides it even with a linked asset
    ( $ret, $msg ) = HTML::Mason::Commands::UpdateConfig(
        Name  => 'PageLayouts',
        Value =>
            { 'RT::Ticket' => { Display => { Default => [ { Layout => 'col-12', Elements => [ ['Basics'] ] } ] } } },
        CurrentUser => RT->SystemUser,
    );
    ok( $ret, "Set a layout that excludes the Assets widget" );

    $m->goto_ticket( $ticket->Id );
    $m->content_lacks( 'ticket-assets', 'Assets widget hidden when removed from the layout, despite a linked asset' );
}

diag "Testing Assets widget on the ticket create page";
{
    ( $ret, $msg ) = HTML::Mason::Commands::UpdateConfig(
        Name  => 'PageLayouts',
        Value => {
            'RT::Ticket' => {
                Create => {
                    Default =>
                        [ { Layout => 'col-12', Elements => [ [ 'Basics', 'Assets', 'Message', 'Submit' ] ] } ]
                }
            }
        },
        CurrentUser => RT->SystemUser,
    );
    ok( $ret, "Set a create layout that includes the Assets widget" );

    my $asset = RT::Asset->new( RT->SystemUser );
    ( $ret, $msg ) = $asset->Create( Catalog => 'General assets', Name => 'Create Page Asset' );
    ok( $ret, "Created an asset: $msg" );

    # an ordinary create has no linked assets, so the widget is hidden even though root can add assets
    $m->get_ok( "/Ticket/Create.html?Queue=" . $queue1->Id );
    $m->content_lacks( 'ticket-assets',
        'Assets widget hidden on an ordinary create, even for a user who can add assets' );

    # the real flow: "Create linked ticket" from an asset lands on a create form with the asset pre-linked
    $m->get_ok( "/Asset/CreateLinkedTicket.html?Asset=" . $asset->id );
    $m->submit_form_ok( { form_id => 'AssetCreateLinkedTicket' }, "submitted the create-linked-ticket form" );
    $m->content_contains( 'ticket-assets',     'Assets widget shows on the create form reached from an asset' );
    $m->content_contains( 'Create Page Asset', 'the linked asset appears on that create form' );
}

done_testing;

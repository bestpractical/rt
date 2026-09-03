use strict;
use warnings;

# %PageLayouts merges recursively, so this adds a layout whose name the admin UI
# would reject, the way a site config file can
use RT::Test
    tests  => undef,
    config => q{
Set( %PageLayouts,
    'RT::Ticket' => {
        'Display' => {
            'Foo & Bar' => [ { Layout => 'col-12', Elements => ['Basics'] } ],
        },
    },
);
};
use RT::Interface::Web;
use URI;

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

my ($baseurl, $m) = RT::Test->started_ok;
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

diag "Testing page layout name validation";
{
    my $invalid_msg
        = 'Page Layout Name may only contain alphanumeric characters, underscores, dashes, and spaces';

    $m->get_ok('/Admin/PageLayouts/Create.html');
    $m->submit_form_ok(
        {   form_name => 'CreatePageLayout',
            fields    => { Name => 'Bad & Name', Class => 'RT::Ticket', Page => 'Display' },
            button    => 'Create',
        },
        'Submitted create form with an ampersand in the name'
    );
    $m->text_contains( $invalid_msg, 'Rejected a name containing an ampersand' );

    # Non-ASCII letters are not alphanumeric for this purpose
    $m->get_ok('/Admin/PageLayouts/Create.html');
    $m->submit_form_ok(
        {   form_name => 'CreatePageLayout',
            fields    => { Name => 'Caf\x{e9}', Class => 'RT::Ticket', Page => 'Display' },
            button    => 'Create',
        },
        'Submitted create form with a non-ASCII name'
    );
    $m->text_contains( $invalid_msg, 'Rejected a name containing a non-ASCII letter' );

    # Spaces are allowed, as RT ships a layout named "One Column"
    for my $name ( 'One Column 2', 'Foo-Bar_1' ) {
        $m->get_ok('/Admin/PageLayouts/Create.html');
        $m->submit_form_ok(
            {   form_name => 'CreatePageLayout',
                fields    => { Name => $name, Class => 'RT::Ticket', Page => 'Display' },
                button    => 'Create',
            },
            "Submitted create form for '$name'"
        );
        $m->text_contains( 'Page Layout created', "Created page layout '$name'" );
    }

    # Renaming is validated too
    $m->submit_form_ok(
        {   with_fields => { NewName => 'Bad & Name' },
            button      => 'UpdatePage',
        },
        'Submitted rename form with an ampersand in the name'
    );
    $m->text_contains( $invalid_msg, 'Rejected a rename to a name containing an ampersand' );

    $m->get_ok('/Admin/PageLayouts/?Class=RT::Ticket&Page=Display');
    $m->text_contains( 'Foo-Bar_1', 'Layout kept its original name' );
    $m->text_lacks( 'Bad &', 'Rejected name was not created' );
}

diag "Testing page layout names containing an ampersand";
{
    my $name = 'Foo & Bar';

    # Pull the Name argument back out of a URL the way a browser would send it
    my $name_arg = sub {
        my %args = URI->new( shift )->query_form;
        return $args{Name};
    };


    # The list page links to each layout by name
    $m->get_ok('/Admin/PageLayouts/?Class=RT::Ticket&Page=Display');
    my $list_link = $m->find_link( text => $name, url_regex => qr{/Admin/PageLayouts/Modify\.html} );
    ok( $list_link, "Found the list link for '$name'" );
    is( $name_arg->( $list_link->url ), $name, 'List link passes the name unmangled' );

    # Load Modify.html directly with a correctly encoded name, so the page menu
    # links below are tested independently of the list page
    my $modify_uri = URI->new('/Admin/PageLayouts/Modify.html');
    $modify_uri->query_form( Class => 'RT::Ticket', Page => 'Display', Name => $name );
    $m->get_ok( $modify_uri->as_string );
    $m->text_contains( "page layout: $name", 'Modify page loaded the right layout' );

    for my $page (qw/Modify Advanced/) {
        my $tab = $m->find_link( url_regex => qr{/Admin/PageLayouts/\Q$page\E\.html} );
        ok( $tab, "Found the $page tab link" );
        is( $name_arg->( $tab->url ), $name, "$page tab link passes the name unmangled" );
    }

    my $advanced = $m->find_link( url_regex => qr{/Admin/PageLayouts/Advanced\.html} );
    $m->get_ok( $advanced->url_abs );
    $m->text_lacks( 'Invalid Page Layout', 'Advanced tab loaded the right layout' );
    $m->text_contains( "page layout: $name", 'Advanced page shows the right layout name' );
}

done_testing;

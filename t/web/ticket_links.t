use strict;
use warnings;
use RT::Test::Assets tests => undef, config => q{Set(%CustomFieldGroupings, 'RT::Ticket' => { 'Links' => ['linkcf'] });};
use JSON qw(from_json);

my ( $baseurl, $m ) = RT::Test->started_ok;
ok( $m->login, "Logged in" );

my $queue = RT::Test->load_or_create_queue( Name => 'General' );
ok( $queue->id, "loaded the General queue" );

# Create a new queue
my $queue_2 = RT::Test->load_or_create_queue( Name => 'NewQueue');
ok( $queue_2->id, "New queue created, 'NewQueue'");

# Create a new ticket
$m->get_ok($baseurl . '/Ticket/Create.html?Queue=1');
$m->form_name('TicketCreate');
$m->field(Subject => 'testing new ticket');
$m->click_button(value => 'Create');

# Set NewQueue as default queue
$m->get_ok($baseurl . '/Prefs/Other.html');
$m->submit_form_ok({
  form_name => 'ModifyPreferences',
  fields => {
    DefaultQueue => 'NewQueue',
  },
  button => 'Update'
}, 'NewQueue set as default queue');

# Verify NewQueue is the default queue on ticket page
$m->get_ok($baseurl . '/Ticket/Display.html?id=1');
my $selected_queue_node = $m->dom->at('select[name=CloneQueue] option:checked');
if ($selected_queue_node) {
    is($selected_queue_node->all_text, 'NewQueue');
}
else {
    fail("no selected queue for clone queue");
}

my ( $deleted, $active, $inactive ) = RT::Test->create_tickets(
    { Queue   => 'General' },
    { Subject => 'deleted ticket', },
    { Subject => 'active ticket', },
    { Subject => 'inactive ticket', }
);

my ( $deleted_id, $active_id, $inactive_id ) = ( $deleted->id, $active->id, $inactive->id );

$deleted->SetStatus('deleted');
is( $deleted->Status, 'deleted', "deleted $deleted_id" );

$inactive->SetStatus('resolved');
is( $inactive->Status, 'resolved', 'resolved $inactive_id' );

# Create an article for linking
require RT::Class;
my $class = RT::Class->new($RT::SystemUser);
$class->Create(Name => 'test class');

require RT::Article;
my $article = RT::Article->new($RT::SystemUser);

$article->Create(Class => $class->Id, Name => 'test article');

for my $type ( "DependsOn", "MemberOf", "RefersTo" ) {
    for my $c (qw/base target/) {
        my $id;

        diag "create ticket with links of type $type $c";
        {
            ok( $m->goto_create_ticket($queue), "go to create ticket" );
            $m->form_name('TicketCreate');
            $m->field( Subject => "test ticket creation with $type $c" );
            if ( $c eq 'base' ) {
                $m->field( "new-$type", "$deleted_id $active_id $inactive_id" );
            }
            else {
                $m->field( "$type-new", "$deleted_id $active_id $inactive_id" );
            }

            $m->click('SubmitTicket');
            $m->content_like(qr/Ticket \d+ created/, 'created ticket');
            $m->content_contains("Linking to a deleted ticket is not allowed");
            $id = RT::Test->last_ticket->id;
        }

        diag "add ticket links of type $type $c";
        {
            my $ticket = RT::Test->create_ticket(
                Queue   => 'General',
                Subject => "test $type $c",
            );
            $id = $ticket->id;

            # The links editor is now a JS-driven row UI, so add links via the API rather than the
            # form. The deleted-ticket rejection is covered by the create-time block above.
            my $t = RT::Ticket->new( RT->SystemUser );
            $t->Load($id);
            for my $target ( $active_id, $inactive_id ) {
                my ( $ok, $msg )
                    = $c eq 'base'
                    ? $t->AddLink( Type => $type, Target => $target )
                    : $t->AddLink( Type => $type, Base   => $target );
                ok( $ok, "$c $type link to ticket $target: $msg" );
            }
        }

        $m->goto_ticket($id);

        # Match via the per-row inline-edit SelectStatus <option> text ("new (Unchanged)"), not
        # the StatusBadge.
        $m->content_like( qr{data-record-id="$active_id".*?>new \&\#40;Unchanged\&\#41;<}s, "has active ticket", );
        $m->content_like(
            qr{data-record-id="$inactive_id".*?>resolved \&\#40;Unchanged\&\#41;<}s,
            "has inactive ticket",
        );
        $m->content_unlike( qr{data-record-id="$deleted_id"}, "no deleted ticket", );

        diag "[$type]: Testing that reminders don't get copied for $c tickets";
        {
            my $ticket = RT::Test->create_ticket(
                Subject => 'test ticket',
                Queue   => 1,
            );

            $m->goto_ticket($ticket->Id);
            $m->form_name('UpdateReminders');
            $m->field('NewReminder-Subject' => 'hello test reminder subject');
            $m->click_button(value => 'Save');
            $m->text_contains('hello test reminder subject');

            my $id = $ticket->Id;
            my $type_value = my $link_field = $type;
            if ($c eq 'base') {
                $type_value = "new-$type_value";
                $link_field    = "$link_field-$id";
            }
            else {
                $type_value = "$type_value-new";
                $link_field = "$id-$link_field";
            }

            if ($type eq 'RefersTo') {
                $m->goto_ticket($ticket->Id);
                $m->follow_link(id => 'page-jumbo');

                # add $baseurl as a link
                $m->form_name('TicketModifyAll');
                $m->field($link_field => "$baseurl/test_ticket_reference");
                $m->click('SubmitTicket');

                # add an article as a link
                $m->form_name('TicketModifyAll');
                $m->field($link_field => 'a:' . $article->Id);
                $m->click('SubmitTicket');
            }

            my $depends_on_url = sprintf( '%s/Ticket/Create.html?Queue=%s&CloneTicket=%s&%s=%s',
                $baseurl, '1', $id, $type_value, $id, );
            $m->get_ok($depends_on_url);
            $m->form_name('TicketCreate');
            $m->click_button(value => 'Create');
            $m->content_lacks('hello test reminder subject');
            if ($type eq 'RefersTo') {
                $m->text_contains("$baseurl/test_ticket_reference");

                $m->text_contains('test article');
            }
        }
    }
}

diag "merged from ticket_links_display.t";
{
    my $q = RT::Test->load_or_create_queue( Name => 'General' );

    my ( $dep, $ref ) = RT::Test->create_tickets(
        { Queue   => $q->id },
        { Subject => 'depends target' },
        { Subject => 'refers target' },
    );

    my ($main) = RT::Test->create_tickets( { Queue => $q->id }, { Subject => 'main ticket' }, );
    {
        my ( $ok, $msg ) = $main->AddLink( Type => 'DependsOn', Target => $dep->id );
        ok( $ok, "linked DependsOn: $msg" );
        ( $ok, $msg ) = $main->AddLink( Type => 'RefersTo', Target => $ref->id );
        ok( $ok, "linked RefersTo: $msg" );
    }

    $m->goto_ticket( $main->id );

    # Section headers render only for populated relationships
    $m->content_contains( 'Depends on', 'has Depends on section' );
    $m->content_contains( 'Refers to',  'has Refers to section' );
    $m->content_lacks( 'links-section-DependedOnBy', 'no empty Depended on by section' );

    # Tables render through CollectionList (collection-as-table markup)
    $m->content_like( qr/collection-as-table/, 'renders a CollectionList table' );

    $m->content_contains( $dep->id,         'shows depends-on ticket id' );
    $m->content_contains( 'depends target', 'shows depends-on subject' );

    $m->content_like( qr{<a href="[^"]*/Ticket/Display\.html\?id=@{[$dep->id]}">@{[$dep->id]}</a>},
        'depends-on ticket id is a link to the related ticket' );
    $m->content_like( qr{<a href="[^"]*/Ticket/Display\.html\?id=@{[$dep->id]}">depends target</a>},
        'depends-on subject is a link to the related ticket' );

    $m->content_like( qr{<span class="title">\s*Ticket\s*</span>}, 'ticket table header names the object type' );

    # Inactive linked objects get a record-inactive row class (struck through); active ones do not.
    my ($inactive_dep) = RT::Test->create_tickets( { Queue => $q->id }, { Subject => 'resolved dep' } );
    $inactive_dep->SetStatus('resolved');
    $main->AddLink( Type => 'DependsOn', Target => $inactive_dep->id );
    $m->goto_ticket( $main->id );
    $m->content_like( qr{<tr[^>]*record-inactive[^>]*data-record-id="@{[$inactive_dep->id]}"},
        'inactive linked ticket row is marked record-inactive' )
        or diag $m->content;
    $m->content_unlike(
        qr{<tr[^>]*record-inactive[^>]*data-record-id="@{[$dep->id]}"},
        'active linked ticket row is not marked inactive'
    );

    $m->content_contains( 'Create new', 'create-linked-ticket footer present' );

    # Helper: add a link as a superuser, regardless of how $main was created.
    sub add_link {
        my ( $id, %args ) = @_;
        my $t = RT::Ticket->new( RT->SystemUser );
        $t->Load($id);
        my ( $ok, $msg ) = $t->AddLink(%args);
        ok( $ok, "AddLink: $msg" );
    }

    # Non-ticket object type: asset link renders its own table
    my $catalog = create_catalog( Name => 'Linked assets' );
    ok( $catalog && $catalog->id, 'created catalog' );
    my $asset = create_asset( Catalog => $catalog->id, Name => 'prod-db-01' );
    ok( $asset && $asset->id, 'created asset' );

    add_link( $main->id, Type => 'RefersTo', Target => 'asset:' . $asset->id );
    $m->goto_ticket( $main->id );
    $m->content_contains( 'prod-db-01', 'asset link shows asset name' );
    $m->content_like( qr{<span class="title">\s*Asset\s*</span>}, 'asset table header names the object type' );
    $m->content_unlike( qr{<span class="title">\s*Catalog\s*</span>}, 'asset table has no Catalog column (dropped from %LinksFormat)' );

    # Article links show id + Name only; the Class column was dropped from %LinksFormat.
    my $art_class = RT::Class->new( RT->SystemUser );
    $art_class->Create( Name => 'KB Articles' );
    my $article = RT::Article->new( RT->SystemUser );
    $article->Create( Name => 'restart-guide', Class => $art_class->id, Summary => 'how to' );
    add_link( $main->id, Type => 'RefersTo', Target => 'a:' . $article->id );
    $m->goto_ticket( $main->id );
    $m->content_contains( 'restart-guide', 'article link shows article name' );
    $m->content_unlike( qr{<span class="title">\s*Class\s*</span>}, 'article table has no Class column (dropped from %LinksFormat)' );

    # External URL renders in its own table, just like the other object types
    add_link( $main->id, Type => 'RefersTo', Target => 'https://example.com/runbook' );
    $m->goto_ticket( $main->id );
    $m->content_contains( 'https://example.com/runbook', 'external URL shown' );
    ok $m->dom->at('.links-type-table[data-links-object-type="URL"] a[href="https://example.com/runbook"]'),
        'external URL is in its own URL table';

    # Empty state: a ticket with no links shows only the footer (no tables)
    my ($bare) = RT::Test->create_tickets( { Queue => $q->id }, { Subject => 'no links' } );
    $m->goto_ticket( $bare->id );
    $m->content_contains( 'Create new', 'empty ticket still has create footer' );
    $m->content_unlike( qr/collection-as-table/, 'empty ticket has no link tables' );

    # --- All links rendered ---
    # 8 dependency tickets; all must render immediately with no "Show all" control.
    my @manydeps = RT::Test->create_tickets( { Queue => $q->id }, map { { Subject => "manydep $_" } } 1 .. 8, );
    my ($big) = RT::Test->create_tickets( { Queue => $q->id }, { Subject => 'many deps' } );
    add_link( $big->id, Type => 'DependsOn', Target => $_->id ) for @manydeps;

    my $url = $baseurl . '/Views/Component/ShowLinks?ObjectType=RT::Ticket&ObjectId=' . $big->id;

    $m->get_ok( $url, 'fetch ShowLinks display component' );
    $m->content_lacks( 'Show all', 'no show-all control' );

    my $init_html = $m->content;
    my %seen_init;
    $seen_init{$1}++ while $init_html =~ /manydep (\d+)/g;
    my $shown = scalar keys %seen_init;
    is( $shown, 8, 'initial render shows all 8 links' );

    # Info modal: icon trigger + modal content present in display mode
    $m->goto_ticket( $main->id );
    $m->content_like( qr/data-bs-target="#links-info-modal"/, 'info icon targets the modal' );
    $m->content_contains( 'links-info-modal', 'info modal element present' );
    $m->content_contains( 'About links',      'modal title present' );
    $m->content_contains( 'Depended on by',   'modal lists relationship descriptions' );
    $m->content_like( qr/This ticket can't be resolved until the linked items are done/,
        'ticket modal uses the resolution-based dependency wording' );
    $m->content_contains( 'asset:',           'modal lists value-field shortcuts' );

    # Transaction link renders in its own table (first-class)
    my ($txn_target) = RT::Test->create_tickets( { Queue => $q->id }, { Subject => 'has a txn' } );
    my $first_txn = $txn_target->Transactions->First;
    add_link( $main->id, Type => 'RefersTo', Target => 'txn:' . $first_txn->id );
    $m->goto_ticket( $main->id );

    # ...in a collection-as-table, not just as a bare URL.
    $m->content_like( qr/collection-as-table/, 'transaction link renders in a collection table' );

    $m->content_like( qr{<a href="[^"]*/Transaction/Display\.html\?id=@{[$first_txn->id]}">@{[$first_txn->id]}</a>},
        'transaction id links to /Transaction/Display.html' )
        or diag $m->content;

    $m->content_like( qr{<a href="[^"]*/Ticket/Display\.html\?id=@{[$txn_target->id]}">has a txn</a>},
        'transaction Object column links to its parent ticket' )
        or diag $m->content;
    $m->content_like( qr{<span class="title">\s*Object\s*</span>}, 'transaction table has an Object column' );
    $m->content_like( qr{<span class="title">\s*Created\s*</span>},
        'transaction table has a Created column' );

    # A non-ticket (asset) transaction has no /Transaction/Display.html page, so its id links to the
    # parent object's history page anchored at the transaction (matching RT::URI::transaction->HREF).
    my $asset_txn = $asset->Transactions->First;
    add_link( $main->id, Type => 'RefersTo', Target => 'txn:' . $asset_txn->id );
    $m->goto_ticket( $main->id );
    $m->content_unlike( qr{/Transaction/Display\.html\?id=@{[$asset_txn->id]}\b},
        'non-ticket (asset) transaction id does not use the ticket-only Transaction display page' )
        or diag $m->content;
    $m->content_like(
        qr{<a href="[^"]*/Asset/History\.html\?id=@{[$asset->id]}#txn-@{[$asset_txn->id]}">@{[$asset_txn->id]}</a>},
        'non-ticket (asset) transaction id links to its parent object history page' )
        or diag $m->content;

    # ...but its Object column still links to the parent object. Use an article reachable
    # ONLY through its transaction, so the only link to it proves the Object column works.
    my $txn_class = RT::Class->new( RT->SystemUser );
    $txn_class->Create( Name => 'Txn KB' );
    my $txn_article = RT::Article->new( RT->SystemUser );
    $txn_article->Create( Name => 'txn-only-article', Class => $txn_class->id, Summary => 's' );
    add_link( $main->id, Type => 'RefersTo', Target => 'txn:' . $txn_article->Transactions->First->id );
    $m->goto_ticket( $main->id );
    $m->content_like(
        qr{<a href="[^"]*/Articles/Article/Display\.html\?id=@{[$txn_article->id]}">txn-only-article</a>},
        'a non-ticket transaction Object column links to its parent object (article)'
        )
        or diag $m->content;

    # Linked users and groups link to their summary pages.
    my ($ug)   = RT::Test->create_tickets( { Queue => $q->id }, { Subject => 'user and group links' } );
    my $luser  = RT::Test->load_or_create_user( Name => 'link-summary-user' );
    my $lgroup = RT::Group->new( RT->SystemUser );
    $lgroup->CreateUserDefinedGroup( Name => 'link-summary-group' );
    add_link( $ug->id, Type => 'RefersTo', Target => 'user:' . $luser->id );
    add_link( $ug->id, Type => 'RefersTo', Target => 'group:' . $lgroup->id );
    $m->goto_ticket( $ug->id );
    $m->content_like( qr{href="[^"]*/User/Summary\.html\?id=@{[$luser->id]}"}, 'linked user links to its summary page' )
        or diag $m->content;
    $m->content_like( qr{href="[^"]*/Group/Summary\.html\?id=@{[$lgroup->id]}"},
        'linked group links to its summary page' )
        or diag $m->content;

    $m->goto_ticket( $main->id );
    $m->content_contains( 'txn:', 'info modal lists the txn: shortcut' );

    # After an inline edit the row reloads via CollectionListRow; the inactive marking must survive
    # (re-evaluating live status). The table flags it via data-mark-inactive; CollectionListRow honors
    # MarkInactive + the current status.
    $m->goto_ticket( $main->id );
    $m->content_like( qr{data-mark-inactive="1"}, 'links table flags inactive marking for row reloads' );
    my $row_url = $m->rt_base_url . 'Helpers/CollectionListRow';
    $m->post(
        $row_url,
        {   DisplayFormat => "'__id__', '__Status__'",
            ObjectClass   => 'RT::Ticket',
            ObjectId      => $inactive_dep->id,
            MaxItems      => 5,
            InlineEdit    => 1,
            i             => 1,
            MarkInactive  => 1
        }
    );
    $m->content_like( qr/record-inactive/, 'reloaded row of an inactive ticket gains the strike-through' );
    $m->post(
        $row_url,
        {   DisplayFormat => "'__id__', '__Status__'",
            ObjectClass   => 'RT::Ticket',
            ObjectId      => $dep->id,
            MaxItems      => 5,
            InlineEdit    => 1,
            i             => 1,
            MarkInactive  => 1
        }
    );
    $m->content_unlike( qr/record-inactive/, 'reloaded row of an active ticket has no strike-through' );
}

diag "merged from ticket_links_edit.t";
{
    my $q = RT::Test->load_or_create_queue( Name => 'General' );

    my ($dep)  = RT::Test->create_tickets( { Queue => $q->id }, { Subject => 'dep' } );
    my ($main) = RT::Test->create_tickets( { Queue => $q->id }, { Subject => 'main' } );
    {
        my $t = RT::Ticket->new( RT->SystemUser );
        $t->Load( $main->id );
        $t->AddLink( Type => 'DependsOn', Target => $dep->id );
    }

    my $url = $baseurl . '/Views/Component/ShowLinks?ObjectType=RT::Ticket&ObjectId=' . $main->id . '&Edit=1';
    $m->get_ok( $url, 'fetch ShowLinks in edit mode' );
    my $dep_id = $dep->id;
    $m->content_like(
        qr{name="DeleteLink--DependsOn-[^"]*ticket/${dep_id}"},
        'edit mode renders a DeleteLink checkbox for the dependency'
    );

    my ($inactive_dep) = RT::Test->create_tickets( { Queue => $q->id }, { Subject => 'resolved dep' } );
    $inactive_dep->SetStatus('resolved');
    {
        my $t = RT::Ticket->new( RT->SystemUser );
        $t->Load( $main->id );
        $t->AddLink( Type => 'DependsOn', Target => $inactive_dep->id );
    }
    $m->get_ok( $url, 'fetch ShowLinks in edit mode (with an inactive dependency)' );
    $m->content_like(
        qr{<tr[^>]*record-inactive[^>]*data-record-id="@{[$inactive_dep->id]}"},
        'inactive linked ticket is marked record-inactive in edit mode'
        )
        or diag $m->content;
    $m->content_unlike(
        qr{<tr[^>]*record-inactive[^>]*data-record-id="${dep_id}"},
        'active linked ticket is not marked inactive in edit mode'
    );

    $m->get_ok( $baseurl . '/Views/Component/ShowLinks?ObjectType=RT::Ticket&ObjectId=' . $main->id,
        'fetch ShowLinks in display mode' );
    $m->content_unlike( qr{name="DeleteLink-}, 'display mode has no DeleteLink checkbox' );

    # Base-mode (DependedOnBy): $blocker depends on $main, so $blocker is the base of the DependsOn link
    # and the checkbox name is DeleteLink-<blockerURI>-DependsOn- (base=blocker URI, type, empty target).
    my ($blocker) = RT::Test->create_tickets( { Queue => $q->id }, { Subject => 'blocker' } );
    {
        my $t = RT::Ticket->new( RT->SystemUser );
        $t->Load( $blocker->id );
        $t->AddLink( Type => 'DependsOn', Target => $main->id );
    }
    my $base_mode_url = $baseurl . '/Views/Component/ShowLinks?ObjectType=RT::Ticket&ObjectId=' . $main->id . '&Edit=1';
    $m->get_ok( $base_mode_url, 'fetch ShowLinks in edit mode (for Base-mode check)' );
    my $blocker_id = $blocker->id;
    $m->content_like(
        qr{name="DeleteLink-[^"]*ticket/${blocker_id}-DependsOn-"},
        'edit mode renders a Base-mode DeleteLink checkbox for DependedOnBy'
    );

    $m->get_ok( $baseurl . '/Views/Component/EditLinks?ObjectType=RT::Ticket&ObjectId=' . $main->id,
        'fetch new edit component' );
    $m->content_like( qr/select[^>]*class="[^"]*link-type-select/,        'has a link-type dropdown' );
    $m->content_like( qr/select[^>]*class="[^"]*link-object-type-select/, 'has an object-type dropdown' );
    $m->content_like( qr/class="[^"]*add-link-row/,                       'has add rows' );
    my $rows = () = ( $m->content =~ /class="[^"]*add-link-row/g );
    ok( $rows >= 2, "renders at least two add rows (got $rows)" );
    $m->content_lacks( 'links-removal-count', 'no removal counter (removed with trash-link design)' );
    $m->content_unlike( qr/links-edit-footer/, 'no edit footer (removed with trash-link design)' );

    my ($url_ticket) = RT::Test->create_tickets( { Queue => $q->id }, { Subject => 'url-links-ticket' } );
    {
        my $t = RT::Ticket->new( RT->SystemUser );
        $t->Load( $url_ticket->id );
        $t->AddLink( Type => 'RefersTo', Target => 'https://example.com/phase2-url' );
    }
    $m->get_ok( $baseurl . '/Views/Component/ShowLinks?ObjectType=RT::Ticket&ObjectId=' . $url_ticket->id . '&Edit=1',
        'fetch ShowLinks in edit mode for URL link' );
    $m->content_like( qr{name="DeleteLink--RefersTo-[^"]*example\.com/phase2-url"},
        'URL row has a removal checkbox in edit mode' );

    $m->get_ok( $baseurl . '/Views/Component/ShowLinks?ObjectType=RT::Ticket&ObjectId=' . $url_ticket->id,
        'fetch ShowLinks in display mode for URL link' );
    $m->content_unlike(
        qr{name="DeleteLink--RefersTo-[^"]*example\.com/phase2-url"},
        'URL row has no removal checkbox in display mode'
    );

    # The ticket page no longer renders the old two-column EditLinks inline; the new edit component is
    # wired instead.
    $m->get_ok( $baseurl . '/Ticket/Display.html?id=' . $main->id, 'ticket display page' );
    $m->content_lacks( 'Current Links', 'old EditLinks two-column header not rendered inline' );
    $m->content_like( qr{Views/Component/EditLinks}, 'portlet wires the generalized edit component' );
    $m->content_like( qr{class="[^"]*links-edit-container[^"]*"[^>]*hx-get="[^"]*Views/Component/EditLinks},
        'links-edit-container carries the EditLinks hx-get' );

    $m->content_like( qr{class="[^"]*links-edit-container[^"]*"}, 'found the links-edit-container div' );
    $m->content_like( qr/add-link-row/, 'edit container renders add-link rows eagerly (DualMode, not lazy)' );

    # End-to-end Save: add a ticket + transaction RefersTo and remove a DependsOn in a single POST to
    # /Helpers/TicketUpdate, exercising ProcessRecordLinks via the same field names the edit JS
    # assembles. Use a FRESH ticket so earlier tests don't interfere.
    {
        my ($e2e_dep)  = RT::Test->create_tickets( { Queue => $q->id }, { Subject => 'e2e dep' } );
        my ($e2e_main) = RT::Test->create_tickets( { Queue => $q->id }, { Subject => 'e2e main' } );
        {
            my $t = RT::Ticket->new( RT->SystemUser );
            $t->Load( $e2e_main->id );
            my ( $ok, $msg ) = $t->AddLink( Type => 'DependsOn', Target => $e2e_dep->id );
            ok( $ok, "added DependsOn link to remove later: $msg" );
        }

        my ($add_ticket) = RT::Test->create_tickets( { Queue => $q->id }, { Subject => 'to add' } );
        my $first_txn = $add_ticket->Transactions->First;
        ok( $first_txn && $first_txn->id, 'got a transaction to link' );

        is( $e2e_main->DependsOn->Count, 1, 'main has one DependsOn before save' );

        # ProcessRecordLinks splits on a SINGLE space, so separate the two RefersTo targets with one.
        my $refers_field = $e2e_main->id . '-RefersTo';
        $m->post(
            $baseurl . '/Helpers/TicketUpdate',
            {   id                                       => $e2e_main->id,
                $refers_field                            => $add_ticket->id . ' txn:' . $first_txn->id,
                'DeleteLink--DependsOn-' . $e2e_dep->URI => 1,
            },
        );
        ok( $m->success, 'POST to /Helpers/TicketUpdate succeeded' );

        DBIx::SearchBuilder::Record::Cachable->FlushCache;
        my $fresh = RT::Ticket->new( RT->SystemUser );
        $fresh->Load( $e2e_main->id );

        # Both RefersTo targets processed: a count of 1 would mean the delimiter is wrong.
        is( $fresh->RefersTo->Count, 2, 'RefersTo now has the ticket and the transaction' )
            or diag 'RefersTo targets: ' . join ', ', map { $_->Target } @{ $fresh->RefersTo->ItemsArrayRef };
        my %targets       = map { $_->Target => 1 } @{ $fresh->RefersTo->ItemsArrayRef };
        my $add_ticket_id = $add_ticket->id;
        ok( ( grep {m{ticket/$add_ticket_id$}} keys %targets ), 'ticket RefersTo added' );
        ok( ( grep {m{^transaction://}} keys %targets ),        'transaction RefersTo added (transaction:// target)' );

        is( $fresh->DependsOn->Count, 0, 'the DependsOn link was removed' );
    }

    # A row reloaded via CollectionListRow must keep its removal checkbox: the edit-mode table wrapper
    # carries the link-delete type/mode, and CollectionListRow restores the notes the
    # DeleteLinkCheckBox column needs.
    {
        my ($d) = RT::Test->create_tickets( { Queue => $q->id }, { Subject => 'reload dep' } );
        my ($t) = RT::Test->create_tickets( { Queue => $q->id }, { Subject => 'reload main' } );
        $t->AddLink( Type => 'DependsOn', Target => $d->id );

        my $edit_url = $baseurl . '/Views/Component/ShowLinks?ObjectType=RT::Ticket&ObjectId=' . $t->id . '&Edit=1';
        $m->get_ok( $edit_url, 'fetch edit mode for the reload check' );
        $m->content_like( qr{data-link-delete-type="DependsOn"}, 'edit table wrapper carries the link-delete type' );

        my ($fmt) = $m->content =~ /data-display-format="([^"]*)"/;
        $fmt =~ s/&#39;/'/g;
        $fmt =~ s/&quot;/"/g;
        $fmt =~ s/&amp;/&/g;

        $m->post(
            $m->rt_base_url . 'Helpers/CollectionListRow',
            {   DisplayFormat  => $fmt,
                ObjectClass    => 'RT::Ticket',
                ObjectId       => $d->id,
                MaxItems       => 5,
                InlineEdit     => 1,
                i              => 1,
                LinkDeleteType => 'DependsOn',
                LinkDeleteMode => 'Target',
            }
        );
        my $did = $d->id;
        $m->content_like(
            qr{name="DeleteLink--DependsOn-[^"]*ticket/${did}"},
            'reloaded edit-mode row keeps its removal checkbox'
            )
            or diag $m->content;
    }
}

diag "merged from ticket_links_filter.t";
{
    my $q = RT::Test->load_or_create_queue( Name => 'General' );

    # Main ticket DependsOn 8 others; the search must find a specific one among them.
    my @deps = RT::Test->create_tickets( { Queue => $q->id }, map { { Subject => "filterdep $_" } } 1 .. 8 );
    my ($main) = RT::Test->create_tickets( { Queue => $q->id }, { Subject => 'filter main' } );
    {
        my $t = RT::Ticket->new( RT->SystemUser );
        $t->Load( $main->id );
        $t->AddLink( Type => 'DependsOn', Target => $_->id ) for @deps;
    }

    my $base = $baseurl . '/Views/Component/ShowLinks?ObjectType=RT::Ticket&ObjectId=' . $main->id;

    # Display always renders the full link set; filtering is now client-side (util.js).
    $m->get_ok( $base, 'unfiltered render' );
    $m->content_contains( 'filterdep 8', 'display renders all links' );
    $m->content_contains( 'filterdep 1', 'display renders all links (no server-side filtering)' );
    $m->content_like(
        qr/data-links-object-type="Ticket"/,
        'object-type filter token renders as CamelCase (Ticket)'
    );
    $m->content_unlike(
        qr/data-links-object-type="ticket"/,
        'lowercase object-type token is gone'
    );

    # The filter bar reveals on a non-zero data-links-total carrier.
    $m->content_like(
        qr/data-links-total="[1-9]/,
        'ShowLinks emits a non-zero data-links-total for a ticket with links'
    );

    my $out = $m->get( $baseurl . '/Views/Component/LinksFilter?ObjectType=RT::Ticket&ObjectId=' . $main->id );
    $m->content_like( qr/links-filter-form/,                             'filter form present' );
    $m->content_like( qr/links-search-input/,                            'search input group present (history-sized)' );
    $m->content_like( qr/name="Search"[^>]*placeholder/,                 'search input with placeholder' );
    $m->content_like( qr/links-filter-dropdown/,                         'filter dropdown present' );
    $m->content_like( qr/name="ShowRelationship"[^>]*value="DependsOn"/, 'link-type checklist has DependsOn' );
    $m->content_like( qr/name="ShowRelationship"[^>]*value="MemberOf"/,
        'link-type checklist lists all types, even ones with no links (so it never goes stale after an update)' );
    $m->content_like( qr/name="ShowObjectType"[^>]*value="Ticket"/, 'object-type checklist has ticket' );
    $m->content_like( qr/links-filter-apply/,                       'Apply button present' );

    $m->get_ok( $baseurl . '/Ticket/Display.html?id=' . $main->id, 'ticket display page' );
    $m->content_like( qr/links-filter-form/,            'filter bar present in the unified edit body' );
    # The edit container, not a separate display target, carries the reload triggers.
    $m->content_like( qr/links-edit-container/, 'unified edit container present' );
    $m->content_like( qr/links-edit-container[^>]*hx-trigger="[^"]*ticketLinksChanged/, 'edit container listens for ticketLinksChanged' );

    $m->get_ok( $baseurl . '/Views/Component/EditLinks?ObjectType=RT::Ticket&ObjectId=' . $main->id, 'edit component' );
    $m->content_like( qr/links-filter-form/, 'filter bar present in edit mode' );
    $m->content_contains( 'filterdep 8', 'edit mode loads ALL links so dep 8 is present' );
    $m->content_lacks( 'Show all', 'edit mode has no Show all control' );

    # Part A: removal survives the client-side filter. The filter only hides non-matching rows (adds
    # .d-none), never removing them from the DOM, so a checked-but-hidden row still submits. Prove the
    # SERVER side: every dep's removal checkbox renders, then a POST removing dep 8 drops the count.
    {
        for my $dep (@deps) {
            my $name = 'DeleteLink--DependsOn-' . $dep->URI;
            $m->content_like( qr/name="\Q$name\E"[^>]*class="[^"]*delete-link/,
                'removal checkbox present for ' . $dep->Subject )
                or last;
        }

        my $dep8 = $deps[7];
        {
            my $t = RT::Ticket->new( RT->SystemUser );
            $t->Load( $main->id );
            is( $t->DependsOn->Count, 8, 'precondition: 8 deps' );
        }
        $m->post( $baseurl . '/Helpers/TicketUpdate',
            { id => $main->id, 'DeleteLink--DependsOn-' . $dep8->URI => 1 }, );
        ok( $m->success, 'POST to /Helpers/TicketUpdate succeeded' );

        DBIx::SearchBuilder::Record::Cachable->FlushCache;
        my $fresh = RT::Ticket->new( RT->SystemUser );
        $fresh->Load( $main->id );
        is( $fresh->DependsOn->Count, 7, 'a removal submitted even though that row could be filtered out client-side' );
        ok( !( grep { $_->Target eq $dep8->URI } @{ $fresh->DependsOn->ItemsArrayRef } ),
            'the removed dep is the one we checked (dep 8)'
          );
    }

    # Part C: a linked transaction renders in its own table (the client filter is browser-tested).
    {
        my ($txn_main)   = RT::Test->create_tickets( { Queue => $q->id }, { Subject => 'txn link main' } );
        my ($txn_source) = RT::Test->create_tickets( { Queue => $q->id }, { Subject => 'unmistakableword source' } );
        my $txn          = $txn_source->Transactions->First;
        ok( $txn && $txn->id, 'got a transaction to link' );
        {
            my $t = RT::Ticket->new( RT->SystemUser );
            $t->Load( $txn_main->id );
            my ( $ok, $msg ) = $t->AddLink( Type => 'RefersTo', Target => 'txn:' . $txn->id );
            ok( $ok, "linked transaction txn:@{[$txn->id]}: $msg" );
        }

        my $tbase = $baseurl . '/Views/Component/ShowLinks?ObjectType=RT::Ticket&ObjectId=' . $txn_main->id;
        $m->get_ok( $tbase, 'transaction link render' );
        $m->content_like(
            qr/links-type-table[^>]*data-links-object-type="Transaction"/,
            'transaction table rendered'
        );
    }

    # The widget renders the filter in its title bar, hidden (d-none) until there are links; the
    # standalone EditLinks component still gates its in-body bar on the live link count.
    {
        my ($nolinks) = RT::Test->create_tickets( { Queue => $q->id }, { Subject => 'no links' } );
        $m->get_ok( $baseurl . '/Ticket/Display.html?id=' . $nolinks->id, 'link-less ticket display page' );
        $m->content_like(
            qr/links-filter-form[^>]*\bd-none\b/,
            'filter bar present but hidden (d-none) on the display page when there are no links'
        );
        $m->get_ok( $baseurl . '/Views/Component/EditLinks?ObjectType=RT::Ticket&ObjectId=' . $nolinks->id,
            'link-less edit component' );
        $m->content_unlike( qr/links-filter-form/, 'no filter bar in the standalone edit component without links' );
    }
}

diag "LinksFilter pre-checks the configured default";
{
    my $lf_q = RT::Test->load_or_create_queue( Name => 'General' );
    my ($lf_t) = RT::Test->create_tickets( { Queue => $lf_q->id }, { Subject => 'lf filter probe' } );
    my $u = "$baseurl/Views/Component/LinksFilter?ObjectType=RT::Ticket&ObjectId=" . $lf_t->id
          . "&HideInactive=1&ShowObjectType=Ticket&ShowObjectType=Asset";
    $m->get_ok( $u, 'fetch LinksFilter with a configured default' );
    $m->content_like( qr/name="HideInactive"[^>]*\bchecked/, 'Hide-inactive box is checked' );
    $m->content_like( qr/name="ShowObjectType" value="Ticket"[^>]*\bchecked/, 'Ticket object-type stays checked' );
    $m->content_unlike( qr/name="ShowObjectType" value="Article"[^>]*\bchecked/, 'Article object-type is unchecked' );
}

diag "EditLinks forwards the configured default to its filter";
{
    my $el_q = RT::Test->load_or_create_queue( Name => 'General' );
    my ($el_dep) = RT::Test->create_tickets( { Queue => $el_q->id }, { Subject => 'el dep' } );
    my ($el_t)   = RT::Test->create_tickets( { Queue => $el_q->id }, { Subject => 'el main' } );
    $el_t->AddLink( Type => 'DependsOn', Target => $el_dep->id );   # EditLinks renders its filter only when $has_links
    my $u = "$baseurl/Views/Component/EditLinks?ObjectType=RT::Ticket&ObjectId=" . $el_t->id
          . "&HideInactive=1&ShowObjectType=Ticket";
    $m->get_ok( $u, 'fetch EditLinks with a configured default' );
    $m->content_like( qr/name="HideInactive"[^>]*\bchecked/, 'edit-mode Hide-inactive box is checked' );
    $m->content_unlike( qr/name="ShowObjectType" value="Asset"[^>]*\bchecked/, 'edit-mode Asset object-type is unchecked' );
}

diag "merged from ticket_links_inline_refresh.t";
{
    my $base = $baseurl;
    my $q    = RT::Test->load_or_create_queue( Name => 'General' );

    my ($main)   = RT::Test->create_tickets( { Queue => $q->id }, { Subject => 'links refresh main' } );
    my ($linked) = RT::Test->create_tickets( { Queue => $q->id }, { Subject => 'links refresh linked' } );
    {
        my $t = RT::Ticket->new( RT->SystemUser );
        $t->Load( $main->id );
        $t->AddLink( Type => 'RefersTo', Target => $linked->id );
    }

    # Simulate the request coming from the main ticket's Display page.
    $m->add_header( 'HX-Current-URL' => $base . '/Ticket/Display.html?id=' . $main->id );

    # Editing a linked ticket (a Links-portlet listing row) must refresh its row.
    my $req  = $m->post( $base . '/Helpers/TicketUpdate', { id => $linked->id, Status => 'open' } );
    my $trig = from_json( $req->header('HX-Trigger') // '{}' );
    ok( $trig->{collectionsChanged}, 'editing a linked ticket from the display page fires collectionsChanged' );
    is( $trig->{collectionsChanged}{id}, $linked->id, 'collectionsChanged targets the linked ticket row' );

    # Editing the display page's own ticket must NOT fire collectionsChanged: its widgets
    # refresh through the ticketXChanged events instead (cd7c5bf879).
    my $req2  = $m->post( $base . '/Helpers/TicketUpdate', { id => $main->id, Status => 'open' } );
    my $trig2 = from_json( $req2->header('HX-Trigger') // '{}' );
    ok( !$trig2->{collectionsChanged}, 'editing the display page ticket itself does not fire collectionsChanged' );

    $m->delete_header('HX-Current-URL');
}

diag "merged from links_children_tree.t";
{
    my $q = RT::Test->load_or_create_queue( Name => 'General' );

    # Build a tree: root -> c1 -> g1 ; root -> c2 -> g1 (diamond, g1 reachable via two paths). RT refuses
    # circular MemberOf links, so we use a shared grandchild instead of a back-edge.
    my %t;
    $t{$_} = ( RT::Test->create_tickets( { Queue => $q->id }, { Subject => "node $_" } ) )[0]
        for qw/root c1 c2 g1/;
    my $add = sub {
        my ( $parent, $child ) = @_;
        my $p = RT::Ticket->new( RT->SystemUser );
        $p->Load( $t{$parent}->id );
        my ( $ok, $msg )
            = $p->AddLink( Type => 'MemberOf', Base => $t{$child}->id );    # $child is a member (child) of $parent
        ok( $ok, "linked $parent -> $child: $msg" );
    };
    $add->( 'root', 'c1' );
    $add->( 'root', 'c2' );
    $add->( 'c1',   'g1' );
    $add->( 'c2',   'g1' );    # g1 also appears under c2, second visit shows "shown above"

    my $url = $baseurl . '/Views/Component/ShowLinks?ObjectType=RT::Ticket&ObjectId=' . $t{root}->id;
    $m->get_ok( $url, 'fetch ShowLinks (display) for the root ticket' );

    # The Children section is a tree table, not the flat per-type table.
    $m->content_like( qr{class="[^"]*links-tree[^"]*"}, 'children render as a links-tree table' );
    $m->content_like( qr{role="treegrid"},              'tree table is a treegrid' );

    # Regression: the tree table renders a header row (it previously jumped straight to <tbody>),
    # type-titled "Ticket" like the flat per-type ticket table.
    $m->content_like( qr{class="[^"]*links-tree[^"]*"[^>]*>\s*<thead\b}s,
        'tree table renders a header (thead right after the table tag)' );
    $m->content_like( qr{<span class="title">Ticket</span>},
        'tree header first column is type-titled "Ticket"' );

    $m->content_like(
        qr{data-record-id="@{[$t{c1}->id]}"[^>]*data-depth="1"|data-depth="1"[^>]*data-record-id="@{[$t{c1}->id]}"},
        'c1 is a depth-1 row'
    );
    $m->content_like(
        qr{data-record-id="@{[$t{c2}->id]}"[^>]*data-depth="1"|data-depth="1"[^>]*data-record-id="@{[$t{c2}->id]}"},
        'c2 is a depth-1 row'
    );
    $m->content_like(
        qr{data-record-id="@{[$t{g1}->id]}"[^>]*data-depth="2"|data-depth="2"[^>]*data-record-id="@{[$t{g1}->id]}"},
        'g1 is a depth-2 row'
    );

    $m->content_like( qr/shown above/, 'a shared grandchild shows a "shown above" marker on its second visit' );

    $m->content_like( qr{data-tree-prefix="[IBML]+"}, 'rows carry an ASCII tree-structure code' );

    $m->content_like( qr{class="[^"]*links-tree[^"]*inline-edit|class="[^"]*inline-edit[^"]*links-tree},
        'tree table is inline-edit enabled' );

    # Given a node's tree decoration, the row-refresh helper returns a row that keeps its guide and
    # depth, so an inline-edited tree row slots back in place.
    my $row_url = $baseurl . '/Helpers/CollectionListRow';
    my $fmt     = RT->Config->Get('LinksFormat')->{'RT::Ticket'};
    $m->post(
        $row_url,
        {   DisplayFormat => $fmt,
            ObjectClass   => 'RT::Ticket',
            ObjectId      => $t{g1}->id,
            MaxItems      => 4,
            InlineEdit    => 1,
            MarkInactive  => 1,
            i             => 1,
            TreePrefix    => 'IL',
            Depth         => 2,
        }
    );
    ok( $m->success, 'refresh a tree row with its decoration' );
    $m->content_like( qr{data-depth="2"},        'refreshed row keeps its depth' );
    $m->content_like( qr{data-tree-prefix="IL"}, 'refreshed row keeps its structure code' );
    $m->content_like( qr{links-tree-guide},      'refreshed row re-renders its tree guide' );
}

diag "Children tree prunes nodes (and their subtrees) the viewer can't see";
{
    my $general = RT::Test->load_or_create_queue( Name => 'General' );
    my $hidden  = RT::Test->load_or_create_queue( Name => 'Hidden' );

    # A privileged user who can see General but not Hidden.
    my $viewer = RT::Test->load_or_create_user(
        Name => 'tree-acl-viewer', Password => 'password', Privileged => 1 );
    RT::Test->add_rights( { Principal => $viewer, Right => [qw/ShowTicket SeeQueue/], Object => $general } );

    my $root        = RT::Test->create_ticket( Queue => 'General', Subject => 'tacl root' );
    my $visible_kid = RT::Test->create_ticket( Queue => 'General', Subject => 'tacl visible kid' );
    my $secret_kid  = RT::Test->create_ticket( Queue => 'Hidden',  Subject => 'tacl SECRET kid' );
    # A grandchild in a readable queue, reachable only through the unreadable secret_kid.
    my $gkid = RT::Test->create_ticket( Queue => 'General', Subject => 'tacl gkid under secret' );

    my $link = sub {
        my ( $parent, $child ) = @_;
        my $p = RT::Ticket->new( RT->SystemUser );
        $p->Load( $parent->id );
        my ( $ok, $msg ) = $p->AddLink( Type => 'MemberOf', Base => $child->id );    # $child is a child of $parent
        ok( $ok, "linked " . $parent->id . " -> " . $child->id . ": $msg" );
    };
    $link->( $root,       $visible_kid );
    $link->( $root,       $secret_kid );
    $link->( $secret_kid, $gkid );

    my $vm = RT::Test::Web->new;
    ok( $vm->login( 'tree-acl-viewer', 'password' ), 'restricted viewer logged in' );

    my $url = $baseurl . '/Views/Component/ShowLinks?ObjectType=RT::Ticket&ObjectId=' . $root->id;
    $vm->get_ok( $url, 'restricted viewer fetches ShowLinks for the root ticket' );

    $vm->content_like( qr{data-record-id="@{[$visible_kid->id]}"}, 'readable child appears in the tree' );
    $vm->content_unlike( qr{data-record-id="@{[$secret_kid->id]}"}, 'unreadable child is pruned from the tree' );
    # The grandchild is readable but reachable only via the hidden node, so it stays out too.
    $vm->content_unlike( qr{data-record-id="@{[$gkid->id]}"},
        'subtree under the unreadable child is pruned, even a readable grandchild reachable only through it' );

    # Every child unreadable: no rows, so neither the tree nor the Children section should render.
    my $lonely = RT::Test->create_ticket( Queue => 'General', Subject => 'tacl lonely root' );
    $link->( $lonely, $secret_kid );
    $vm->get_ok(
        $baseurl . '/Views/Component/ShowLinks?ObjectType=RT::Ticket&ObjectId=' . $lonely->id,
        'fetch ShowLinks for a root whose only child is unreadable'
    );
    $vm->content_unlike( qr{links-tree}, 'no children tree rendered when every child is unreadable' );
    $vm->content_unlike( qr{links-section-Members}, 'the Children section is dropped entirely' );
}

diag "merged from ticket_modifyall_links.t";
{
    my $q      = RT::Test->load_or_create_queue( Name => 'General' );
    my ($main) = RT::Test->create_tickets( { Queue => $q->id }, { Subject => 'jumbo main' } );
    my ($dep)  = RT::Test->create_tickets( { Queue => $q->id }, { Subject => 'jumbo dep' } );
    {
        my $t = RT::Ticket->new( RT->SystemUser );
        $t->Load( $main->id );
        $t->AddLink( Type => 'RefersTo', Target => $dep->id );
    }

    $m->get_ok( $baseurl . '/Ticket/ModifyAll.html?id=' . $main->id, 'ModifyAll (Jumbo) page' );
    my $content = $m->content;

    $m->content_like( qr{class="edit-ticket-links"},      'ModifyAll renders the links editor' );
    $m->content_like( qr{class="[^"]*add-link-row[^"]*"}, 'ModifyAll renders the row-based add UI' );
    $m->content_like( qr{name="DeleteLink-}, 'ModifyAll renders a DeleteLink checkbox for the existing link' );

    # Embedded in the page form, the editor must NOT emit nested <form> elements: they would close
    # TicketModifyAll early and orphan the reply box / Save button.
    $m->content_unlike( qr{name="SpawnLinkedTicket"},            'no nested SpawnLinkedTicket form on ModifyAll' );
    $m->content_unlike( qr{class="[^"]*links-filter-form[^"]*"}, 'no nested links-filter form on ModifyAll' );

    # Critical invariant: no </form> between the form open and the SubmitTicket button.
    my $form_open = index( $content, 'name="TicketModifyAll"' );
    ok( $form_open >= 0, 'found TicketModifyAll form' );

    # Use the LAST SubmitTicket occurrence (the visible Save button). RT emits a hidden SubmitTicket
    # right after the form open, so index() would give a vacuous (empty) slice.
    my $submit_pos = rindex( $content, 'name="SubmitTicket"' );
    ok( $submit_pos > $form_open, 'found the visible SubmitTicket button after the form open' );
    my $between = substr( $content, $form_open, $submit_pos - $form_open );
    unlike( $between, qr{</form>}, 'no nested </form> between the form open and the Save button (form not broken)' );
    unlike( $between, qr{class="editor"}, 'embedded link rows are not inline-edit forms' );
}

diag "merged from asset_links_portlet.t";
{
    my $catalog = create_catalog( Name => 'Kit' );
    my $main    = create_asset( Name => 'main asset',   Catalog => $catalog->id );
    my $other   = create_asset( Name => 'linked asset', Catalog => $catalog->id );
    $main->AddLink( Type => 'RefersTo', Target => 'asset:' . $other->id );

    my $edit_url = $baseurl . '/Views/Component/EditLinks?ObjectType=RT::Asset&ObjectId=' . $main->id;
    $m->get_ok( $edit_url, 'fetch the asset EditLinks component' );
    $m->content_like( qr{class="edit-ticket-links"},      'asset edit uses the shared editor container hook' );
    $m->content_like( qr{class="[^"]*add-link-row[^"]*"}, 'asset edit renders the row-based Add-links UI' );
    $m->content_like( qr{name="DeleteLink-}, 'asset edit renders a DeleteLink checkbox for the existing link' );

    # The asset Display page renders ONE unified body (no separate display target).
    $m->get_ok( $baseurl . '/Asset/Display.html?id=' . $main->id, 'asset display page' );
    $m->content_like( qr{class="[^"]*links-edit-container[^"]*"}, 'asset portlet renders the unified edit container' );
    $m->content_unlike( qr{id="links-display-target-}, 'asset portlet has no separate display-only target' );
    $m->content_like( qr{Views/Component/EditLinks\?ObjectType=RT::Asset}, 'asset edit container refreshes via EditLinks' );
    $m->content_like( qr{id="links-info-modal"},               'asset portlet includes the shared info modal' );
    $m->content_like( qr{class="[^"]*links-filter-form[^"]*"}, 'asset display shows the links filter' );

    # The modal wording is object-aware: assets use the record-type noun and the generic phrasing,
    # not the ticket-only "can't be resolved".
    my $noun = lc( $main->RecordType );
    $m->content_like( qr/This \Q$noun\E depends on the linked items/,
        "info modal wording uses the object noun ($noun)" );
    $m->content_unlike( qr/can't be resolved/, 'asset modal omits the ticket-only "resolved" wording' );
}

diag "Asset Links widget applies a configured default filter";
{
    my $cat   = create_catalog( Name => 'LWFilter' );
    my $a_act = create_asset( Catalog => $cat->id, Name => 'lw active asset dep' );
    my $a_res = create_asset( Catalog => $cat->id, Name => 'lw retired asset dep' );
    # Find an inactive status reachable from the asset's current (initial) status.
    my $lc = $a_res->LifecycleObj;
    my %inactive = map { $_ => 1 } $lc->Inactive;
    my ($inactive_status) = grep { $inactive{$_} } $lc->Transitions( $a_res->Status );
    ok( $inactive_status, 'found a reachable inactive status for the asset lifecycle' );
    ok( ( $a_res->SetStatus($inactive_status) )[0], "asset set to inactive ($inactive_status)" );
    my $a_main = create_asset( Catalog => $cat->id, Name => 'lw asset main' );
    $a_main->AddLink( Type => 'DependsOn', Target => 'asset:' . $a_act->id );
    $a_main->AddLink( Type => 'DependsOn', Target => 'asset:' . $a_res->id );

    my ( $ok, $msg ) = HTML::Mason::Commands::UpdateConfig(
        Name  => 'PageLayouts',
        Value => {
            'RT::Asset' => {
                'Display' => {
                    Default => [
                        { Layout => 'col-12', Elements => [ { Name => 'Links', HideInactive => 1 } ] },
                    ],
                },
            },
        },
        CurrentUser => RT->SystemUser,
    );
    ok( $ok, "configured asset Links HideInactive default" ) or diag $msg;

    $m->get_ok( "$baseurl/Asset/Display.html?id=" . $a_main->id, 'load asset display' );
    $m->content_contains( 'lw active asset dep',  'active asset dependency is shown' );

    # Filtering is client-side: the inactive row is in the server HTML (the client hides it) and the
    # funnel pre-checks Hide-inactive to reflect the configured default.
    $m->content_contains( 'lw retired asset dep', 'inactive asset dependency is rendered (hidden client-side)' );
    $m->content_like( qr/name="HideInactive"[^>]*\bchecked/, 'funnel Hide-inactive box reflects the default' );
}

diag "clone prefill renders clean values + object types in the add-links rows";
{
    my $q = RT::Test->load_or_create_queue( Name => 'General' );
    my ( $src, $other ) = RT::Test->create_tickets(
        { Queue   => $q->id },
        { Subject => 'clone prefill source' },
        { Subject => 'clone prefill ticket target' },
    );

    my $catalog = create_catalog( Name => 'Clone Prefill' );
    my $asset   = create_asset( Name => 'clone prefill asset', Catalog => $catalog->id );

    my $link_user = RT::Test->load_or_create_user( Name => 'clone-prefill-user', Privileged => 1 );
    ok( $link_user->id, 'created a user to link' );
    my $link_group = RT::Group->new( RT->SystemUser );

    # A group Name with a space: the row submits the space-free id, so the server's space-delimited
    # link parsing doesn't split the name into bogus targets.
    $link_group->CreateUserDefinedGroup( Name => 'clone prefill group' );
    ok( $link_group->id, 'created a group to link' );

    my $t = RT::Ticket->new( RT->SystemUser );
    $t->Load( $src->id );
    my $txn_id = $t->Transactions->First->id;
    for my $target (
        $other->id,
        'a:' . $article->id,
        'asset:' . $asset->id,
        'txn:' . $txn_id,
        'user:' . $link_user->id,
        'group:' . $link_group->id,
        'https://example.com/clone-prefill'
        )
    {
        my ( $ok, $msg ) = $t->AddLink( Type => 'RefersTo', Target => $target );
        ok( $ok, "RefersTo $target: $msg" );
    }

    $m->get_ok( $baseurl . '/Ticket/Create.html?Queue=' . $q->id . '&CloneTicket=' . $src->id,
        'create page cloning the source ticket' );

    # The object-type dropdown conveys the type, so the value box shows the bare human-readable form:
    # the id for tickets/articles/assets/txns, the Name for users/groups, the full URL for external
    # links. No shorthand prefix or full local URI leaks into the box; it's recomposed at submit time.
    my @rows;
    for my $row ( $m->dom->find('.add-links-section .add-link-row')->each ) {
        my $value = $row->at('input.link-value')->attr('value') // '';
        next unless length $value;
        my $selected = $row->at('.link-object-type-select option[selected]');
        my $submit   = $row->at('input.link-value-submit');
        push @rows,
            {   value  => $value,
                type   => ( $selected ? $selected->attr('value')         : '' ),
                submit => ( $submit   ? ( $submit->attr('value') // '' ) : '' ),
            };
    }
    my %present = map { $_->{type} . '|' . $_->{value} => 1 } @rows;
    ok( $present{ 'ticket|' . $other->id },       'ticket link prefills as a bare id with ticket type' );
    ok( $present{ 'article|' . $article->id },    'article link prefills as a bare id with article type' );
    ok( $present{ 'asset|' . $asset->id },        'asset link prefills as a bare id with asset type' );
    ok( $present{ 'transaction|' . $txn_id },     'transaction link prefills as a bare id with transaction type' );
    ok( $present{ 'user|' . $link_user->Name },   'user link prefills as the user Name with user type' );
    ok( $present{ 'group|' . $link_group->Name }, 'group link prefills as the group Name with group type' );
    ok( $present{'url|https://example.com/clone-prefill'}, 'external URL prefills as a full URL with url type' );

    # The hidden submit field carries the space-free form the server resolves: a shorthand-prefixed id
    # for local objects (so a spaced name is never split), the full URL for external links.
    my %submit = map { $_->{type} . '|' . $_->{submit} => 1 } @rows;
    ok( $submit{ 'user|user:' . $link_user->id },    'user row submits user:<id>, not the name' );
    ok( $submit{ 'group|group:' . $link_group->id }, 'group row submits group:<id>, not the (spaced) name' );
    ok( !( grep { $_->{type} eq 'group' && $_->{submit} =~ /\s/ } @rows ),
        'no group row submits a value containing whitespace'
      );
    ok( $submit{ 'ticket|' . $other->id },      'ticket row submits the bare id' );
    ok( $submit{ 'asset|asset:' . $asset->id }, 'asset row submits asset:<id>' );

    for my $r (@rows) {
        unlike( $r->{value}, qr{^(?:a|asset|txn|user|group):}, "row value '$r->{value}' has no shorthand prefix" );
        unlike(
            $r->{value},
            qr{^(?:fsck\.com-rt|fsck\.com-article|asset|transaction|user|group)://},
            "row value '$r->{value}' is not a full local URI"
        );
    }
}

diag "merged from ticket_merge_action.t";
{
    my $q = RT::Test->load_or_create_queue( Name => 'General' );
    my ($main) = RT::Test->create_tickets( { Queue => $q->id }, { Subject => 'merge main' } );

    my $merge_path = RT->Config->Get('WebPath') . '/Helpers/MergeTicket?id=' . $main->id;

    $m->goto_ticket( $main->id );

    $m->content_unlike( qr{<h3[^>]*>\s*Merge\s*</h3>}, 'Links portlet has no Merge section' );

    # The merge modal is now loaded on demand: nothing is pre-rendered into the Display page.
    $m->content_lacks( 'ticket-merge-form', 'merge form is not pre-rendered on Display' );
    $m->content_unlike( qr/Warning: merging is a non-reversible action/, 'no merge warning pre-rendered' );
    $m->content_unlike( qr/name="@{[$main->id]}-MergeInto"/,             'no MergeInto field pre-rendered' );

    $m->content_like( qr/class="[^"]*\bmerge-ticket-modal-link\b[^"]*"\s+href="\Q$merge_path\E"/,
        'Actions menu Merge item links to the MergeTicket helper' );
    $m->content_like(
        qr/class="[^"]*\bdropdown-item\b[^"]*\bmerge-ticket-modal-link\b/,
        'Merge item is a dropdown-item, aligned like the other actions'
    );

    $m->get_ok( $merge_path, 'fetched the merge modal helper' );
    $m->content_contains( 'modal-dialog',                                'helper returns a modal-dialog fragment' );
    $m->content_contains( 'Warning: merging is a non-reversible action', 'helper renders the non-reversible warning' );
    $m->content_like( qr/name="@{[$main->id]}-MergeInto"/, 'helper renders the MergeInto field' );
    $m->content_like( qr{<form[^>]*\bticket-merge-form\b[^>]*hx-post="[^"]*/Helpers/TicketUpdate"},
        'helper form posts to TicketUpdate' );

    # A read-only user (ShowTicket only, no ModifyTicket) gets neither the action nor the helper.
    my $ro = RT::Test->load_or_create_user( Name => 'rouser', Password => 'password' );
    RT::Test->add_rights( { Principal => $ro, Right => [qw(ShowTicket SeeQueue)], Object => $q } );
    our $rom = RT::Test::Web->new;
    ok( $rom->login( 'rouser', 'password' ), 'read-only user logged in' );

    $rom->get_ok( $baseurl . '/Ticket/Display.html?id=' . $main->id );
    $rom->content_lacks( 'merge-ticket-modal-link', 'read-only user has no Merge action' );

    $rom->get($merge_path);
    $rom->content_lacks( $main->id . '-MergeInto', 'read-only user is denied the merge modal helper' );
    $rom->warning_like( qr/Permission Denied/, 'denied helper request logs the expected Permission Denied warning' );

    # A successful merge via TicketUpdate redirects to the surviving ticket.
    my ($src) = RT::Test->create_tickets( { Queue => $q->id }, { Subject => 'merge source' } );
    my ($dst) = RT::Test->create_tickets( { Queue => $q->id }, { Subject => 'merge target' } );

    $m->post( $baseurl . '/Helpers/TicketUpdate', { id => $src->id, $src->id . '-MergeInto' => $dst->id } );
    is( $m->response->header('HX-Redirect'),
        RT->Config->Get('WebPath') . '/Ticket/Display.html?id=' . $dst->id,
        'merge sets HX-Redirect to the surviving ticket'
      );

    my $reloaded = RT::Ticket->new( RT->SystemUser );
    $reloaded->Load( $src->id );
    is( $reloaded->EffectiveId, $dst->id, 'source ticket merged into target' );

    # A failed merge (into itself) does not redirect and does not merge.
    my ($lone) = RT::Test->create_tickets( { Queue => $q->id }, { Subject => 'lone' } );
    $m->post( $baseurl . '/Helpers/TicketUpdate', { id => $lone->id, $lone->id . '-MergeInto' => $lone->id } );
    ok( !$m->response->header('HX-Redirect'), 'self-merge does not redirect' );
    my $lone_reload = RT::Ticket->new( RT->SystemUser );
    $lone_reload->Load( $lone->id );
    is( $lone_reload->EffectiveId, $lone->id, 'self-merge did not merge' );
}

diag "link custom fields render editable in place in edit mode (not duplicated in Add links)";
{
    my $cfq = RT::Test->load_or_create_queue( Name => 'LinkCFQueue' );
    my $cf  = RT::Test->load_or_create_custom_field(
        Name => 'linkcf', Type => 'FreeformSingle', Queue => $cfq->id,
    );
    ok( $cf->id, 'created a Links-grouping custom field' );
    my $cfid = $cf->id;
    my ($t) = RT::Test->create_tickets( { Queue => $cfq->id }, { Subject => 'link cf edit' } );
    my $tid = $t->id;

    # Edit mode renders the Links CF as a single editable input in the listing, where the read-only
    # value shows, not as a read-only row plus a separate input in the "Add links" section.
    $m->get_ok( $baseurl . '/Views/Component/EditLinks?ObjectType=RT::Ticket&ObjectId=' . $tid,
        'fetch the edit component' );
    my $edit_inputs = () = $m->content =~ /name="[^"]*CustomField:Links-$cfid-Value"/g;
    is( $edit_inputs, 1, 'edit mode renders the Links CF as a single editable input, in place' );
    $m->content_lacks( 'edit-custom-fields-container',
        'no duplicate Add-links custom field block when editing an existing object' );

    $m->get_ok( $baseurl . '/Views/Component/ShowLinks?ObjectType=RT::Ticket&ObjectId=' . $tid,
        'fetch the display component' );
    my $disp_inputs = () = $m->content =~ /name="[^"]*CustomField:Links-$cfid-Value"/g;
    is( $disp_inputs, 0, 'display mode renders the Links CF read-only (no editable input)' );

    # The inner list target listens for the CF event so a saved CF edit refreshes the listing without
    # wiping the outer container's add-link rows.
    $m->goto_ticket($tid);
    $m->content_like(
        qr/links-edit-target[^>]*hx-trigger="[^"]*ticketCustomFieldsChanged/,
        'inner links list refreshes on the custom-field event'
    );

    # End-to-end: a CF save fires the event and is reflected by a ShowLinks refetch.
    $m->post(
        $baseurl . '/Helpers/TicketUpdate',
        {   id                                                           => $tid,
            "Object-RT::Ticket-$tid-CustomField:Links-$cfid-Value"       => 'cf-reflected',
            "Object-RT::Ticket-$tid-CustomField:Links-$cfid-Value-Magic" => 1,
        }
    );
    like( $m->response->header('HX-Trigger') // '', qr/ticketCustomFieldsChanged/,
        'saving the link custom field fires the custom-field event' );
    $m->get_ok( $baseurl . '/Views/Component/ShowLinks?ObjectType=RT::Ticket&ObjectId=' . $tid,
        'refetch the display after the CF save' );
    $m->content_contains( 'cf-reflected', 'display reflects the new custom field value' );
}

diag "every populated section renders with its rows (client filter drops sections whose rows are all hidden)";
{
    my $sq = RT::Test->load_or_create_queue( Name => 'SectionHideQueue' );
    my ( $sh_main, $sh_dep, $sh_ref ) = RT::Test->create_tickets(
        { Queue => $sq->id },
        { Subject => 'section-hide main' },
        { Subject => 'alpha-section-target' },
        { Subject => 'beta-section-target' },
    );
    $sh_main->AddLink( Type => 'DependsOn', Target => $sh_dep->id );
    $sh_main->AddLink( Type => 'RefersTo',  Target => $sh_ref->id );
    my $shid = $sh_main->id;

    $m->get_ok( $baseurl . "/Views/Component/ShowLinks?ObjectType=RT::Ticket&ObjectId=$shid", 'links rendered' );
    $m->content_contains( 'links-section-DependsOn', 'DependsOn section present' );
    $m->content_contains( 'links-section-RefersTo',  'RefersTo section present' );
    $m->content_contains( 'alpha-section-target', 'DependsOn target rendered' );
    $m->content_contains( 'beta-section-target',  'RefersTo target rendered' );
}

diag 'Links editor autocomplete exclusions (data-link-excludes on AddLinks)';
{
    my $main  = RT::Test->create_ticket( Queue => 'General', Subject => 'exclude main' );
    my $dep   = RT::Test->create_ticket( Queue => 'General', Subject => 'exclude dep' );
    my $depby = RT::Test->create_ticket( Queue => 'General', Subject => 'exclude depby' );
    my $ref   = RT::Test->create_ticket( Queue => 'General', Subject => 'exclude ref' );

    ok( ( $main->AddLink( Type => 'DependsOn', Target => $dep->id ) )[0],   'main DependsOn dep' );
    ok( ( $main->AddLink( Type => 'DependsOn', Base   => $depby->id ) )[0], 'depby DependsOn main (DependedOnBy)' );
    ok( ( $main->AddLink( Type => 'RefersTo',  Target => $ref->id ) )[0],   'main RefersTo ref' );

    $m->get_ok( $baseurl . '/Views/Component/EditLinks?ObjectType=RT::Ticket&ObjectId=' . $main->id,
        'fetched the links editor' );
    my $node = $m->dom->at('.add-links-section');
    ok( $node, 'editor has an .add-links-section' );
    my $excludes = from_json( $node->attr('data-link-excludes') );

    my %dep_ids = map { $_ => 1 } split /\s+/, ( $excludes->{DependsOn}{ticket} // '' );
    ok( $dep_ids{ $dep->id },   'DependsOn family excludes the DependsOn target' );
    ok( $dep_ids{ $depby->id }, 'DependsOn family excludes the DependedOnBy base (both directions)' );
    ok( $dep_ids{ $main->id },  'DependsOn family excludes the object itself' );
    ok( !$dep_ids{ $ref->id },  'DependsOn family does not exclude a RefersTo target' );

    my %ref_ids = map { $_ => 1 } split /\s+/, ( $excludes->{RefersTo}{ticket} // '' );
    ok( $ref_ids{ $ref->id },  'RefersTo family excludes the RefersTo target' );
    ok( !$ref_ids{ $dep->id }, 'RefersTo family does not exclude a DependsOn target' );
}

diag 'Links table row ordering: id asc for tickets, Name asc for users';
{
    my $org = RT->Config->Get('Organization');

    # Tickets: link three targets OUT of id order; the table must render them id-ascending.
    my $tmain = RT::Test->create_ticket( Queue => 'General', Subject => 'order ticket main' );
    my @t = map { RT::Test->create_ticket( Queue => 'General', Subject => "order ticket $_" ) } 1 .. 3;
    my @tids = sort { $a <=> $b } map { $_->id } @t;
    $tmain->AddLink( Type => 'RefersTo', Target => $t[2]->id );    # link in 3, 1, 2 order
    $tmain->AddLink( Type => 'RefersTo', Target => $t[0]->id );
    $tmain->AddLink( Type => 'RefersTo', Target => $t[1]->id );

    $m->get_ok( $baseurl . '/Views/Component/ShowLinks?ObjectType=RT::Ticket&ObjectId=' . $tmain->id,
        'fetched ShowLinks for the ticket-order case' );
    my $trows = $m->dom->find(
        '#links-section-RefersTo .links-type-table[data-links-object-type="Ticket"] tbody tr[data-record-id]'
    )->map( sub { $_->attr('data-record-id') } )->to_array;
    is_deeply( $trows, [ map {"$_"} @tids ],
        'ticket rows render in id-ascending order regardless of link order' );

    # Users: names anti-correlated with creation/id order, so id-order != Name-order.
    my $umain = RT::Test->create_ticket( Queue => 'General', Subject => 'order user main' );
    my %uid;
    for my $label (qw/charlie alice bob/) {    # creation order -> ascending ids
        my $u = RT::User->new( RT->SystemUser );
        $u->Create( Name => "order-$label-$$", Privileged => 1 );
        $uid{$label} = $u->id;
        $umain->AddLink( Type => 'RefersTo', Target => "user://$org/" . $u->id );
    }
    my @expected_uids = ( $uid{alice}, $uid{bob}, $uid{charlie} );    # Name-ascending

    $m->get_ok( $baseurl . '/Views/Component/ShowLinks?ObjectType=RT::Ticket&ObjectId=' . $umain->id,
        'fetched ShowLinks for the user-order case' );
    my $urows = $m->dom->find(
        '#links-section-RefersTo .links-type-table[data-links-object-type="User"] tbody tr[data-record-id]'
    )->map( sub { $_->attr('data-record-id') } )->to_array;
    is_deeply( $urows, [ map {"$_"} @expected_uids ],
        'user rows render in Name-ascending order, not id order' );
}

diag 'DualMode children tree: depth-1 rows carry a trash delete link';
{
    my $parent = RT::Test->create_ticket( Queue => 'General', Subject => 'tree parent' );
    my $child  = RT::Test->create_ticket( Queue => 'General', Subject => 'tree child' );
    my $gchild = RT::Test->create_ticket( Queue => 'General', Subject => 'tree grandchild' );
    $parent->AddLink( Type => 'MemberOf', Base => $child->id );
    $child->AddLink(  Type => 'MemberOf', Base => $gchild->id );

    $m->get_ok(
        $baseurl . '/Views/Component/ShowLinks?ObjectType=RT::Ticket&ObjectId=' . $parent->id . '&DualMode=1',
        'fetched DualMode tree'
    );

    # In DualMode the direct child (depth 1) gets a trash link (hx-post) not a checkbox.
    $m->content_like(
        qr{<a[^>]*class="[^"]*delete-link[^"]*"[^>]*hx-post="[^"]*/Helpers/TicketUpdate},
        'depth-1 child row has a MemberOf trash link in DualMode'
    );
    # Display mode renders every depth. Deeper rows carry a CSS-hidden delete cell; their visibility
    # is CSS-gated and asserted in the Playwright suite, not here.
    $m->content_like( qr/data-depth="2"/, 'grandchild row rendered at depth 2' );
}

diag 'DualMode: one render carries read-only + edit affordances';
{
    my $parent = RT::Test->create_ticket( Queue => 'General', Subject => 'dual parent' );
    my $child  = RT::Test->create_ticket( Queue => 'General', Subject => 'dual child' );
    my $dep    = RT::Test->create_ticket( Queue => 'General', Subject => 'dual dep' );
    $parent->AddLink( Type => 'MemberOf',  Base   => $child->id );   # child is a Member of parent
    $parent->AddLink( Type => 'DependsOn', Target => $dep->id );

    my $base = $baseurl
        . '/Views/Component/ShowLinks?ObjectType=RT::Ticket&ObjectId=' . $parent->id;

    $m->get_ok( $base . '&DualMode=1', 'fetched ShowLinks in DualMode' );
    $m->content_like( qr/delete-link/, 'DualMode emits delete checkboxes' );
    $m->content_like( qr/links-tree/,  'DualMode renders the children tree' );
    $m->content_like( qr/links-cf-display/, 'DualMode renders the read-only CF block' );
    $m->content_like( qr/links-cf-edit/,    'DualMode renders the editable CF block' );

    $m->get_ok( $base, 'fetched ShowLinks without DualMode' );
    $m->content_unlike( qr/delete-link/, 'plain ShowLinks emits no delete checkboxes' );
    $m->content_unlike( qr/links-cf-edit/, 'plain ShowLinks does not render the editable CF block' );
}

diag 'EditLinks forwards DualMode to its inner ShowLinks and refresh URL';
{
    my $t = RT::Test->create_ticket( Queue => 'General', Subject => 'editlinks dual' );
    my $d = RT::Test->create_ticket( Queue => 'General', Subject => 'editlinks dual dep' );
    $t->AddLink( Type => 'DependsOn', Target => $d->id );

    $m->get_ok(
        $baseurl . '/Views/Component/EditLinks?ObjectType=RT::Ticket&ObjectId=' . $t->id . '&DualMode=1',
        'fetched EditLinks in DualMode'
    );
    $m->content_like( qr/links-cf-display/, 'EditLinks DualMode renders the read-only CF block' );
    $m->content_like(
        qr{Views/Component/ShowLinks\?[^"]*DualMode=1},
        'inner list refresh URL carries DualMode=1'
    );
}

diag 'Ticket Links widget renders one unified body inside the edit form';
{
    my $t = RT::Test->create_ticket( Queue => 'General', Subject => 'widget unify' );
    my $d = RT::Test->create_ticket( Queue => 'General', Subject => 'widget unify dep' );
    $t->AddLink( Type => 'DependsOn', Target => $d->id );

    $m->get_ok( $baseurl . '/Ticket/Display.html?id=' . $t->id, 'loaded ticket display' );

    $m->content_like( qr/links-edit-container/, 'editable container rendered' );
    $m->content_unlike( qr/links-display-target/, 'no separate display-only list' );
    $m->content_like( qr/delete-link/, 'delete affordances present in the unified body' );
    $m->content_like( qr/class="[^"]*\blinks-widget\b/, 'titlebox carries links-widget class' );
}

diag 'DualMode widget: trash link replaces the delete checkbox';
{
    my $q = RT::Test->load_or_create_queue( Name => 'General' );
    my ($main) = RT::Test->create_tickets( { Queue => $q->id }, { Subject => 'trash link main' } );
    my ($dep)  = RT::Test->create_tickets( { Queue => $q->id }, { Subject => 'trash link dep' } );
    $main->AddLink( Type => 'DependsOn', Target => $dep->id );

    $m->get_ok( $baseurl . '/Ticket/Display.html?id=' . $main->id, 'widget display (DualMode)' );
    $m->content_like(
        qr{<a[^>]*class="[^"]*delete-link[^"]*"[^>]*hx-post="[^"]*/Helpers/TicketUpdate},
        'widget renders a trash link that posts to TicketUpdate' );
    $m->content_like( qr{hx-vals=["'][^"']*DeleteLink-}, 'trash link carries a DeleteLink param' );
    $m->content_unlike( qr{type="checkbox"[^>]*class="[^"]*delete-link}, 'widget has no delete checkbox' );
    $m->content_unlike( qr/links-removal-count/, 'no removal counter in the widget' );
}

done_testing;

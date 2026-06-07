use strict;
use warnings;

use RT::Test tests => undef, playwright => 1;
use RT::Interface::Web;

my ( $url, $p ) = RT::Test->started_ok;

$p->login();

my $queue = RT::Test->load_or_create_queue( Name => 'General' );

my @deps = RT::Test->create_tickets( { Queue => $queue->id }, map { { Subject => "filterdep $_" } } 1 .. 8 );
my ($main) = RT::Test->create_tickets( { Queue => $queue->id }, { Subject => 'filter main' } );
{
    my $t = RT::Ticket->new( RT->SystemUser );
    $t->Load( $main->id );
    $t->AddLink( Type => 'DependsOn', Target => $_->id ) for @deps;
}
my $main_id = $main->id;

$p->goto_ticket($main_id);

$p->wait_for_element('div.ticket-info-links .links-filter-form input[name="Search"]');

diag "Display mode: the client filter hides non-matching rows (no reload)";
{
    my $search = 'div.ticket-info-links .links-filter-form input[name="Search"]';
    $p->{page}->fill( $search, 'filterdep 8' );
    $p->{page}->dispatchEvent( $search, 'input' );
    $p->{handle}->await(
        $p->{page}->waitForFunction(
            <<'JS'
(function() {
    const target = document.querySelector('div.ticket-info-links .links-edit-target');
    if (!target) return false;
    const rows = target.querySelectorAll('tbody tr');
    if (rows.length < 2) return false;
    const visible = []; let hidden = 0;
    rows.forEach(function(r) {
        if (r.classList.contains('d-none')) hidden++;
        else visible.push(r.textContent);
    });
    // The matching dep-8 row stays visible; every other row stays in the DOM but hidden via d-none.
    return visible.length === 1
        && /filterdep 8\b/.test(visible[0])
        && hidden >= 1;
})()
JS
            , {}, { timeout => 10000 }
        )
    );
    pass('display search leaves the single matching dependency visible and hides the rest with d-none');

    $p->{page}->fill( $search, '' );
    $p->{page}->dispatchEvent( $search, 'input' );
}

diag 'Filter/search state set in display mode persists into edit mode';
{
    $p->goto_ticket($main_id);
    $p->wait_for_element('div.ticket-info-links .links-filter-form input[name="Search"]');

    $p->{page}->fill( 'div.ticket-info-links .links-filter-form input[name="Search"]', 'filterdep 8' );
    $p->{page}->dispatchEvent( 'div.ticket-info-links .links-filter-form input[name="Search"]', 'input' );

    $p->{page}->click('div.ticket-info-links a.inline-edit-toggle.edit');

    $p->{handle}->await(
        $p->{page}->waitForFunction(
            <<'JS'
(function() {
    const forms = document.querySelectorAll('div.ticket-info-links .links-filter-form');
    if (forms.length !== 1) return false;
    const box = forms[0].querySelector('input[name="Search"]');
    if (!box || box.value !== 'filterdep 8') return false;
    const t = document.querySelector('div.ticket-info-links .links-edit-target');
    if (!t) return false;
    const rows = t.querySelectorAll('tbody tr');
    const visible = [];
    rows.forEach(function(r){ if (!r.classList.contains('d-none')) visible.push(r.textContent); });
    return visible.length === 1 && /filterdep 8\b/.test(visible[0]);
})()
JS
            , {}, { timeout => 10000 }
        )
    );
    pass('search term and filtering carried from display into edit mode');

    $p->{handle}->await(
        $p->{page}->waitForFunction(
            <<'JS'
(function() {
    const boxes = document.querySelectorAll('div.ticket-info-links .links-edit-target .delete-link');
    if (!boxes.length) return false;
    return Array.prototype.some.call(boxes, function(box) { return box.offsetParent !== null; });
})()
JS
            , {}, { timeout => 10000 }
        )
    );
    pass('delete trash links are visible in edit mode');
}

diag "Edit mode: the client filter hides non-matching rows";
{
    $p->goto_ticket($main_id);
    $p->wait_for_element('div.ticket-info-links .links-filter-form input[name="Search"]');

    $p->{page}->click('div.ticket-info-links a.inline-edit-toggle.edit');
    $p->wait_for_element('div.ticket-info-links.editing');

    $p->wait_for_element( 'div.ticket-info-links .links-edit-target tbody tr',
        { timeout => 10000 } );

    my $search = 'div.ticket-info-links .links-filter-form input[name="Search"]';
    $p->{page}->fill( $search, 'filterdep 8' );
    $p->{page}->dispatchEvent( $search, 'input' );

    $p->{handle}->await(
        $p->{page}->waitForFunction(
            <<'JS'
(function() {
    const root = document.querySelector('div.ticket-info-links .links-edit-target');
    if (!root) return false;
    const rows = root.querySelectorAll('tbody tr');
    const visible = []; let hidden = 0;
    rows.forEach(function(r) {
        if (r.classList.contains('d-none')) hidden++;
        else visible.push(r.textContent);
    });
    // Exactly one row stays visible and it is the dep-8 row; the rest are hidden.
    return visible.length === 1
        && /filterdep 8/.test(visible[0])
        && hidden >= 1;
})()
JS
            , {}, { timeout => 10000 }
        )
    );

    my $visible_count
        = $p->{page}->evaluate(
        'return Array.prototype.filter.call(document.querySelectorAll("div.ticket-info-links .links-edit-target tbody tr"), function(r){ return !r.classList.contains("d-none"); }).length'
        );
    is( $visible_count, 1, 'edit filter leaves exactly one matching row visible' );

    my $hidden_has_dep1
        = $p->{page}->evaluate(
        'return Array.prototype.some.call(document.querySelectorAll("div.ticket-info-links .links-edit-target tbody tr"), function(r){ return r.classList.contains("d-none") && /filterdep 1\\b/.test(r.textContent); })'
        );
    ok( $hidden_has_dep1, 'a non-matching row (filterdep 1) is hidden with .d-none, not removed from the DOM' );
}

diag "Edit mode: the client filter ignores hidden inline-edit <select> option text";
{
    my $search = 'div.ticket-info-links .links-filter-form input[name="Search"]';
    $p->{page}->fill( $search, 'resolved' );
    $p->{page}->dispatchEvent( $search, 'input' );

    $p->{handle}->await(
        $p->{page}->waitForFunction(
            <<'JS'
(function() {
    const root = document.querySelector('div.ticket-info-links .links-edit-target');
    if (!root) return false;
    const rows = root.querySelectorAll('tbody tr');
    if (!rows.length) return false;
    const visible = Array.prototype.filter.call(rows, function(r){ return !r.classList.contains('d-none'); }).length;
    return visible === 0;
})()
JS
            , {}, { timeout => 10000 }
        )
    );

    my $visible = $p->{page}->evaluate(
        'return Array.prototype.filter.call(document.querySelectorAll("div.ticket-info-links .links-edit-target tbody tr"), function(r){ return !r.classList.contains("d-none"); }).length'
    );
    is( $visible, 0, 'a value present only in the hidden inline-edit <select> (not in any visible cell) matches no rows' );
}

diag "Edit mode: deselecting an object type hides the table AND its empty section";
{
    my $search = 'div.ticket-info-links .links-filter-form input[name="Search"]';
    $p->{page}->fill( $search, '' );
    $p->{page}->dispatchEvent( $search, 'input' );

    $p->{page}->click('div.ticket-info-links .links-filter-form .links-filter-toggle .links-filter');
    $p->wait_for_element(
        'div.ticket-info-links .links-filter-form input[name="ShowObjectType"][value="Ticket"]');
    $p->{page}->uncheck(
        'div.ticket-info-links .links-filter-form input[name="ShowObjectType"][value="Ticket"]');
    $p->{page}->click('div.ticket-info-links .links-filter-form .links-filter-apply');

    $p->{handle}->await(
        $p->{page}->waitForFunction(
            <<'JS'
(function() {
    const root    = document.querySelector('div.ticket-info-links .links-edit-target');
    if (!root) return false;
    const table   = root.querySelector('.links-type-table[data-links-object-type="Ticket"]');
    const section = root.querySelector('[id="links-section-DependsOn"]');
    const visibleTicketRows = table
        ? Array.prototype.filter.call(table.querySelectorAll('tbody tr'), function(r){ return !r.classList.contains('d-none'); }).length
        : 0;
    return visibleTicketRows === 0
        && table && table.classList.contains('d-none')
        && section && section.classList.contains('d-none');
})()
JS
            , {}, { timeout => 10000 }
        )
    );

    my $table_hidden
        = $p->{page}->evaluate(
        'return document.querySelector("div.ticket-info-links .links-edit-target .links-type-table[data-links-object-type=\'Ticket\']").classList.contains("d-none")'
        );
    ok( $table_hidden, 'the emptied ticket table hides itself (header included)' );

    my $section_hidden
        = $p->{page}->evaluate(
        'return document.querySelector("div.ticket-info-links .links-edit-target [id=\'links-section-DependsOn\']").classList.contains("d-none")'
        );
    ok( $section_hidden,
        'the DependsOn section hides when its only (ticket) table is emptied by the object-type filter' );

    my $ticket_rows_visible
        = $p->{page}->evaluate(
        'const t = document.querySelector("div.ticket-info-links .links-edit-target .links-type-table[data-links-object-type=\'Ticket\']"); return t ? Array.prototype.filter.call(t.querySelectorAll("tbody tr"), function(r){ return !r.classList.contains("d-none"); }).length : 0'
        );
    is( $ticket_rows_visible, 0, 'no ticket rows remain visible after deselecting the Ticket object type' );
}

diag "The filter bar reveals/hides as links are added/removed without a reload";
{
    my ($nolinks)  = RT::Test->create_tickets( { Queue => $queue->id }, { Subject => 'reload host' } );
    my ($other)    = RT::Test->create_tickets( { Queue => $queue->id }, { Subject => 'reload target other' } );
    my $nolinks_id = $nolinks->id;
    my $other_id   = $other->id;

    $p->goto_ticket($nolinks_id);
    $p->wait_for_element( 'div.ticket-info-links .links-edit-target', { state => 'attached' } );

    my $hidden_initially
        = $p->{page}->evaluate('const f = document.querySelector("div.ticket-info-links .links-filter-form"); return f ? f.classList.contains("d-none") : false');
    ok( $hidden_initially, 'filter bar is present but hidden (d-none) on a ticket with no links' );

    {
        my $t = RT::Ticket->new( RT->SystemUser );
        $t->Load($nolinks_id);
        my ( $ok, $msg ) = $t->AddLink( Type => 'RefersTo', Target => $other_id );
        ok( $ok, "added first link: $msg" );
    }
    $p->{page}->evaluate("htmx.trigger(document.body, 'ticketLinksChanged')");

    $p->{handle}->await(
        $p->{page}->waitForFunction(
            <<'JS'
(function() {
    const form   = document.querySelector('div.ticket-info-links .links-filter-form');
    const target = document.querySelector('div.ticket-info-links .links-edit-target');
    return form && !form.classList.contains('d-none')
        && target && /reload target other/.test(target.textContent);
})()
JS
            , {}, { timeout => 10000 }
        )
    );

    my $shown_after_add
        = $p->{page}->evaluate(
        'const f = document.querySelector("div.ticket-info-links .links-filter-form"); return f ? !f.classList.contains("d-none") : false'
        );
    ok( $shown_after_add, 'filter bar appears after the first link is added (no reload)' );

    {
        my $t = RT::Ticket->new( RT->SystemUser );
        $t->Load($nolinks_id);
        my ( $ok, $msg ) = $t->DeleteLink( Type => 'RefersTo', Target => $other_id );
        ok( $ok, "removed last link: $msg" );
    }
    $p->{page}->evaluate("htmx.trigger(document.body, 'ticketLinksChanged')");

    $p->{handle}->await(
        $p->{page}->waitForFunction(
            <<'JS'
(function() {
    const form   = document.querySelector('div.ticket-info-links .links-filter-form');
    const target = document.querySelector('div.ticket-info-links .links-edit-target');
    // EditLinks omits the bar once the object has no links again; the target re-renders empty.
    return (!form || form.classList.contains('d-none'))
        && target && !/reload target other/.test(target.textContent);
})()
JS
            , {}, { timeout => 10000 }
        )
    );

    my $hidden_after_remove
        = $p->{page}->evaluate(
        'const f = document.querySelector("div.ticket-info-links .links-filter-form"); return f ? f.classList.contains("d-none") : true'
        );
    ok( $hidden_after_remove, 'filter bar goes away again after the last link is removed (no reload)' );
}

diag "Edit mode: a visible non-subject column is searched; a sibling table can hide while its section stays";
{
    my ($mt)  = RT::Test->create_tickets( { Queue => $queue->id }, { Subject => 'multitable host' } );
    my ($mtt) = RT::Test->create_tickets( { Queue => $queue->id }, { Subject => 'multitable ticketdep' } );
    my $txn   = $mtt->Transactions->First;
    {
        my $t = RT::Ticket->new( RT->SystemUser );
        $t->Load( $mt->id );
        my ( $ok1, $m1 ) = $t->AddLink( Type => 'RefersTo', Target => $mtt->id );
        ok( $ok1, "linked ticket: $m1" );
        my ( $ok2, $m2 ) = $t->AddLink( Type => 'RefersTo', Target => 'txn:' . $txn->id );
        ok( $ok2, "linked transaction (object column shows '@{[$mtt->Subject]}'): $m2" );
    }

    $p->goto_ticket( $mt->id );
    $p->{page}->click('div.ticket-info-links a.inline-edit-toggle.edit');
    $p->wait_for_element('div.ticket-info-links.editing');
    $p->wait_for_element(
        'div.ticket-info-links .links-edit-target .links-type-table[data-links-object-type="Transaction"]',
        { timeout => 10000 } );

    my $search = 'div.ticket-info-links .links-filter-form input[name="Search"]';
    $p->{page}->fill( $search, 'ticketdep' );
    $p->{page}->dispatchEvent( $search, 'input' );

    $p->{handle}->await(
        $p->{page}->waitForFunction(
            <<'JS'
(function() {
    const root    = document.querySelector('div.ticket-info-links .links-edit-target');
    if (!root) return false;
    const section = root.querySelector('[id="links-section-RefersTo"]');
    const tickets = root.querySelector('.links-type-table[data-links-object-type="Ticket"]');
    const txns    = root.querySelector('.links-type-table[data-links-object-type="Transaction"]');
    if (!section || !tickets || !txns) return false;
    const ticketVisible = Array.prototype.some.call(tickets.querySelectorAll('tbody tr'), function(r){ return !r.classList.contains('d-none'); });
    const txnVisible    = Array.prototype.some.call(txns.querySelectorAll('tbody tr'), function(r){ return !r.classList.contains('d-none'); });
    // The shared subject is visible in both tables, so both match and stay; the section stays.
    return ticketVisible
        && txnVisible
        && !tickets.classList.contains('d-none')
        && !txns.classList.contains('d-none')
        && !section.classList.contains('d-none');
})()
JS
            , {}, { timeout => 10000 }
        )
    );

    my $txn_table_visible = $p->{page}->evaluate(
        'return !document.querySelector("div.ticket-info-links .links-edit-target .links-type-table[data-links-object-type=\'Transaction\']").classList.contains("d-none")'
    );
    ok( $txn_table_visible, 'the transaction table matches too -- its visible object column (the linked subject) is searched' );

    my $section_shown = $p->{page}->evaluate(
        'return !document.querySelector("div.ticket-info-links .links-edit-target [id=\'links-section-RefersTo\']").classList.contains("d-none")'
    );
    ok( $section_shown, 'the RefersTo section stays visible because its ticket table still matches' );

    $p->{page}->fill( $search, 'Nobody' );
    $p->{page}->dispatchEvent( $search, 'input' );

    $p->{handle}->await(
        $p->{page}->waitForFunction(
            <<'JS'
(function() {
    const root    = document.querySelector('div.ticket-info-links .links-edit-target');
    if (!root) return false;
    const section = root.querySelector('[id="links-section-RefersTo"]');
    const tickets = root.querySelector('.links-type-table[data-links-object-type="Ticket"]');
    const txns    = root.querySelector('.links-type-table[data-links-object-type="Transaction"]');
    if (!section || !tickets || !txns) return false;
    const ticketVisible = Array.prototype.some.call(tickets.querySelectorAll('tbody tr'), function(r){ return !r.classList.contains('d-none'); });
    // Owner matches the ticket table only; the transaction table empties and hides; the section stays.
    return ticketVisible
        && !tickets.classList.contains('d-none')
        && txns.classList.contains('d-none')
        && !section.classList.contains('d-none');
})()
JS
            , {}, { timeout => 10000 }
        )
    );

    my $txn_hidden_owner = $p->{page}->evaluate(
        'return document.querySelector("div.ticket-info-links .links-edit-target .links-type-table[data-links-object-type=\'Transaction\']").classList.contains("d-none")'
    );
    ok( $txn_hidden_owner, 'searching the ticket owner hides the transaction table (no owner column) while the section stays' );
}

diag "Display mode: Hide inactive hides the record-inactive row client-side";
{
    my ($host)   = RT::Test->create_tickets( { Queue => $queue->id }, { Subject => 'hideinactive host' } );
    my ($active) = RT::Test->create_tickets( { Queue => $queue->id }, { Subject => 'hideinactive active dep' } );
    my ($done)   = RT::Test->create_tickets( { Queue => $queue->id }, { Subject => 'hideinactive resolved dep' } );
    {
        my $t = RT::Ticket->new( RT->SystemUser );
        $t->Load( $host->id );
        $t->AddLink( Type => 'DependsOn', Target => $active->id );
        $t->AddLink( Type => 'DependsOn', Target => $done->id );
        my $d = RT::Ticket->new( RT->SystemUser );
        $d->Load( $done->id );
        my ( $ok, $msg ) = $d->SetStatus('resolved');
        ok( $ok, "resolved the inactive dependency: $msg" );
    }

    $p->goto_ticket( $host->id );
    $p->wait_for_element('.links-filter-form input[name="Search"]');

    $p->{page}->click('.links-filter-form .links-filter-toggle .links-filter');
    $p->wait_for_element('.links-filter-form input[name="HideInactive"]');
    $p->{page}->check('.links-filter-form input[name="HideInactive"]');
    $p->{page}->click('.links-filter-form .links-filter-apply');

    $p->{handle}->await(
        $p->{page}->waitForFunction(
            <<'JS'
(function() {
    const target = document.querySelector('.links-edit-target');
    if (!target) return false;
    const rows = target.querySelectorAll('tbody tr');
    if (rows.length < 2) return false;
    let activeShown = false, inactiveHidden = false;
    rows.forEach(function(r) {
        if (/hideinactive active dep/.test(r.textContent) && !r.classList.contains('d-none')) activeShown = true;
        if (/hideinactive resolved dep/.test(r.textContent) && r.classList.contains('d-none')) inactiveHidden = true;
    });
    // The resolved (record-inactive) row stays in the DOM but carries d-none; the active row stays visible.
    return activeShown && inactiveHidden;
})()
JS
            , {}, { timeout => 10000 }
        )
    );

    my $active_shown = $p->{page}->evaluate(
        'return Array.prototype.some.call(document.querySelectorAll(".links-edit-target tbody tr"), function(r){ return /hideinactive active dep/.test(r.textContent) && !r.classList.contains("d-none"); })'
    );
    ok( $active_shown, 'active dependency stays visible' );

    my $inactive_hidden = $p->{page}->evaluate(
        'return Array.prototype.some.call(document.querySelectorAll(".links-edit-target tbody tr"), function(r){ return /hideinactive resolved dep/.test(r.textContent) && r.classList.contains("d-none"); })'
    );
    ok( $inactive_hidden, 'resolved dependency stays in the DOM but is hidden with d-none' );
}

diag "Edit mode: Hide inactive hides the record-inactive row client-side";
{
    my ($host)   = RT::Test->create_tickets( { Queue => $queue->id }, { Subject => 'hideinactive edit host' } );
    my ($active) = RT::Test->create_tickets( { Queue => $queue->id }, { Subject => 'hideinactive edit active' } );
    my ($done)   = RT::Test->create_tickets( { Queue => $queue->id }, { Subject => 'hideinactive edit resolved' } );
    {
        my $t = RT::Ticket->new( RT->SystemUser );
        $t->Load( $host->id );
        $t->AddLink( Type => 'DependsOn', Target => $active->id );
        $t->AddLink( Type => 'DependsOn', Target => $done->id );
        my $d = RT::Ticket->new( RT->SystemUser );
        $d->Load( $done->id );
        $d->SetStatus('resolved');
    }

    $p->goto_ticket( $host->id );
    $p->{page}->click('div.ticket-info-links a.inline-edit-toggle.edit');
    $p->wait_for_element('div.ticket-info-links.editing');
    $p->wait_for_element(
        'div.ticket-info-links .links-edit-target tbody tr.record-inactive',
        { timeout => 10000 } );

    my $form = 'div.ticket-info-links .links-filter-form';
    $p->{page}->click("$form .links-filter-toggle .links-filter");
    $p->wait_for_element("$form input[name=\"HideInactive\"]");
    $p->{page}->check("$form input[name=\"HideInactive\"]");
    $p->{page}->click("$form .links-filter-apply");

    $p->{handle}->await(
        $p->{page}->waitForFunction(
            <<'JS'
(function() {
    const root = document.querySelector('div.ticket-info-links .links-edit-target');
    if (!root) return false;
    const rows = root.querySelectorAll('tbody tr');
    if (!rows.length) return false;
    const inactiveHidden = Array.prototype.every.call(
        root.querySelectorAll('tbody tr.record-inactive'),
        function(r){ return r.classList.contains('d-none'); });
    const activeShown = Array.prototype.some.call(
        rows,
        function(r){ return !r.classList.contains('record-inactive') && !r.classList.contains('d-none'); });
    return inactiveHidden && activeShown;
})()
JS
            , {}, { timeout => 10000 }
        )
    );

    my $inactive_hidden = $p->{page}->evaluate(
        'return Array.prototype.every.call(document.querySelectorAll("div.ticket-info-links .links-edit-target tbody tr.record-inactive"), function(r){ return r.classList.contains("d-none"); })'
    );
    ok( $inactive_hidden, 'the resolved (record-inactive) row is hidden when Hide inactive is checked' );

    my $active_shown = $p->{page}->evaluate(
        'return Array.prototype.some.call(document.querySelectorAll("div.ticket-info-links .links-edit-target tbody tr"), function(r){ return !r.classList.contains("record-inactive") && !r.classList.contains("d-none"); })'
    );
    ok( $active_shown, 'the active row stays visible' );
}

diag "Edit mode: a configured HideInactive default hides resolved rows on load";
{
    my $q = RT::Test->load_or_create_queue( Name => 'General' );
    my ($act) = RT::Test->create_tickets( { Queue => $q->id }, { Subject => 'lwp active' } );
    my ($res) = RT::Test->create_tickets( { Queue => $q->id }, { Subject => 'lwp resolved' } );
    $res->SetStatus('resolved');
    my ($m2) = RT::Test->create_tickets( { Queue => $q->id }, { Subject => 'lwp main' } );
    $m2->AddLink( Type => 'DependsOn', Target => $act->id );
    $m2->AddLink( Type => 'DependsOn', Target => $res->id );

    my ($cfg_ok, $cfg_msg) = HTML::Mason::Commands::UpdateConfig(
        Name  => 'PageLayouts',
        Value => {
            'RT::Ticket' => { 'Display' => { Default => [
                { Layout => 'col-12', Elements => [ { Name => 'Links', HideInactive => 1 } ] },
            ] } },
        },
        CurrentUser => RT->SystemUser,
    );
    ok( $cfg_ok, "configured Links HideInactive default" ) or diag $cfg_msg;

    $p->goto_ticket( $m2->id );
    $p->wait_for_element('.links-edit-target [data-record-id="' . $act->id . '"]');
    $p->{handle}->await(
        $p->{page}->waitForFunction(
            '(function() { const r = document.querySelector(".links-edit-target [data-record-id=\'' . $res->id
                . '\']"); return r ? r.classList.contains("d-none") : false; })()',
            {}, { timeout => 10000 }
        )
    );
    my $res_hidden_display = $p->{page}->evaluate(
        'const r = document.querySelector(".links-edit-target [data-record-id=\'' . $res->id
            . '\']"); return r ? r.classList.contains("d-none") : null'
    );
    ok( $res_hidden_display, 'resolved dependency stays in the display DOM but is hidden via the configured default' );

    $p->{page}->click('div.ticket-info-links a.inline-edit-toggle.edit');
    $p->wait_for_element('div.ticket-info-links.editing');

    $p->{handle}->await(
        $p->{page}->waitForFunction(
            <<'JS'
(function() {
    const root = document.querySelector('div.ticket-info-links .links-edit-target');
    if (!root) return false;
    const rows = root.querySelectorAll('tbody tr');
    if (!rows.length) return false;
    // All rows loaded; the record-inactive one must be d-none (clientFilter default applied).
    const inactiveRows = root.querySelectorAll('tbody tr.record-inactive');
    return inactiveRows.length > 0 &&
        Array.prototype.every.call(inactiveRows, function(r) { return r.classList.contains('d-none'); });
})()
JS
            , {}, { timeout => 10000 }
        )
    );
    my $res_hidden = $p->{page}->evaluate(
        'const r = document.querySelector("div.ticket-info-links .links-edit-target [data-record-id=\'' . $res->id . '\']"); return r ? r.classList.contains("d-none") : null'
    );
    ok( $res_hidden, 'edit mode hides the resolved dependency row via the configured default' );
}

diag "Display mode: filtering the children tree keeps a deep match plus its ancestor chain";
{
    my ($root)  = RT::Test->create_tickets( { Queue => $queue->id }, { Subject => 'tree root' } );
    my ($child) = RT::Test->create_tickets( { Queue => $queue->id }, { Subject => 'tree child' } );
    my ($gkid)  = RT::Test->create_tickets( { Queue => $queue->id }, { Subject => 'tree grandkid' } );
    my ($other) = RT::Test->create_tickets( { Queue => $queue->id }, { Subject => 'tree other' } );
    {
        my $c = RT::Ticket->new( RT->SystemUser );
        $c->Load( $child->id );
        my ( $ok1, $m1 ) = $c->AddLink( Type => 'MemberOf', Target => $root->id );
        ok( $ok1, "child is a member of root: $m1" );
        my $g = RT::Ticket->new( RT->SystemUser );
        $g->Load( $gkid->id );
        my ( $ok2, $m2 ) = $g->AddLink( Type => 'MemberOf', Target => $child->id );
        ok( $ok2, "grandkid is a member of child: $m2" );
        my $o = RT::Ticket->new( RT->SystemUser );
        $o->Load( $other->id );
        my ( $ok3, $m3 ) = $o->AddLink( Type => 'MemberOf', Target => $root->id );
        ok( $ok3, "other is a member of root: $m3" );
    }

    $p->goto_ticket( $root->id );
    $p->wait_for_element(
        '.links-edit-target #links-section-Members .links-tree [data-record-id="' . $gkid->id . '"]',
        { timeout => 10000 } );

    $p->{page}->fill( '.links-filter-form input[name="Search"]', 'grandkid' );
    $p->{page}->dispatchEvent( '.links-filter-form input[name="Search"]', 'input' );

    $p->{handle}->await(
        $p->{page}->waitForFunction(
            '(function() {'
                . 'const tree = document.querySelector(".links-edit-target #links-section-Members .links-tree");'
                . 'if (!tree) return false;'
                . 'const gk = tree.querySelector("[data-record-id=\'' . $gkid->id . '\']");'
                . 'const ch = tree.querySelector("[data-record-id=\'' . $child->id . '\']");'
                . 'const ot = tree.querySelector("[data-record-id=\'' . $other->id . '\']");'
                . 'if (!gk || !ch || !ot) return false;'
                . 'return !gk.classList.contains("d-none") && !ch.classList.contains("d-none")'
                . ' && ot.classList.contains("d-none");'
                . '})()',
            {}, { timeout => 10000 }
        )
    );

    my $gkid_shown = $p->{page}->evaluate(
        'const r = document.querySelector(".links-edit-target #links-section-Members .links-tree [data-record-id=\''
            . $gkid->id . '\']"); return r ? !r.classList.contains("d-none") : null'
    );
    ok( $gkid_shown, 'the matching grandkid row (depth 2) stays visible' );

    my $child_shown = $p->{page}->evaluate(
        'const r = document.querySelector(".links-edit-target #links-section-Members .links-tree [data-record-id=\''
            . $child->id . '\']"); return r ? !r.classList.contains("d-none") : null'
    );
    ok( $child_shown, 'the grandkid ancestor (child, depth 1) is kept visible for context' );

    my $other_hidden = $p->{page}->evaluate(
        'const r = document.querySelector(".links-edit-target #links-section-Members .links-tree [data-record-id=\''
            . $other->id . '\']"); return r ? r.classList.contains("d-none") : null'
    );
    ok( $other_hidden, 'the unrelated sibling branch (other, depth 1) is hidden with d-none' );
}

$p->logout;

done_testing;

use strict;
use warnings;
use Test::Deep;

use RT::Test tests => undef, playwright => 1;
my ( $url, $p ) = RT::Test->started_ok;

$p->login();

my $root = RT::Test->load_or_create_user( Name => 'root' );
my $ticket
    = RT::Test->create_ticket( Queue => 'General', Subject => 'Test inline edit', Requestor => 'root@localhost' );
my $ticket_id = $ticket->Id;

$p->goto_ticket($ticket_id);
ok( $p->{page}->locator('div.date.created')->isVisible, 'Created date is visible' );
ok( $p->{page}->locator('div.date.starts')->isVisible, 'Starts date is visible' );

$p->{page}->locator('#metadata-dropdown')->click;
$p->wait_for_element('[data-show-label="Show unset fields"]');
$p->{page}->locator('[data-show-label="Show unset fields"]')->click;

ok( $p->{page}->locator('div.date.created')->isVisible, 'Created date is still visible' );
ok( $p->{page}->locator('div.date.starts')->isHidden, 'Starts date is hidden' );

$p->get_ok('/Prefs/Other.html');

$p->submit_form_ok(
    {
        form_name => 'ModifyPreferences',
        fields    => { 'HideUnsetFieldsOnDisplay' => 1 },
        button => 'Update',
    },
    'Change preference to hide unset fields on display'
);
$p->content_contains( 'Preferences saved', 'Enabled HideUnsetFieldsOnDisplay' );

$p->goto_ticket($ticket_id);
ok( $p->{page}->locator('div.date.created')->isVisible, 'Created date is still visible' );
ok( $p->{page}->locator('div.date.starts')->isHidden, 'Starts date is hidden' );

$p->{page}->locator('#metadata-dropdown')->click;
$p->wait_for_element('[data-show-label="Show unset fields"]');
$p->{page}->locator('[data-show-label="Show unset fields"]')->click;

ok( $p->{page}->locator('div.date.created')->isVisible, 'Created date is still visible' );
ok( $p->{page}->locator('div.date.starts')->isVisible, 'Starts date is visible' );

diag "Transaction auto-contrast scanner";
{
    my $ac_ticket = RT::Test->create_ticket(
        Queue       => 'General',
        Subject     => 'Auto-contrast test',
        ContentType => 'text/html',
        Content     => '<p style="color: #222222;">Dark text that is unreadable in dark mode</p>',
    );
    my $ac_id   = $ac_ticket->Id;
    my $page    = $p->{page};

    $p->goto_ticket($ac_id);
    $p->wait_for_element('.transaction .messagebody');

    is( $page->locator('.history-container[data-auto-contrast="1"]')->count, 1,
        'history-container emits data-auto-contrast=1' );

    ok( !$page->locator('.transaction .messagebody.auto-contrast')->count,
        'in default (light) theme, messagebody has no .auto-contrast' );

    # Flip to dark theme via MutationObserver path and give the re-scan a tick.
    $page->evaluate(q{document.documentElement.setAttribute('data-bs-theme', 'dark');});
    $p->wait_for_element('.transaction .messagebody.auto-contrast');
    ok( $page->locator('.transaction .messagebody.auto-contrast')->count,
        'after flipping to dark theme, messagebody gains .auto-contrast' );

    # Manual button override: removes auto, pins with contrast-user-original.
    $page->locator('.toggle-contrast-link')->first->click;
    $p->wait_for_element('.transaction .messagebody.contrast-user-original');
    ok( !$page->locator('.transaction .messagebody.auto-contrast')->count,
        'clicking manual button removes .auto-contrast' );
    ok( $page->locator('.transaction .messagebody.contrast-user-original')->count,
        'clicking manual button adds .contrast-user-original' );

    # Theme round-trip: the MutationObserver strips .auto-contrast from
    # non-pinned transactions and re-scans; pinned messagebodies must
    # stay unflipped.
    $page->evaluate(q{document.documentElement.setAttribute('data-bs-theme', 'light');});
    $p->wait_for_element('.transaction .messagebody.contrast-user-original');
    $page->evaluate(q{document.documentElement.setAttribute('data-bs-theme', 'dark');});
    $p->wait_for_element('.transaction .messagebody.contrast-user-original');
    ok( !$page->locator('.transaction .messagebody.auto-contrast')->count,
        'after theme round-trip, user-pinned transaction stays without .auto-contrast' );

    # Disable the config and assert the scanner is inert.
    my $cfg = RT::Configuration->new( RT->SystemUser );
    my ( $r, $msg ) = $cfg->Create(
        Name    => 'TransactionAutoContrast',
        Content => 0,
    );
    ok( $r, "Set TransactionAutoContrast=0: $msg" );

    $p->goto_ticket($ac_id);
    $p->wait_for_element('.transaction .messagebody');
    is( $page->locator('.history-container[data-auto-contrast="0"]')->count, 1,
        'history-container emits data-auto-contrast=0 when config disabled' );

    $page->evaluate(q{document.documentElement.setAttribute('data-bs-theme', 'dark');});
    # Give the MutationObserver a tick; if the scanner were going to
    # apply the class it would have by now.
    my $delay = $page->waitForTimeout(200);
    $p->{handle}->await($delay);
    ok( !$page->locator('.transaction .messagebody.auto-contrast')->count,
        'with config disabled, scanner does not apply .auto-contrast even in dark theme' );

    my $row = RT::Configuration->new( RT->SystemUser );
    $row->LoadByCols( Name => 'TransactionAutoContrast' );
    $row->Delete if $row->Id;
}

$p->logout;

done_testing;

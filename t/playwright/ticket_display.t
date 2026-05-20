use strict;
use warnings;
use Test::Deep;

use RT::Test tests => undef, playwright => 1;

my $linked_queue_name = 'Linked Queue';
my $linked_queue      = RT::Test->load_or_create_queue( Name => $linked_queue_name );
RT->Config->Set( LinkedQueuePortlets => ( General => [ { $linked_queue_name => ['All'] } ], ), );

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

diag "Linked queue portlet pagination";
{
    # Default Rows for the linked-queue portlet is 8, so 9 children
    # forces a second page.
    my $parent = RT::Test->create_ticket(
        Queue   => 'General',
        Subject => 'Parent ticket for linked queue pagination test',
    );
    for my $n ( 1 .. 9 ) {
        RT::Test->create_ticket(
            Queue    => $linked_queue_name,
            Subject  => "Linked queue child $n",
            RefersTo => $parent->Id,
        );
    }

    my $page       = $p->{page};
    my $portlet    = '.linked-queue-portlet';
    my $rows       = "$portlet table.ticket-list tbody tr";
    my $pagination = "$portlet ul.pagination";
    my $page2_link = qq{$pagination a.page-link:has-text("2")};

    $p->goto_ticket( $parent->Id );
    $p->wait_for_element($portlet);

    ok( $page->locator(qq{$pagination a.page-link:has-text("1")})->count, 'page 1 pagination link is present' );
    ok( $page->locator($page2_link)->count,                               'page 2 pagination link is present' );

    is( $page->locator($rows)->count, 8, 'page 1 of linked-queue portlet shows 8 children' );

    $page->locator($page2_link)->first->click;
    $p->wait_for_htmx;

    is( $page->locator($rows)->count, 1, 'page 2 of linked-queue portlet shows 1 child' );
}

$p->logout;

done_testing;

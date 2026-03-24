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

$p->logout;

done_testing;

use strict;
use warnings;

use RT::Test tests => 11;

RT->Config->Set('DisplayTicketAfterQuickCreate' => 0);

my ($baseurl, $m) = RT::Test->started_ok;

ok($m->login, 'logged in');

$m->form_with_fields('Subject', 'Content');
$m->field(Subject => 'from quick create');
$m->submit;

$m->content_like(qr/Ticket \d+ created in queue/, 'created ticket');
like( $m->uri, qr{^\Q$baseurl\E/(?:index\.html)?\?results=}, 'still in homepage' );
unlike( $m->uri, qr{Ticket/Display.html}, 'not on ticket display page' );

$m->get_ok($baseurl . '/Prefs/Other.html');
$m->submit_form(
    form_name => 'ModifyPreferences',
    fields    => { 'DisplayTicketAfterQuickCreate' => 1, },
    button => 'Update',
);

$m->content_contains( 'Preferences saved',
    'enabled DisplayTicketAfterQuickCreate' );
$m->get($baseurl);

$m->form_with_fields('Subject', 'Content');
$m->field(Subject => 'from quick create');
$m->submit;

$m->content_like(qr/Ticket \d+ created in queue/, 'created ticket');
like( $m->uri, qr!/Ticket/Display.html!, 'still in homepage' );

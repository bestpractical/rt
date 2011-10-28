use strict;
use warnings;

use RT::Test tests => 15;

my $ticket = RT::Test->create_ticket(
    Subject => 'test bulk update',
    Queue   => 1,
);

my ( $url, $m ) = RT::Test->started_ok;
ok( $m->login, 'logged in' );

$m->get_ok( $url . "/Ticket/ModifyAll.html?id=" . $ticket->id );

$m->submit_form(
    form_number => 3,
    fields      => { 'UpdateContent' => 'this is update content' },
    button      => 'SubmitTicket',
);

$m->content_contains("Message recorded", 'updated ticket');
$m->content_lacks("this is update content", 'textarea is clear');

$m->get_ok($url . '/Ticket/Display.html?id=' . $ticket->id );
$m->content_contains("this is update content", 'updated content in display page');

# NOTE http://issues.bestpractical.com/Ticket/Display.html?id=18284
RT::Test->stop_server;
RT->Config->Set(AutocompleteOwners => 1);
($url, $m) = RT::Test->started_ok;
$m->login;

$m->get_ok($url . '/Ticket/ModifyAll.html?id=' . $ticket->id);

$m->form_name('TicketModifyAll');
$m->field(Owner => 'root');
$m->click('SubmitTicket');

$m->form_name('TicketModifyAll');
is($m->value('Owner'), 'root', 'owner was successfully changed to root');

# XXX TODO test other parts, i.e. basic, dates, people and links


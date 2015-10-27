use strict;
use warnings;

use RT::Test tests => undef;

my $ticket = RT::Test->create_ticket(
    Subject => 'test bulk update',
    Queue   => 1,
);

RT->Config->Set(AutocompleteOwners => 1);

my ( $url, $m ) = RT::Test->started_ok;
ok( $m->login, 'logged in' );

$m->get_ok( $url . "/Ticket/ModifyAll.html?id=" . $ticket->id );

$m->submit_form(
    form_number => 3,
    fields      => { 'UpdateContent' => 'this is update content' },
    button      => 'SubmitTicket',
);

$m->content_contains("Comments added", 'updated ticket');
$m->content_lacks("this is update content", 'textarea is clear');

$m->get_ok($url . '/Ticket/Display.html?id=' . $ticket->id );
$m->content_contains("this is update content", 'updated content in display page');

$m->get_ok($url . '/Ticket/ModifyAll.html?id=' . $ticket->id);

$m->form_name('TicketModifyAll');
$m->field(Owner => 'root');
$m->click('SubmitTicket');

$m->form_name('TicketModifyAll');
is($m->value('Owner'), 'root', 'owner was successfully changed to root');

$m->get_ok($url . "/Ticket/ModifyAll.html?id=" . $ticket->id);

$m->form_name('TicketModifyAll');
$m->field('Starts_Date' => "2013-01-01 00:00:00");
$m->click('SubmitTicket');
$m->text_contains("Starts: (Tue Jan 01 00:00:00 2013)", 'start date successfully updated');

$m->form_name('TicketModifyAll');
$m->field('Started_Date' => "2014-01-01 00:00:00");
$m->click('SubmitTicket');
$m->text_contains("Started: (Wed Jan 01 00:00:00 2014)", 'started date successfully updated');

$m->form_name('TicketModifyAll');
$m->field('Told_Date' => "2015-01-01 00:00:00");
$m->click('SubmitTicket');
$m->text_contains("Last Contact:  (Thu Jan 01 00:00:00 2015)", 'told date successfully updated');

for my $unset ("0", "-", " ") {
    $m->form_name('TicketModifyAll');
    $m->field('Due_Date' => "2016-01-01 00:00:00");
    $m->click('SubmitTicket');
    $m->text_contains("Due: (Fri Jan 01 00:00:00 2016)", 'due date successfully updated');

    $m->form_name('TicketModifyAll');
    $m->field('Due_Date' => $unset);
    $m->click('SubmitTicket');
    $m->text_contains("Due: (Not set)", "due date successfully cleared with '$unset'");

    if ( $unset eq '-' ) {
        my @warnings = $m->get_warnings;
        chomp @warnings;
        is_deeply(
            [ @warnings ],
            [
                (
                    q{Couldn't parse date '-' by Time::ParseDate},
                    q{Couldn't parse date '-' by DateTime::Format::Natural}
                )
            ]
        );
    }
}

$m->get( $url . '/Ticket/ModifyAll.html?id=' . $ticket->id );
$m->form_name('TicketModifyAll');
$m->field(WatcherTypeEmail => 'Requestor');
$m->field(WatcherAddressEmail => 'root@localhost');
$m->click('SubmitTicket');
$m->text_contains(
    "Added root as Requestor for this ticket",
    'watcher is added',
);
$m->form_name('TicketModifyAll');
$m->field(WatcherTypeEmail => 'Requestor');
$m->field(WatcherAddressEmail => 'root@localhost');
$m->click('SubmitTicket');
$m->text_contains(
    "root is already Requestor",
    'no duplicate watchers',
);

undef $m;
done_testing;

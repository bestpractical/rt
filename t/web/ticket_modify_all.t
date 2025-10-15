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
$m->field(TimeWorked => 120);
$m->click('SubmitTicket');

$m->text_contains('Owner changed from Nobody to root');
$m->text_contains('Worked 2 hours (120 minutes)');

$m->form_name('TicketModifyAll');
is($m->value('Owner'), 'root', 'owner was successfully changed to root');
is($m->value('TimeWorked'), 120, 'logged 2 hours');

$m->get_ok($url . "/Ticket/ModifyAll.html?id=" . $ticket->id);

$m->form_name('TicketModifyAll');
$m->field('Starts_Date' => "2013-01-01 00:00:00");
$m->click('SubmitTicket');
$m->content_contains(qq{name="Starts_Date" value="2013-01-01 00:00:00"}, 'start date successfully updated');

$m->form_name('TicketModifyAll');
$m->field('Started_Date' => "2014-01-01 00:00:00");
$m->click('SubmitTicket');
$m->content_contains(qq{name="Started_Date" value="2014-01-01 00:00:00"}, 'started date successfully updated');

$m->form_name('TicketModifyAll');
$m->field('Told_Date' => "2015-01-01 00:00:00");
$m->click('SubmitTicket');
$m->content_contains(qq{name="Told_Date" value="2015-01-01 00:00:00"}, 'told date successfully updated');

for my $unset ("0", "-", " ") {
    $m->form_name('TicketModifyAll');
    $m->field('Due_Date' => "2016-01-01 00:00:00");
    $m->click('SubmitTicket');
    $m->content_contains(qq{name="Due_Date" value="2016-01-01 00:00:00"}, 'due date successfully updated');

    $m->form_name('TicketModifyAll');
    $m->field('Due_Date' => $unset);
    $m->click('SubmitTicket');
    $m->content_contains(qq{name="Due_Date" value=""}, "due date successfully cleared with '$unset'");

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

$m->get( $url . '/Ticket/ModifyAll.html?id=' . $ticket->id );
$m->form_name('TicketModifyAll');
$m->click('SubmitTicket');
$m->content_lacks("That is already the current value", 'no spurious messages');

$m->form_name('TicketModifyAll');
$m->field(TimeWorked => 0);
$m->click('SubmitTicket');
$m->text_contains('Adjusted time worked by -120 minutes');
$m->form_name('TicketModifyAll');
is($m->value('TimeWorked'), "", 'no time worked');

diag "Test history and history filter";
{
    my @short_list = RT::Transaction->GetTransactionTypes(TicketList => 1);
    my %short_list_hash = map { $_ => 1 } @short_list;
    ok(!$short_list_hash{'Told'}, "Type 'Told' is not in the short list");

    # Test: When all short list types are checked, should show ALL transactions (no filter)
    # Use loadAll=1 to bypass pagination and load all transactions
    $m->get_ok($url . "/Helpers/TicketHistoryPage?id=" . $ticket->id . "&loadAll=1&" . join('&', map { "FilterTxnTypes=$_" } @short_list));

    # Extract transaction IDs from the response
    my %displayed = map { $_ => 1 } $m->content =~ /data-transaction-id="(\d+)"/g;

    my $txns = $ticket->Transactions;

    while (my $txn = $txns->Next) {
        my $id = $txn->id;
        my $type = $txn->Type;
        my $field = $txn->Field || '';

        if ($txn->Type eq 'SetWatcher' && $txn->Field && $txn->Field eq 'Owner') {
            # ShowHistoryPage skips SetWatcher transactions for Owner field on tickets
            ok(!$displayed{$txn->Id}, 'Correctly skipped SetWatcher for Owner');
            next;
        }

        ok($displayed{$txn->Id}, 'Found transaction of type ' . $txn->Type);
    }
}

diag "Test history filter with Set excluded";
{
    # Filter with all short list types EXCEPT Set
    my @short_list = RT::Transaction->GetTransactionTypes(TicketList => 1);
    my @filter_list = grep { $_ ne 'Set' } @short_list;

    $m->get_ok($url . "/Helpers/TicketHistoryPage?id=" . $ticket->id . "&loadAll=1&" . join('&', map { "FilterTxnTypes=$_" } @filter_list));

    # Extract transaction IDs from the response
    my %displayed = map { $_ => 1 } $m->content =~ /data-transaction-id="(\d+)"/g;

    my $txns = $ticket->Transactions;

    while (my $txn = $txns->Next) {
        if ($txn->Type eq 'SetWatcher' && $txn->Field && $txn->Field eq 'Owner') {
            # ShowHistoryPage skips SetWatcher transactions for Owner field on tickets
            ok(!$displayed{$txn->Id}, 'Correctly skipped SetWatcher for Owner');
            next;
        }

        if ($txn->Type eq 'Told') {
            # ShowHistoryPage skips SetWatcher transactions for Owner field on tickets
            ok(!$displayed{$txn->Id}, 'Correctly skipped Told when a filter rule is provided');
            next;
        }

        if ($txn->Type eq 'Set') {
            # Set transactions should be filtered out
            ok(!$displayed{$txn->Id}, 'Correctly filtered out Set transaction');
        }
        else {
            # Other transactions should be displayed
            ok($displayed{$txn->Id}, 'Found transaction of type ' . $txn->Type);
        }
    }
}

done_testing;

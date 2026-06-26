use strict;
use warnings;

use RT::Test tests => undef;

my $queue = RT::Test->load_or_create_queue( Name => 'General' );

my $ticket = RT::Test->create_ticket( Queue => $queue->Id, );

diag "Default PriorityAsString";

for my $field (qw/Priority InitialPriority FinalPriority/) {
    is( $ticket->$field, 0, "$field is 0" );
    my $string_method = $field . 'AsString';
    is( $ticket->$string_method, 'Low', "$string_method is Low" );
}

diag "Disable PriorityAsString";

RT->Config->Set( 'EnablePriorityAsString', 0 );
for my $field (qw/Priority InitialPriority FinalPriority/) {
    my $string_method = $field . 'AsString';
    is( $ticket->$string_method, undef, "$string_method is undef" );
}

diag "Disable PriorityAsString at queue level";

RT->Config->Set( 'EnablePriorityAsString', 1 );
RT->Config->Set( 'PriorityAsString', General => 0 );
for my $field (qw/Priority InitialPriority FinalPriority/) {
    my $string_method = $field . 'AsString';
    is( $ticket->$string_method, undef, "$string_method is undef" );
}

diag "Specific PriorityAsString config at queue level";

RT->Config->Set(
    'PriorityAsString',
    Default => { Low     => 0, Medium => 50, High   => 100 },
    General => { VeryLow => 0, Low    => 20, Medium => 50, High => 100, VeryHigh => 200 },
);
for my $field (qw/Priority InitialPriority FinalPriority/) {
    my $string_method = $field . 'AsString';
    is( $ticket->$string_method, 'VeryLow', "$string_method is updated" );
}

diag "Update Priorities";

my ( $ret, $msg ) = $ticket->SetPriority(50);
ok( $ret, "Priority is updated" );
is( $msg, "Priority changed from 'VeryLow' to 'Medium'", 'Priority updated message' );

( $ret, $msg ) = $ticket->SetPriority('Low');
ok( $ret, "Priority is updated" );
is( $msg, "Priority changed from 'Medium' to 'Low'", 'Priority updated message' );
is( $ticket->Priority, 20, 'Priority is 20');

( $ret, $msg ) = $ticket->SetPriority('Medium');
ok( $ret, "Priority is updated" );
is( $msg, "Priority changed from 'Low' to 'Medium'", 'Priority updated message' );
is( $ticket->Priority, 50, 'Priority is 50');

( $ret, $msg ) = $ticket->SetFinalPriority(100);
ok( $ret, "FinalPriority is updated" );
is( $msg, "FinalPriority changed from 'VeryLow' to 'High'", 'FinalPriority updated message' );

diag "Queue default priorities";

( $ret, $msg ) = $queue->SetDefaultValue( Name => 'InitialPriority', Value => 20 );
ok( $ret, "InitialPriority defaulted to Low" );
is( $msg, 'Default value of InitialPriority changed from (no value) to Low', "InitialPriority updated message" );

( $ret, $msg ) = $queue->SetDefaultValue( Name => 'FinalPriority', Value => 100 );
ok( $ret, "FinalPriority defaulted to High" );
is( $msg, 'Default value of FinalPriority changed from (no value) to High', "FinalPriority updated message" );

$ticket = RT::Test->create_ticket( Queue => $queue->Id, );
is( $ticket->PriorityAsString,        'Low',  'PriorityAsString is correct' );
is( $ticket->InitialPriorityAsString, 'Low',  'InitialPriorityAsString is correct' );
is( $ticket->FinalPriorityAsString,   'High', 'FinalPriorityAsString is correct' );

diag "Explicitly set priorities on create";

$ticket = RT::Test->create_ticket( Queue => $queue->Id, InitialPriority => '50', FinalPriority => 200 );
is( $ticket->PriorityAsString,        'Medium',   'PriorityAsString is correct' );
is( $ticket->InitialPriorityAsString, 'Medium',   'InitialPriorityAsString is correct' );
is( $ticket->FinalPriorityAsString,   'VeryHigh', 'FinalPriorityAsString is correct' );

diag "Ticket/Transaction search";

for my $field (qw/Priority InitialPriority FinalPriority/) {
    my $tickets = RT::Tickets->new( RT->SystemUser );
    $tickets->FromSQL("Queue = 'General' AND $field = 'Low'");
    like( $tickets->BuildSelectQuery(PreferBind => 0), qr/$field = '20'/, "$field is translated properly" );

    my $txns = RT::Transactions->new( RT->SystemUser );
    $txns->FromSQL("TicketQueue = 'General' AND Ticket$field = 'Low'");
    like( $txns->BuildSelectQuery(PreferBind => 0), qr/$field = '20'/, "Ticket$field is translated properly" );
}

my $tickets = RT::Tickets->new( RT->SystemUser );
$tickets->FromSQL("Queue = 'General' AND Priority = 'Medium'");
is( $tickets->Count, 2, 'Found 2 tickets' );
while ( my $ticket = $tickets->Next ) {
    is( $ticket->PriorityAsString, 'Medium', 'Priority is correct' );
}

my $txns = RT::Transactions->new( RT->SystemUser );
$txns->FromSQL("TicketQueue = 'General' AND TicketPriority = 'Medium' AND Field = 'Priority'");
is( $txns->Count, 3, 'Found 3 txn' );
my $txn = $txns->First;
is( $txn->OldValue, 0,  'OldValue is correct' );
is( $txn->NewValue, 50, 'NewValue is correct' );

diag "Priority validation in number mode";

RT->Config->Set( 'EnablePriorityAsString', 1 );
RT->Config->Set( 'PriorityAsString', Default => 0 );

my $num_queue = RT::Test->load_or_create_queue( Name => 'NumberMode' );

for my $field (qw/Priority InitialPriority FinalPriority/) {
    # Keep the other two fields valid so only $field is bad.
    my %priorities = ( Priority => 50, InitialPriority => 50, FinalPriority => 50 );
    $priorities{$field} = 'Emergency';

    my $bad = RT::Ticket->new( RT->SystemUser );
    my ( $id, undef, $msg ) = $bad->Create(
        Queue   => $num_queue->Id,
        Subject => "Non-numeric $field",
        %priorities,
    );
    ok( !$id, "Ticket not created with a non-numeric $field" );
    is( $msg, 'Priority must be a whole number between 0 and 100', "Number-mode message for $field" );
}

diag "Priority out of range is rejected; boundaries are accepted";

{
    my $bad = RT::Ticket->new( RT->SystemUser );
    my ( $id, undef, $msg ) = $bad->Create(
        Queue => $num_queue->Id, Subject => 'Out of range', Priority => 500,
    );
    ok( !$id, 'Ticket not created with an out-of-range priority' );
    is( $msg, 'Priority must be a whole number between 0 and 100', 'Out-of-range message' );
}

for my $boundary ( 0, 100 ) {
    my $ok_ticket = RT::Ticket->new( RT->SystemUser );
    my ($id) = $ok_ticket->Create(
        Queue    => $num_queue->Id,
        Subject  => "Boundary $boundary",
        Priority => $boundary,
        FinalPriority => $boundary,
    );
    ok( $id, "Ticket created with boundary priority $boundary" );
    is( $ok_ticket->Priority, $boundary, "Priority is $boundary" );
}

diag "String mode rejects a crafted non-numeric value";

# In string mode the UI submits a configured number, but a crafted non-numeric
# value must still be rejected rather than passed to the integer column.
RT->Config->Set( 'PriorityAsString', Default => { Low => 0, Medium => 50, High => 100 } );
{
    my $bad = RT::Ticket->new( RT->SystemUser );
    my ( $id, undef, $msg ) = $bad->Create(
        Queue => $num_queue->Id, Subject => 'Crafted string-mode value', Priority => 'Bogus',
    );
    ok( !$id, 'Ticket not created with a non-numeric value in string mode' );
    is( $msg, 'Priority must be a whole number.', 'String-mode non-numeric is rejected' );
}

done_testing;

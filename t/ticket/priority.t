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
    like( $tickets->BuildSelectQuery, qr/$field = '20'/, "$field is translated properly" );

    my $txns = RT::Transactions->new( RT->SystemUser );
    $txns->FromSQL("TicketQueue = 'General' AND Ticket$field = 'Low'");
    like( $txns->BuildSelectQuery, qr/$field = '20'/, "Ticket$field is translated properly" );
}

my $tickets = RT::Tickets->new( RT->SystemUser );
$tickets->FromSQL("Queue = 'General' AND Priority = 'Medium'");
is( $tickets->Count, 2, 'Found 2 tickets' );
while ( my $ticket = $tickets->Next ) {
    is( $ticket->PriorityAsString, 'Medium', 'Priority is correct' );
}

my $txns = RT::Transactions->new( RT->SystemUser );
$txns->FromSQL("TicketQueue = 'General' AND TicketPriority = 'Medium' AND Field = 'Priority'");
is( $txns->Count, 1, 'Found 1 txn' );
my $txn = $txns->First;
is( $txn->OldValue, 0,  'OldValue is correct' );
is( $txn->NewValue, 50, 'NewValue is correct' );

done_testing;

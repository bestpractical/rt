use strict;
use warnings;

use RT::Test tests => 27;

my $queue = RT::Test->load_or_create_queue( Name => 'General' );
ok $queue && $queue->id, "loaded or created a queue";

note 'set on Create';
{
    my $ticket = RT::Test->create_ticket(
        Queue => $queue->id, TimeWorked => 10,
    );
    is $ticket->TimeWorked, 10, 'correct value';

    my $txn = RT::Transaction->new( RT->SystemUser );
    $txn->LoadByCols(
        ObjectType => 'RT::Ticket', ObjectId => $ticket->id,
        Type => 'Create',
    );
    ok $txn->id, 'found transaction';
    is $txn->TimeTaken, 10, 'correct value';
}

note 'set on Comment';
{
    my $ticket = RT::Test->create_ticket( Queue => $queue->id );
    ok !$ticket->TimeWorked, 'correct value';
    $ticket->Comment( Content => 'test', TimeTaken => 10 );
    is $ticket->TimeWorked, 10, 'correct value';

    my $txn = RT::Transaction->new( RT->SystemUser );
    $txn->LoadByCols(
        ObjectType => 'RT::Ticket', ObjectId => $ticket->id,
        Type => 'Comment',
    );
    ok $txn->id, 'found transaction';
    is $txn->TimeTaken, 10, 'correct value';
}

note 'update';
{
    my $ticket = RT::Test->create_ticket( Queue => $queue->id );
    ok !$ticket->TimeWorked, 'correct value';
    $ticket->SetTimeWorked( 10 );
    is $ticket->TimeWorked, 10, 'correct value';

    my $txn = RT::Transaction->new( RT->SystemUser );
    $txn->LoadByCols(
        ObjectType => 'RT::Ticket', ObjectId => $ticket->id,
        Type => 'Set', Field => 'TimeWorked',
    );
    ok $txn->id, 'found transaction';
    is $txn->TimeTaken, 10, 'correct value';
}

note 'on Merge';
{
    my $ticket = RT::Test->create_ticket(
        Queue => $queue->id, TimeWorked => 7,
    );
    {
        my $tmp = RT::Test->create_ticket(
            Queue => $queue->id, TimeWorked => 13,
        );
        my ($status, $msg) = $tmp->MergeInto( $ticket->id );
        ok $status, "merged tickets";
    }
    $ticket->Load( $ticket->id );
    is $ticket->TimeWorked, 20, 'correct value';
}

sub dump_txns {
    my $ticket = shift;
    my $txns = $ticket->Transactions;
    while ( my $txn = $txns->Next ) {
        diag sprintf "#%d\t%s\t%s\t%d", map $txn->$_() // '', qw(id Type Field TimeTaken);
    }
}


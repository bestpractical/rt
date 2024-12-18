use strict;
use warnings;

use RT::Test tests => undef;

my $queue = RT::Test->load_or_create_queue( Name => 'General' );
ok $queue && $queue->id, "loaded or created a queue";
my $root = RT::User->new(RT->SystemUser);
$root->Load('root');
ok($root->Id, "Loaded " . $root->Name . " user");

my $test_user = RT::Test->load_or_create_user( Name => 'worker', EmailAddress => 'worker@example.com', Password => 'password' );

my $date = RT::Date->new(RT->SystemUser);
$date->Set(Format => 'ISO', Value => '2024-08-01 15:10:00');
is($date->ISO, '2024-08-01 15:10:00', "Test date set");
my $test_date = $date->Date( Timezone => 'user' );
ok( $test_date, "Test day is $test_date" );

my $now = RT::Date->new(RT->SystemUser);
$date->SetToNow;
my $current_date = $date->Date( Timezone => 'user' );
ok( $current_date, "Current day is $current_date" );

diag 'set on Create';
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
    is( $txn->Creator, 1, 'Created by RT_System' );
    is( $txn->TimeWorker, RT->SystemUser->Id, 'Correct worker');
    is( $txn->TimeWorkedDate, $current_date, 'Worked date set');
}

diag 'Set on Create with worker and worked date';
{
    my $ticket = RT::Test->create_ticket(
        Queue => $queue->id, TimeWorked => 10, TimeWorker => $test_user->Id, TimeWorkedDate => $test_date
    );
    is $ticket->TimeWorked, 10, 'correct value';

    my $txn = RT::Transaction->new( RT->SystemUser );
    $txn->LoadByCols(
        ObjectType => 'RT::Ticket', ObjectId => $ticket->id,
        Type => 'Create',
    );
    ok $txn->id, 'found transaction';
    is $txn->TimeTaken, 10, 'correct value';
    is( $txn->Creator, 1, 'Created by RT_System' );
    is( $txn->TimeWorker, $test_user->Id, 'Correct worker set ' . $test_user->Id );
    is( $txn->TimeWorkedDate, $test_date, "Correct worked date set $test_date" );
}

diag 'set on Comment';
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
    is( $txn->Creator, 1, 'Created by RT_System' );
    is( $txn->TimeWorker, RT->SystemUser->Id, 'Correct worker');
    is( $txn->TimeWorkedDate, $current_date, 'Worked date set');
}

diag 'Set on Comment with worker and worked date';
{
    my $ticket = RT::Test->create_ticket( Queue => $queue->id );
    ok !$ticket->TimeWorked, 'correct value';
    $ticket->Comment( Content => 'test', TimeTaken => 10, TimeWorker => $test_user->Id, TimeWorkedDate => $test_date );
    is $ticket->TimeWorked, 10, 'correct value';

    my $txn = RT::Transaction->new( RT->SystemUser );
    $txn->LoadByCols(
        ObjectType => 'RT::Ticket', ObjectId => $ticket->id,
        Type => 'Comment',
    );
    ok $txn->id, 'found transaction';
    is $txn->TimeTaken, 10, 'correct value';
    is( $txn->Creator, 1, 'Created by RT_System' );
    is( $txn->TimeWorker, $test_user->Id, 'Correct worker set ' . $test_user->Id );
    is( $txn->TimeWorkedDate, $test_date, "Correct worked date set $test_date" );
}

diag 'update';
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
    is( $txn->Creator, 1, 'Created by RT_System' );
    is( $txn->TimeWorker, RT->SystemUser->Id, 'Correct worker');
    is( $txn->TimeWorkedDate, $current_date, 'Worked date set');
}

diag 'Update with worker and worked date';
{
    my $ticket = RT::Test->create_ticket( Queue => $queue->id );
    ok !$ticket->TimeWorked, 'correct value';
    $ticket->SetTimeWorked( 10, $test_user->Id, $test_date );
    is $ticket->TimeWorked, 10, 'correct value';

    my $txn = RT::Transaction->new( RT->SystemUser );
    $txn->LoadByCols(
        ObjectType => 'RT::Ticket', ObjectId => $ticket->id,
        Type => 'Set', Field => 'TimeWorked',
    );
    ok $txn->id, 'found transaction';
    is $txn->TimeTaken, 10, 'correct value';
    is( $txn->Creator, 1, 'Created by RT_System' );
    is( $txn->TimeWorker, $test_user->Id, 'Correct worker set ' . $test_user->Id );
    is( $txn->TimeWorkedDate, $test_date, "Correct worked date set $test_date" );
}

diag 'on Merge';
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

done_testing();

sub dump_txns {
    my $ticket = shift;
    my $txns = $ticket->Transactions;
    while ( my $txn = $txns->Next ) {
        diag sprintf "#%d\t%s\t%s\t%d", map $txn->$_() // '', qw(id Type Field TimeTaken);
    }
}


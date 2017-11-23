use strict;
use warnings;

use RT::Test tests => undef;
use Test::MockTime qw/set_fixed_time/;

use constant KIDS => 50;

my $id;

{
    my $t = RT::Ticket->new( RT->SystemUser );
    ($id) = $t->Create(
        Queue => "General",
        Subject => "Race $$",
    );
}

diag "Created ticket $id";
RT->DatabaseHandle->Disconnect;

my @kids;
for (1..KIDS) {
    if (my $pid = fork()) {
        push @kids, $pid;
        next;
    }

    # In the kid, load up the ticket and correspond
    RT->ConnectToDatabase;
    my $t = RT::Ticket->new( RT->SystemUser );
    $t->Load( $id );
    $t->Correspond( Content => "Correspondence from PID $$" );
    undef $t;
    exit 0;
}


diag "Forked @kids";
waitpid $_, 0 for @kids;
diag "All kids finished corresponding";

RT->ConnectToDatabase;
my $t = RT::Ticket->new( RT->SystemUser );
$t->Load($id);
my $txns = $t->Transactions;
$txns->Limit( FIELD => 'Type', VALUE => 'Status' );
is($txns->Count, 1, "Only one transaction change recorded" );

$txns = $t->Transactions;
$txns->Limit( FIELD => 'Type', VALUE => 'Correspond' );
is($txns->Count, KIDS, "But all correspondences were recorded" );


my @users;
for my $n (0..2) {
    push @users, RT::Test->load_or_create_user(
        Name => "user_$n", Password => 'password',
    )->id;
}

ok(RT::Test->add_rights({
    Principal   => 'Privileged',
    Right       => 'OwnTicket',
}), "Granted OwnTicket");

for my $round (1..10) {
    my ($ok, $msg) = $t->SetOwner($users[0]);
    ok $ok, "Set owner back to base";
    my $last_txn = $t->Transactions->Last->id;
    RT->DatabaseHandle->Disconnect;

    diag "Round $round..\n";
    @kids = ();
    for my $n (1..2) {
        if (my $pid = fork()) {
            push @kids, $pid;
            next;
        }

        set_fixed_time("2017-01-03T17:17:17Z");

        # In the kid, load up the ticket and claim the owner
        RT->ConnectToDatabase;
        my $t = RT::Ticket->new( RT->SystemUser );
        $t->Load( $id );

        my ($ok, $msg);
        if ($n == 1) {
            $RT::Handle->BeginTransaction;
            $t->LockForUpdate;
            ($ok, $msg) = $t->SetOwner( $users[$n] );
            undef $t;
            $RT::Handle->Commit;
        } else {
            ($ok, $msg) = $t->SetOwner( $users[$n] );
            undef $t;
        }
        exit(1 - $ok);
    }

    diag "Forked @kids";
    for my $pid (@kids) {
        waitpid $pid, 0;
        my $ret = $? >> 8;
        is $ret, 0, "$pid returned $ret";
    }

    RT->ConnectToDatabase;
    # Flush the process-local cache and reload, since the changes
    # happened in other processes
    DBIx::SearchBuilder::Record::Cachable->FlushCache;
    $t->Load( $id );
    $txns = $t->Transactions;
    $txns->Limit( FIELD => 'id', OPERATOR => '>', VALUE => $last_txn );
    $txns->Limit( FIELD => 'Type', VALUE => 'SetWatcher' );
    is $txns->Count, 2, "Found two new SetWatcher transactions";

    my $winner = $t->Owner;
    isnt $winner, $users[0], "Not the base owner";
    ok $t->OwnerGroup->HasMember( $winner ), "GroupMembers agrees";
    ok $t->OwnerGroup->HasMemberRecursively( $winner ), "CachedGroupMembers agrees";
}

done_testing;

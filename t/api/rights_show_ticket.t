
use RT::Test nodata => 1, tests => 264;

use strict;
use warnings;


my $queue_a = RT::Test->load_or_create_queue( Name => 'A' );
ok $queue_a && $queue_a->id, 'loaded or created queue_a';
my $qa_id = $queue_a->id;

my $queue_b = RT::Test->load_or_create_queue( Name => 'B' );
ok $queue_b && $queue_b->id, 'loaded or created queue_b';
my $qb_id = $queue_b->id;

my $user_a = RT::Test->load_or_create_user(
    Name => 'user_a', Password => 'password',
);
ok $user_a && $user_a->id, 'loaded or created user';

my $user_b = RT::Test->load_or_create_user(
    Name => 'user_b', Password => 'password',
);
ok $user_b && $user_b->id, 'loaded or created user';

foreach my $option (0 .. 1 ) { RT->Config->Set( 'UseSQLForACLChecks' => $option );

diag "Testing with UseSQLForACLChecks => $option";

# Global Cc has right, a User is nobody
{
    cleanup();
    RT::Test->set_rights(
        { Principal => 'Everyone', Right => [qw(SeeQueue)] },
        { Principal => 'Cc',       Right => [qw(ShowTicket)] },
    );
    create_tickets_set();
    have_no_rights($user_a, $user_b);
}

# Global Cc has right, a User is Queue Cc
{
    cleanup();
    RT::Test->set_rights(
        { Principal => 'Everyone', Right => [qw(SeeQueue)] },
        { Principal => 'Cc',       Right => [qw(ShowTicket)] },
    );
    create_tickets_set();
    have_no_rights($user_a, $user_b);

    my ($status, $msg) = $queue_a->AddWatcher( Type => 'Cc', PrincipalId => $user_a->id );
    ok($status, "user A is now queue A watcher");

    foreach my $q (
        '',
        "Queue = $qa_id OR Queue = $qb_id",
        "Queue = $qb_id OR Queue = $qa_id",
    ) {
        my $tickets = RT::Tickets->new( RT::CurrentUser->new( $user_a ) );
        $q? $tickets->FromSQL($q) : $tickets->UnLimit;
        my $found = 0;
        while ( my $t = $tickets->Next ) {
            $found++;
            is( $t->Queue, $queue_a->id, "user sees tickets only in queue A" );
        }
        is($found, 2, "user sees tickets");
    }
    have_no_rights( $user_b );
}

# global Cc has right, a User is ticket Cc
{
    cleanup();
    RT::Test->set_rights(
        { Principal => 'Everyone', Right => [qw(SeeQueue)] },
        { Principal => 'Cc',       Right => [qw(ShowTicket)] },
    );
    my @tickets = create_tickets_set();
    have_no_rights($user_a, $user_b);

    my ($status, $msg) = $tickets[1]->AddWatcher( Type => 'Cc', PrincipalId => $user_a->id );
    ok($status, "user A is now queue A watcher");

    foreach my $q (
        '',
        "Queue = $qa_id OR Queue = $qb_id",
        "Queue = $qb_id OR Queue = $qa_id",
    ) {
        my $tickets = RT::Tickets->new( RT::CurrentUser->new( $user_a ) );
        $q? $tickets->FromSQL($q) : $tickets->UnLimit;
        my $found = 0;
        while ( my $t = $tickets->Next ) {
            $found++;
            is( $t->Queue, $queue_a->id, "user sees tickets only in queue A" );
            is( $t->id, $tickets[1]->id, "correct ticket");
        }
        is($found, 1, "user sees tickets");
    }
    have_no_rights($user_b);
}

# Queue Cc has right, a User is nobody
{
    cleanup();
    RT::Test->set_rights(
        { Principal => 'Everyone', Right => [qw(SeeQueue)] },
        { Principal => 'Cc', Object => $queue_a, Right => [qw(ShowTicket)] },
    );
    create_tickets_set();
    have_no_rights($user_a, $user_b);
}

# Queue Cc has right, Users are Queue Ccs
{
    cleanup();
    RT::Test->set_rights(
        { Principal => 'Everyone', Right => [qw(SeeQueue)] },
        { Principal => 'Cc', Object => $queue_a, Right => [qw(ShowTicket)] },
    );
    create_tickets_set();
    have_no_rights($user_a, $user_b);

    my ($status, $msg) = $queue_a->AddWatcher( Type => 'Cc', PrincipalId => $user_a->id );
    ok($status, "user A is now queue A watcher");

    ($status, $msg) = $queue_b->AddWatcher( Type => 'Cc', PrincipalId => $user_b->id );
    ok($status, "user B is now queue B watcher");

    foreach my $q (
        '',
        "Queue = $qa_id OR Queue = $qb_id",
        "Queue = $qb_id OR Queue = $qa_id",
    ) {
        my $tickets = RT::Tickets->new( RT::CurrentUser->new( $user_a ) );
        $q? $tickets->FromSQL($q) : $tickets->UnLimit;
        my $found = 0;
        while ( my $t = $tickets->Next ) {
            $found++;
            is( $t->Queue, $queue_a->id, "user sees tickets only in queue A" );
        }
        is($found, 2, "user sees tickets");
    }
    have_no_rights( $user_b );
}

# Queue Cc has right, Users are ticket Ccs
{
    cleanup();
    RT::Test->set_rights(
        { Principal => 'Everyone', Right => [qw(SeeQueue)] },
        { Principal => 'Cc', Object => $queue_a, Right => [qw(ShowTicket)] },
    );
    my @tickets = create_tickets_set();
    have_no_rights($user_a, $user_b);

    my ($status, $msg) = $tickets[1]->AddWatcher( Type => 'Cc', PrincipalId => $user_a->id );
    ok($status, "user A is now Cc on a ticket in queue A");

    ($status, $msg) = $tickets[2]->AddWatcher( Type => 'Cc', PrincipalId => $user_b->id );
    ok($status, "user B is now Cc on a ticket in queue B");

    foreach my $q (
        '',
        "Queue = $qa_id OR Queue = $qb_id",
        "Queue = $qb_id OR Queue = $qa_id",
    ) {
        my $tickets = RT::Tickets->new( RT::CurrentUser->new( $user_a ) );
        $q? $tickets->FromSQL($q) : $tickets->UnLimit;
        my $found = 0;
        while ( my $t = $tickets->Next ) {
            $found++;
            is( $t->Queue, $queue_a->id, "user sees tickets only in queue A" );
            is( $t->id, $tickets[1]->id, )
        }
        is($found, 1, "user sees tickets");
    }
    have_no_rights( $user_b );
}

# Users has direct right on queue
{
    cleanup();
    RT::Test->set_rights(
        { Principal => 'Everyone', Right => [qw(SeeQueue)] },
        { Principal => $user_a, Object => $queue_a, Right => [qw(ShowTicket)] },
    );
    my @tickets = create_tickets_set();

    foreach my $q (
        '',
        "Queue = $qa_id OR Queue = $qb_id",
        "Queue = $qb_id OR Queue = $qa_id",
    ) {
        my $tickets = RT::Tickets->new( RT::CurrentUser->new( $user_a ) );
        $q? $tickets->FromSQL($q) : $tickets->UnLimit;
        my $found = 0;
        while ( my $t = $tickets->Next ) {
            $found++;
            is( $t->Queue, $queue_a->id, "user sees tickets only in queue A" );
        }
        is($found, 2, "user sees tickets");
    }
    have_no_rights( $user_b );
}


}

sub have_no_rights {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    foreach my $u ( @_ ) {
        foreach my $q (
            '',
            "Queue = $qa_id OR Queue = $qb_id",
            "Queue = $qb_id OR Queue = $qa_id",
        ) {
            my $tickets = RT::Tickets->new( RT::CurrentUser->new( $u ) );
            $q? $tickets->FromSQL($q) : $tickets->UnLimit;
            ok(!$tickets->First, "no tickets");
        }
    }
}

sub create_tickets_set{
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my @res;
    foreach my $q ($queue_a, $queue_b) {
        foreach my $n (1 .. 2) {
            my $ticket = RT::Ticket->new( RT->SystemUser );
            my ($tid) = $ticket->Create(
                Queue => $q->id, Subject => $q->Name .' - '. $n
            );
            ok( $tid, "created ticket #$tid");
            push @res, $ticket;
        }
    }
    return @res;
}

sub cleanup {
    RT::Test->delete_tickets( "Queue = $qa_id OR Queue = $qb_id" );
    RT::Test->delete_queue_watchers( $queue_a, $queue_b );
}; 


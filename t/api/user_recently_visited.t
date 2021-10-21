use strict;
use warnings;

# test the RecentlyViewedTickets method

use RT::Test::Shredder tests => undef;
my $test = "RT::Test::Shredder";

{
    my $user = RT::Test->load_or_create_user( Name => 'tester' );
    ok( $user && $user->Id, 'created user' );

    # need ShowTicket to visit, ModifyTicket to merge
    ok( RT::Test->add_rights(
            {   Principal => $user,
                Right => [qw( SeeQueue CreateTicket ShowTicket ModifyTicket )]
            }
        ),
        'granting rights'
      );

    is( visited_nb( $user ), 0, 'init: empty RecentlyViewedTickets' );

    my %ticket;
    foreach my $ticket_code ( 'a' .. 't' ) {
        my $new_ticket = RT::Test->create_ticket(
            Subject => $ticket_code,
            Queue   => 'General'
        );
        my $id = $new_ticket->id;
        ok( $new_ticket, "ticket '$ticket_code' created" );
        $ticket{$ticket_code}
            = { ticket => $new_ticket, id => $id, subject => $ticket_code };
        $new_ticket->ApplyTransactionBatch
            ;    # needed for the tests with shredder to work
    }

    is( visited_nb( $user ), 0,
        'tickets created: empty RecentlyViewedTickets'
    );

    # using reverse on the list so it's easier to read later (last visited is first in RecentlyViewedTicket)
    foreach my $viewed ( reverse qw( c q p b e d c b a ) ) {
        $user->AddRecentlyViewedTicket( $ticket{$viewed}->{ticket} );
    }

    is( visited( $user ), 'c,q,p,b,e,d,a',
        'visited tickets after inital visits'
    );

    my $shredder = $test->shredder_new();

    $shredder->PutObjects( Objects => $ticket{m}->{ticket} );
    $shredder->WipeoutAll;
    is( visited( $user ), 'c,q,p,b,e,d,a',
        'visited tickets after shredding an unvisited ticket'
    );

    $shredder->PutObjects( Objects => $ticket{p}->{ticket} );
    $shredder->PutObjects( Objects => $ticket{d}->{ticket} );
    $shredder->WipeoutAll;
    is( visited( $user ), 'c,q,b,e,a',
        'visited tickets after shredding 2 visited tickets'
    );

    my ( $ok, $msg ) = $ticket{b}->{ticket}->MergeInto( $ticket{j}->{id} );
    if ( !$ok ) { die "error merging: $msg\n"; }
    is( visited( $user ), 'c,q,j,e,a',
        'visited tickets after merging into a ticket that was NOT on the list'
    );

    $ticket{c}->{ticket}->MergeInto( $ticket{a}->{id} );
    is( visited( $user ), 'a,q,j,e',
        'visited tickets after merging into a ticket that was on the list'
    );

    $ticket{e}->{ticket}->MergeInto( $ticket{j}->{id} );
    is( visited( $user ), 'a,q,j',
        'visited tickets after merging into a ticket that was on the list (merged)'
    );

    foreach my $viewed ( reverse qw( r j a h k a q a k i s t f g d ) ) {
        $user->AddRecentlyViewedTicket( $ticket{$viewed}->{ticket} );
    }

    is( visited( $user ), 'r,j,a,h,k,q,i,s,t,f',
        'visited more than 10 tickets'
    );

}

done_testing();

sub visited_nb {
    return scalar shift->RecentlyViewedTickets;
}

sub visited {
    return join ',', map { $_->{subject} } shift->RecentlyViewedTickets;
}

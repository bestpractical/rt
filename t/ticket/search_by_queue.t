use strict;
use warnings;

use RT::Test nodata => 1, tests => undef;
use RT::Ticket;

my $qa = RT::Test->load_or_create_queue( Name => 'Queue A' );
ok $qa && $qa->id, 'loaded or created queue';

my $qb = RT::Test->load_or_create_queue( Name => 'Queue B' );
ok $qb && $qb->id, 'loaded or created queue';

my @tickets = RT::Test->create_tickets(
    {},
    { Queue => $qa->id, Subject => 'a1', },
    { Queue => $qa->id, Subject => 'a2', },
    { Queue => $qb->id, Subject => 'b1', },
    { Queue => $qb->id, Subject => 'b2', },
);

run_tests( \@tickets,
    'Queue = "Queue A"' => { a1 => 1, a2 => 1, b1 => 0, b2 => 0 },
    'Queue = '. $qa->id => { a1 => 1, a2 => 1, b1 => 0, b2 => 0 },
    'Queue != "Queue A"' => { a1 => 0, a2 => 0, b1 => 1, b2 => 1 },
    'Queue != '. $qa->id => { a1 => 0, a2 => 0, b1 => 1, b2 => 1 },

    'Queue = "Queue B"' => { a1 => 0, a2 => 0, b1 => 1, b2 => 1 },
    'Queue = '. $qb->id => { a1 => 0, a2 => 0, b1 => 1, b2 => 1 },
    'Queue != "Queue B"' => { a1 => 1, a2 => 1, b1 => 0, b2 => 0 },
    'Queue != '. $qb->id => { a1 => 1, a2 => 1, b1 => 0, b2 => 0 },

    'Queue = "Bad Queue"' => { a1 => 0, a2 => 0, b1 => 0, b2 => 0 },
    'Queue != "Bad Queue"' => { a1 => 1, a2 => 1, b1 => 1, b2 => 1 },

    'Queue LIKE "Queue A"' => { a1 => 1, a2 => 1, b1 => 0, b2 => 0 },
    'Queue LIKE "Queue B"' => { a1 => 0, a2 => 0, b1 => 1, b2 => 1 },
    'Queue LIKE "Bad Queue"' => { a1 => 0, a2 => 0, b1 => 0, b2 => 0 },
    'Queue LIKE "Queue"' => { a1 => 1, a2 => 1, b1 => 1, b2 => 1 },

    'Queue NOT LIKE "Queue B"' => { a1 => 1, a2 => 1, b1 => 0, b2 => 0 },
    'Queue NOT LIKE "Queue A"' => { a1 => 0, a2 => 0, b1 => 1, b2 => 1 },
    'Queue NOT LIKE "Bad Queue"' => { a1 => 1, a2 => 1, b1 => 1, b2 => 1 },
    'Queue NOT LIKE "Queue"' => { a1 => 0, a2 => 0, b1 => 0, b2 => 0 },
);

done_testing;

sub run_tests {
    my @tickets = @{ shift() };
    my %test = @_;
    my $query_prefix = join ' OR ', map 'id = '. $_->id, @tickets;
    foreach my $key ( sort keys %test ) {
        my $tix = RT::Tickets->new(RT->SystemUser);
        $tix->FromSQL( "( $query_prefix ) AND ( $key )" );

        my $error = 0;

        my $count = 0;
        $count++ foreach grep $_, values %{ $test{$key} };
        is($tix->Count, $count, "found correct number of ticket(s) by '$key'") or $error = 1;

        my $good_tickets = 1;
        while ( my $ticket = $tix->Next ) {
            next if $test{$key}->{ $ticket->Subject };
            diag $ticket->Subject ." ticket has been found when it's not expected";
            $good_tickets = 0;
        }
        ok( $good_tickets, "all tickets are good with '$key'" ) or $error = 1;

        diag "Wrong SQL query for '$key':". $tix->BuildSelectQuery if $error;
    }
}

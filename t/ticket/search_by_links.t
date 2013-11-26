
use strict;
use warnings;

use RT::Test nodata => 1, tests => 100;
use RT::Ticket;

my $q = RT::Test->load_or_create_queue( Name => 'Regression' );
ok $q && $q->id, 'loaded or created queue';

my ($total, @tickets, %test) = (0, ());

sub run_tests {
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

# simple set with "no links", "parent and child"
@tickets = RT::Test->create_tickets(
    { Queue => $q->id },
    { Subject => '-', },
    { Subject => 'p', },
    { Subject => 'c', MemberOf => -1 },
);
$total += @tickets;
%test = (
    'Linked     IS NOT NULL'  => { '-' => 0, c => 1, p => 1 },
    'Linked     IS     NULL'  => { '-' => 1, c => 0, p => 0 },
    'LinkedTo   IS NOT NULL'  => { '-' => 0, c => 1, p => 0 },
    'LinkedTo   IS     NULL'  => { '-' => 1, c => 0, p => 1 },
    'LinkedFrom IS NOT NULL'  => { '-' => 0, c => 0, p => 1 },
    'LinkedFrom IS     NULL'  => { '-' => 1, c => 1, p => 0 },

    'HasMember  IS NOT NULL'  => { '-' => 0, c => 0, p => 1 },
    'HasMember  IS     NULL'  => { '-' => 1, c => 1, p => 0 },
    'MemberOf   IS NOT NULL'  => { '-' => 0, c => 1, p => 0 },
    'MemberOf   IS     NULL'  => { '-' => 1, c => 0, p => 1 },

    'RefersTo   IS NOT NULL'  => { '-' => 0, c => 0, p => 0 },
    'RefersTo   IS     NULL'  => { '-' => 1, c => 1, p => 1 },

    'Linked      = '. $tickets[0]->id  => { '-' => 0, c => 0, p => 0 },
    'Linked     != '. $tickets[0]->id  => { '-' => 1, c => 1, p => 1 },

    'MemberOf    = '. $tickets[1]->id  => { '-' => 0, c => 1, p => 0 },
    'MemberOf   != '. $tickets[1]->id  => { '-' => 1, c => 0, p => 1 },
);
{
    my $tix = RT::Tickets->new(RT->SystemUser);
    $tix->FromSQL("Queue = '". $q->id ."'");
    is($tix->Count, $total, "found $total tickets");
}
run_tests();

# make sure search by id is on LocalXXX columns
{
    my $tickets = RT::Tickets->new( RT->SystemUser );
    $tickets->FromSQL('MemberOf = '. $tickets[0]->id);
    like $tickets->BuildSelectQuery, qr/LocalBase/;
    like $tickets->BuildSelectQuery, qr/LocalTarget/;
}

# another set with tests of combinations searches
@tickets = RT::Test->create_tickets(
    { Queue => $q->id },
    { Subject => '-', },
    { Subject => 'p', },
    { Subject => 'rp',  RefersTo => -1 },
    { Subject => 'c',   MemberOf => -2 },
    { Subject => 'rc1', RefersTo => -1 },
    { Subject => 'rc2', RefersTo => -2 },
);
$total += @tickets;
my $pid = $tickets[1]->id;
%test = (
    'RefersTo IS NOT NULL'  => { '-' => 0, c => 0, p => 0, rp => 1, rc1 => 1, rc2 => 1 },
    'RefersTo IS     NULL'  => { '-' => 1, c => 1, p => 1, rp => 0, rc1 => 0, rc2 => 0 },

    'RefersTo IS NOT NULL AND MemberOf IS NOT NULL'  => { '-' => 0, c => 0, p => 0, rp => 0, rc1 => 0, rc2 => 0 },
    'RefersTo IS NOT NULL AND MemberOf IS     NULL'  => { '-' => 0, c => 0, p => 0, rp => 1, rc1 => 1, rc2 => 1 },
    'RefersTo IS     NULL AND MemberOf IS NOT NULL'  => { '-' => 0, c => 1, p => 0, rp => 0, rc1 => 0, rc2 => 0 },
    'RefersTo IS     NULL AND MemberOf IS     NULL'  => { '-' => 1, c => 0, p => 1, rp => 0, rc1 => 0, rc2 => 0 },

    'RefersTo IS NOT NULL OR  MemberOf IS NOT NULL'  => { '-' => 0, c => 1, p => 0, rp => 1, rc1 => 1, rc2 => 1 },
    'RefersTo IS NOT NULL OR  MemberOf IS     NULL'  => { '-' => 1, c => 0, p => 1, rp => 1, rc1 => 1, rc2 => 1 },
    'RefersTo IS     NULL OR  MemberOf IS NOT NULL'  => { '-' => 1, c => 1, p => 1, rp => 0, rc1 => 0, rc2 => 0 },
    'RefersTo IS     NULL OR  MemberOf IS     NULL'  => { '-' => 1, c => 1, p => 1, rp => 1, rc1 => 1, rc2 => 1 },

    "RefersTo  = $pid AND MemberOf  = $pid" => { '-' => 0, c => 0, p => 0, rp => 0, rc1 => 0, rc2 => 0 },
    "RefersTo  = $pid AND MemberOf != $pid" => { '-' => 0, c => 0, p => 0, rp => 1, rc1 => 0, rc2 => 0 },
    "RefersTo != $pid AND MemberOf  = $pid" => { '-' => 0, c => 1, p => 0, rp => 0, rc1 => 0, rc2 => 0 },
    "RefersTo != $pid AND MemberOf != $pid" => { '-' => 1, c => 0, p => 1, rp => 0, rc1 => 1, rc2 => 1 },

    "RefersTo  = $pid OR  MemberOf  = $pid" => { '-' => 0, c => 1, p => 0, rp => 1, rc1 => 0, rc2 => 0 },
    "RefersTo  = $pid OR  MemberOf != $pid" => { '-' => 1, c => 0, p => 1, rp => 1, rc1 => 1, rc2 => 1 },
    "RefersTo != $pid OR  MemberOf  = $pid" => { '-' => 1, c => 1, p => 1, rp => 0, rc1 => 1, rc2 => 1 },
    "RefersTo != $pid OR  MemberOf != $pid" => { '-' => 1, c => 1, p => 1, rp => 1, rc1 => 1, rc2 => 1 },
);
{
    my $tix = RT::Tickets->new(RT->SystemUser);
    $tix->FromSQL("Queue = '". $q->id ."'");
    is($tix->Count, $total, "found $total tickets");
}
run_tests();

@tickets = ();


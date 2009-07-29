#!/usr/bin/perl -w

use strict;
use warnings;

use RT::Test tests => 80;
use RT::Ticket;

my $q = RT::Test->load_or_create_queue( Name => 'Regression' );
ok $q && $q->id, 'loaded or created queue';

my ($total, @data, @tickets, %test) = (0, ());

sub add_tix_from_data {
    my @res = ();
    while (@data) {
        my $t = RT::Ticket->new($RT::SystemUser);
        my %args = %{ shift(@data) };
        $args{$_} = $res[ $args{$_} ]->id foreach grep $args{$_}, keys %RT::Ticket::LINKTYPEMAP;
        my ( $id, undef $msg ) = $t->Create(
            Queue => $q->id,
            %args,
        );
        ok( $id, "ticket created" ) or diag("error: $msg");
        push @res, $t;
        $total++;
    }
    return @res;
}

sub run_tests {
    my $query_prefix = join ' OR ', map 'id = '. $_->id, @tickets;
    foreach my $key ( sort keys %test ) {
        my $tix = RT::Tickets->new($RT::SystemUser);
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
@data = (
    { Subject => '-', },
    { Subject => 'p', },
    { Subject => 'c', MemberOf => -1 },
);
@tickets = add_tix_from_data();
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
    my $tix = RT::Tickets->new($RT::SystemUser);
    $tix->FromSQL("Queue = '". $q->id ."'");
    is($tix->Count, $total, "found $total tickets");
}
run_tests();

# another set with tests of combinations searches
@data = (
    { Subject => '-', },
    { Subject => 'p', },
    { Subject => 'rp',  RefersTo => -1 },
    { Subject => 'c',   MemberOf => -2 },
    { Subject => 'rc1', RefersTo => -1 },
    { Subject => 'rc2', RefersTo => -2 },
);
@tickets = add_tix_from_data();
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
    my $tix = RT::Tickets->new($RT::SystemUser);
    $tix->FromSQL("Queue = '". $q->id ."'");
    is($tix->Count, $total, "found $total tickets");
}
run_tests();


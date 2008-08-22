#!/usr/bin/perl

use Test::More tests => 8;
use RT::Test;

use strict;
use warnings;

use RT::Model::TicketCollection;
use RT::Model::Queue;
use RT::CustomField;

#########################################################
# Test sorting by Queue, we sort by its name
#########################################################


diag "Create queues to test with." if $ENV{TEST_VERBOSE};
my @qids;
my @queues;
# create them in reverse order to avoid false positives
foreach my $name ( qw(sort-by-queue-Z sort-by-queue-A) ) {
    my $queue = RT::Model::Queue->new(current_user => RT->system_user );
    my ($ret, $msg) = $queue->create(
        name =>  $name ."-$$",
        description =>  'queue to test sorting by queue'
    );
    ok($ret, "test queue creation. $msg");
    push @queues, $queue;
    push @qids, $queue->id;
}

my ($total, @data, @tickets, @test) = (0, ());

sub add_tix_from_data {
    my @res = ();
    @data = sort { rand(100) <=> rand(100) } @data;
    while (@data) {
        my $t = RT::Model::Ticket->new(current_user => RT->system_user);
        my %args = %{ shift(@data) };
        my ( $id, undef, $msg ) = $t->create( %args );
        ok( $id, "ticket created" ) or diag("error: $msg");
        push @res, $t;
        $total++;
    }
    return @res;
}

sub run_tests {
    my $query_prefix = join ' OR ', map 'id = '. $_->id, @tickets;
    foreach my $test ( @test ) {
        my $query = join " AND ", map "( $_ )", grep defined && length,
            $query_prefix, $test->{'Query'};

        foreach my $order (qw(ASC DESC)) {
            my $error = 0;
            my $tix = RT::Model::TicketCollection->new(current_user => RT->system_user );
            $tix->from_sql( $query );
            $tix->OrderBy( FIELD => $test->{'Order'}, ORDER => $order );

            ok($tix->count, "found ticket(s)")
                or $error = 1;

            my ($order_ok, $last) = (1, $order eq 'ASC'? '-': 'zzzzzz');
            while ( my $t = $tix->next ) {
                my $tmp;
                if ( $order eq 'ASC' ) {
                    $tmp = ((split( /,/, $last))[0] cmp (split( /,/, $t->Subject))[0]);
                } else {
                    $tmp = -((split( /,/, $last))[-1] cmp (split( /,/, $t->Subject))[-1]);
                }
                if ( $tmp > 0 ) {
                    $order_ok = 0; last;
                }
                $last = $t->Subject;
            }

            ok( $order_ok, "$order order of tickets is good" )
                or $error = 1;

            if ( $error ) {
                diag "Wrong SQL query:". $tix->BuildSelectQuery;
                $tix->GotoFirstItem;
                while ( my $t = $tix->next ) {
                    diag sprintf "%02d - %s", $t->id, $t->Subject;
                }
            }
        }
    }
}

@data = (
    { Queue => $qids[0], Subject => 'z' },
    { Queue => $qids[1], Subject => 'a' },
);
@tickets = add_tix_from_data();
@test = (
    { Order => "Queue" },
);
run_tests();


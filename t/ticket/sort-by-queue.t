#!/usr/bin/perl

use Test::More tests => 8;
use RT::Test;

use strict;
use warnings;

use RT::Model::TicketCollection;
use RT::Model::Queue;
use RT::Model::CustomField;

#########################################################
# Test sorting by queue, we sort by its name
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
            $query_prefix, $test->{'query'};

        foreach my $order (qw(ASC DESC)) {
            my $error = 0;
            my $tix = RT::Model::TicketCollection->new(current_user => RT->system_user );
            $tix->from_sql( $query );
            $tix->order_by( { column => $test->{'order'}, order => $order } );

            ok($tix->count, "found ticket(s)")
                or $error = 1;

            my ($order_ok, $last) = (1, $order eq 'ASC'? '-': 'zzzzzz');
            while ( my $t = $tix->next ) {
                use Data::Dumper;
                my $tmp;
                if ( $order eq 'ASC' ) {
                    $tmp = ((split( /,/, $last))[0] cmp (split( /,/, $t->subject))[0]);
                } else {
                    $tmp = -((split( /,/, $last))[-1] cmp (split( /,/, $t->subject))[-1]);
                }
                if ( $tmp > 0 ) {
                    $order_ok = 0; last;
                }
                $last = $t->subject;
            }

            ok( $order_ok, "$order order of tickets is good" )
                or $error = 1;

            if ( $error ) {
                diag "Wrong SQL query:". $tix->build_select_query;
                $tix->goto_first_item;
                while ( my $t = $tix->next ) {
                    diag sprintf "%02d- %s", $t->id, $t->subject;
                }
            }
        }
    }
}

@data = (
    { queue => $qids[0], subject => 'z' },
    { queue => $qids[1], subject => 'a' },
);
@tickets = add_tix_from_data();
@test = (
    { order => "queue" },
);
run_tests();

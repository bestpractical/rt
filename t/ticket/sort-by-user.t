#!/usr/bin/perl

use Test::More tests => 32;
use RT::Test;

use strict;
use warnings;

use RT::Model::TicketCollection;
use RT::Model::Queue;
use RT::Model::CustomField;

#########################################################
# Test sorting by owner, creator and last_updated_by
# we sort by user name
#########################################################

diag "Create a queue to test with." if $ENV{TEST_VERBOSE};
my $queue_name = "OwnerSortQueue$$";
my $queue;
{
    $queue = RT::Model::Queue->new(current_user => RT->system_user );
    my ($ret, $msg) = $queue->create(
        name =>  $queue_name,
        description =>  'queue for custom field sort testing'
    );
    ok($ret, "$queue test queue creation. $msg");
}

my @uids;
my @users;
# create them in reverse order to avoid false positives
foreach my $u (qw(Z A)) {
    my $name = $u ."-user-to-test-ordering-$$";
    my $user = RT::Model::User->new(current_user => RT->system_user );
    my ($uid) = $user->create(
        name =>  $name,
        privileged => 1,
    );
    ok $uid, "created user #$uid";

    my ($status, $msg) = $user->principal_object->grant_right( right => 'OwnTicket', object => $queue );
    ok $status, "granted right";
    ($status, $msg) = $user->principal_object->grant_right( right => 'CreateTicket', object => $queue );
    ok $status, "granted right";

    push @users, $user;
    push @uids, $user->id;
}

my ($total, @data, @tickets, @test) = (0, ());

sub add_tix_from_data {
    my @res = ();
    @data = sort { rand(100) <=> rand(100) } @data;
    while (@data) {
        my $t = RT::Model::Ticket->new(current_user => RT->system_user);
        my %args = %{ shift(@data) };

        my ( $id, undef, $msg ) = $t->create( %args, queue => $queue->id );
        if ( $args{'owner'} ) {
            is $t->owner, $args{'owner'}, "owner is correct";
        }
        if ( $args{'creator'} ) {
            is $t->creator->id, $args{'creator'}, "creator is correct";
        }
        # hackish, but simpler
        if ( $args{'last_updated_by'} ) {
            $t->__set( column => 'last_updated_by', value => $args{'last_updated_by'} );
        }
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
                    diag sprintf "%02d - %s", $t->id, $t->subject;
                }
            }
        }
    }
}

@data = (
    { subject => 'Nobody' },
    { subject => 'Z', owner => $uids[0] },
    { subject => 'A', owner => $uids[1] },
);
@tickets = add_tix_from_data();
@test = (
    { order => "owner" },
);
run_tests();

@data = (
    { subject => 'RT' },
    { subject => 'Z', creator => $uids[0] },
    { subject => 'A', creator => $uids[1] },
);
@tickets = add_tix_from_data();
@test = (
    { order => "creator" },
);
run_tests();

@data = (
    { subject => 'RT' },
    { subject => 'Z', last_updated_by => $uids[0] },
    { subject => 'A', last_updated_by => $uids[1] },
);
@tickets = add_tix_from_data();
@test = (
    { order => "last_updated_by" },
);
run_tests();


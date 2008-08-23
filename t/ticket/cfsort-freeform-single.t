#!/usr/bin/perl

use Test::More tests => 57;
use RT::Test;

use strict;
use warnings;

use RT::Model::TicketCollection;
use RT::Model::Queue;
use RT::Model::CustomField;

# Test Sorting by FreeformSingle custom field.

diag "Create a queue to test with." if $ENV{TEST_VERBOSE};
my $queue_name = "CFSortQueue-$$";
my $queue;
{
    $queue = RT::Model::Queue->new(current_user => RT->system_user );
    my ($ret, $msg) = $queue->create(
        name =>  $queue_name,
        description =>  'queue for custom field sort testing'
    );
    ok($ret, "$queue test queue creation. $msg");
}

# CFs for testing, later we create another one
my %CF;
my $cf_name;

diag "create a CF\n" if $ENV{TEST_VERBOSE};
{
    $cf_name = $CF{'CF'}{'name'} = "Order$$";
    $CF{'CF'}{'obj'} = RT::Model::CustomField->new( current_user => RT->system_user );
    my ($ret, $msg) = $CF{'CF'}{'obj'}->create(
        name  => $CF{'CF'}{'name'},
        queue => $queue->id,
        type  => 'FreeformSingle',
    );
    ok($ret, "Custom Field $CF{'CF'}{'name'} created");
}

my ($total, @data, @tickets, @test) = (0, ());

sub add_tix_from_data {
    my @res = ();
    @data = sort { rand(100) <=> rand(100) } @data;
    while (@data) {
        my $t = RT::Model::Ticket->new(current_user => RT->system_user);
        my %args = %{ shift(@data) };

        my $subject = '-';
        foreach my $e ( grep exists $CF{$_} && defined $CF{$_}, keys %args ) {
            my @values = ();
            if ( ref $args{ $e } ) {
                @values = @{ delete $args{ $e } };
            } else {
                @values = (delete $args{ $e });
            }
            $args{ 'CustomField-'. $CF{ $e }{'obj'}->id } = \@values
                if @values;
            $subject = join(",", sort @values) || '-'
                if $e eq 'CF';
        }

        my ( $id, undef $msg ) = $t->create(
            %args,
            queue => $queue->id,
            subject => $subject,
        );
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
            $tix->order_by( field => $test->{'Order'}, order => $order );

            ok($tix->count, "found ticket(s)")
                or $error = 1;

            my ($order_ok, $last) = (1, $order eq 'ASC'? '-': 'zzzzzz');
            my $last_id = $tix->last->id;
            while ( my $t = $tix->next ) {
                my $tmp;
                next if $t->id == $last_id and $t->subject eq "-"; # Nulls are allowed to come last, in Pg

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
    { },
    { cf => 'a' },
    { cf => 'b' },
);
@tickets = add_tix_from_data();
@test = (
    { order => "CF.{$cf_name}" },
    { order => "CF.$queue_name.{$cf_name}" },
);
run_tests();

@data = (
    { },
    { cf => 'aa' },
    { cf => 'ab' },
);
@tickets = add_tix_from_data();
@test = (
    { query => "CF.{$cf_name} LIKE 'a'", order => "CF.{$cf_name}" },
    { query => "CF.{$cf_name} LIKE 'a'", order => "CF.$queue_name.{$cf_name}" },
);
run_tests();

@data = (
    { subject => '-', },
    { subject => 'a', cf => 'a' },
    { subject => 'b', cf => 'b' },
    { subject => 'c', cf => 'c' },
);
@tickets = add_tix_from_data();
@test = (
    { query => "CF.{$cf_name} != 'c'", order => "CF.{$cf_name}" },
    { query => "CF.{$cf_name} != 'c'", order => "CF.$queue_name.{$cf_name}" },
);
run_tests();



diag "create another CF\n" if $ENV{TEST_VERBOSE};
{
    $CF{'AnotherCF'}{'name'} = "OrderAnother$$";
    $CF{'AnotherCF'}{'obj'} = RT::Model::CustomField->new( current_user => RT->system_user );
    my ($ret, $msg) = $CF{'AnotherCF'}{'obj'}->create(
        name  => $CF{'AnotherCF'}{'name'},
        queue => $queue->id,
        type  => 'FreeformSingle',
    );
    ok($ret, "Custom Field $CF{'AnotherCF'}{'name'} created");
}

# test that order is not affect by other fields (had such problem)
@data = (
    { subject => '-', },
    { subject => 'a', cf => 'a', another_cf => 'za' },
    { subject => 'b', cf => 'b', another_cf => 'ya' },
    { subject => 'c', cf => 'c', another_cf => 'xa' },
);
@tickets = add_tix_from_data();
@test = (
    { order => "CF.{$cf_name}" },
    { order => "CF.$queue_name.{$cf_name}" },
    { query => "CF.{$cf_name} != 'c'", order => "CF.{$cf_name}" },
    { query => "CF.{$cf_name} != 'c'", order => "CF.$queue_name.{$cf_name}" },
);
run_tests();




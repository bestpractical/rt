#!/usr/bin/perl

use RT::Test tests => 24;

use strict;
use warnings;

use RT::Tickets;
use RT::Queue;
use RT::CustomField;

# Test Sorting by custom fields.

diag "Create a queue to test with." if $ENV{TEST_VERBOSE};
my $queue_name = "CFSortQueue-$$";
my $queue;
{
    $queue = RT::Queue->new( $RT::SystemUser );
    my ($ret, $msg) = $queue->Create(
        Name => $queue_name,
        Description => 'queue for custom field sort testing'
    );
    ok($ret, "$queue_name - test queue creation. $msg");
}

diag "create a CF\n" if $ENV{TEST_VERBOSE};
my $cf_name = "Order$$";
my $cf;
{
    $cf = RT::CustomField->new( $RT::SystemUser );
    my ($ret, $msg) = $cf->Create(
        Name  => $cf_name,
        Queue => $queue->id,
        Type  => 'FreeformMultiple',
    );
    ok($ret, "Custom Field Order created");
}

my ($total, @data, @tickets, @test) = (0, ());

sub add_tix_from_data {
    my @res = ();
    @data = sort { rand(100) <=> rand(100) } @data;
    while (@data) {
        my $t = RT::Ticket->new($RT::SystemUser);
        my %args = %{ shift(@data) };
        my @values = ();
        if ( exists $args{'CF'} && ref $args{'CF'} ) {
            @values = @{ delete $args{'CF'} };
        } elsif ( exists $args{'CF'} ) {
            @values = (delete $args{'CF'});
        }
        $args{ 'CustomField-'. $cf->id } = \@values
            if @values;
        my $subject = join(",", sort @values) || '-';
        my ( $id, undef $msg ) = $t->Create(
            %args,
            Queue => $queue->id,
            Subject => $subject,
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
            my $tix = RT::Tickets->new( $RT::SystemUser );
            $tix->FromSQL( $query );
            $tix->OrderBy( FIELD => $test->{'Order'}, ORDER => $order );

            ok($tix->Count, "found ticket(s)")
                or $error = 1;

            my ($order_ok, $last) = (1, $order eq 'ASC'? '-': 'zzzzzz');
            my $last_id = $tix->Last->id;
            while ( my $t = $tix->Next ) {
                my $tmp;
                next if $t->id == $last_id and $t->Subject eq "-"; # Nulls are allowed to come last, in Pg

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
                while ( my $t = $tix->Next ) {
                    diag sprintf "%02d - %s", $t->id, $t->Subject;
                }
            }
        }
    }
}

@data = (
    { },
    { CF => ['b', 'd'] },
    { CF => ['a', 'c'] },
);
@tickets = add_tix_from_data();
@test = (
    { Order => "CF.{$cf_name}" },
    { Order => "CF.$queue_name.{$cf_name}" },
);
run_tests();

@data = (
    { CF => ['m', 'a'] },
    { CF => ['m'] },
    { CF => ['m', 'o'] },
);
@tickets = add_tix_from_data();
@test = (
    { Order => "CF.{$cf_name}", Query => "CF.{$cf_name} = 'm'" },
    { Order => "CF.$queue_name.{$cf_name}", Query => "CF.{$cf_name} = 'm'" },
);
run_tests();


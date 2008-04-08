#!/usr/bin/perl

use Test::More tests => 57;
use RT;
RT::LoadConfig();
RT::Init();

use strict;
use warnings;

use RT::Tickets;
use RT::Queue;
use RT::CustomField;

# Test Sorting by FreeformSingle custom field.

diag "Create a queue to test with.";
my $queue_name = "CFSortQueue$$";
my $queue;
{
    $queue = RT::Queue->new( $RT::SystemUser );
    my ($ret, $msg) = $queue->Create(
        Name => $queue,
        Description => 'queue for custom field sort testing'
    );
    ok($ret, "$queue test queue creation. $msg");
}

# CFs for testing, later we create another one
my %CF;
my $cf_name;

diag "create a CF\n";
{
    $cf_name = $CF{'CF'}{'name'} = "Order$$";
    $CF{'CF'}{'obj'} = RT::CustomField->new( $RT::SystemUser );
    my ($ret, $msg) = $CF{'CF'}{'obj'}->Create(
        Name  => $CF{'CF'}{'name'},
        Queue => $queue->id,
        Type  => 'FreeformSingle',
    );
    ok($ret, "Custom Field $CF{'CF'}{'name'} created");
}

my ($total, @data, @tickets, @test) = (0, ());

sub add_tix_from_data {
    my @res = ();
    @data = sort { rand(100) <=> rand(100) } @data;
    while (@data) {
        my $t = RT::Ticket->new($RT::SystemUser);
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
            while ( my $t = $tix->Next ) {
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
                while ( my $t = $tix->Next ) {
                    diag sprintf "%02d - %s", $t->id, $t->Subject;
                }
            }
        }
    }
}

@data = (
    { },
    { CF => 'a' },
    { CF => 'b' },
);
@tickets = add_tix_from_data();
@test = (
    { Order => "CF.{$cf_name}" },
    { Order => "CF.$queue_name.{$cf_name}" },
);
run_tests();

@data = (
    { },
    { CF => 'aa' },
    { CF => 'ab' },
);
@tickets = add_tix_from_data();
@test = (
    { Query => "CF.{$cf_name} LIKE 'a'", Order => "CF.{$cf_name}" },
    { Query => "CF.{$cf_name} LIKE 'a'", Order => "CF.$queue_name.{$cf_name}" },
);
run_tests();

@data = (
    { Subject => '-', },
    { Subject => 'a', CF => 'a' },
    { Subject => 'b', CF => 'b' },
    { Subject => 'c', CF => 'c' },
);
@tickets = add_tix_from_data();
@test = (
    { Query => "CF.{$cf_name} != 'c'", Order => "CF.{$cf_name}" },
    { Query => "CF.{$cf_name} != 'c'", Order => "CF.$queue_name.{$cf_name}" },
);
run_tests();



diag "create another CF\n";
{
    $CF{'AnotherCF'}{'name'} = "OrderAnother$$";
    $CF{'AnotherCF'}{'obj'} = RT::CustomField->new( $RT::SystemUser );
    my ($ret, $msg) = $CF{'AnotherCF'}{'obj'}->Create(
        Name  => $CF{'AnotherCF'}{'name'},
        Queue => $queue->id,
        Type  => 'FreeformSingle',
    );
    ok($ret, "Custom Field $CF{'AnotherCF'}{'name'} created");
}

# test that order is not affect by other fields (had such problem)
@data = (
    { Subject => '-', },
    { Subject => 'a', CF => 'a', AnotherCF => 'za' },
    { Subject => 'b', CF => 'b', AnotherCF => 'ya' },
    { Subject => 'c', CF => 'c', AnotherCF => 'xa' },
);
@tickets = add_tix_from_data();
@test = (
    { Order => "CF.{$cf_name}" },
    { Order => "CF.$queue_name.{$cf_name}" },
    { Query => "CF.{$cf_name} != 'c'", Order => "CF.{$cf_name}" },
    { Query => "CF.{$cf_name} != 'c'", Order => "CF.$queue_name.{$cf_name}" },
);
run_tests();




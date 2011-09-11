#!/usr/bin/perl -w

use strict;
use warnings;

use RT::Test tests => 14;
use RT::Ticket;

my $q1 = RT::Test->load_or_create_queue( Name => 'One' );
ok $q1 && $q1->id, 'loaded or created queue';

my $q2 = RT::Test->load_or_create_queue( Name => 'Two' );
ok $q2 && $q2->id, 'loaded or created queue';

my @tickets = add_tix_from_data(
    { Queue => $q1->id, Resolved => 3*60 },
    { Queue => $q1->id, Resolved => 3*60*60 },
    { Queue => $q1->id, Resolved => 3*24*60*60 },
    { Queue => $q1->id, Resolved => 3*30*24*60*60 },
    { Queue => $q1->id, Resolved => 9*30*24*60*60 },
    { Queue => $q2->id, Resolved => 7*60 },
    { Queue => $q2->id, Resolved => 7*60*60 },
    { Queue => $q2->id, Resolved => 7*24*60*60 },
    { Queue => $q2->id, Resolved => 7*30*24*60*60 },
    { Queue => $q2->id, Resolved => 24*30*24*60*60 },
);

use_ok 'RT::Report::Tickets';

{
    my $report = RT::Report::Tickets->new( RT->SystemUser );
    my %columns = $report->SetupGroupings(
        Query    => 'id > 0',
        GroupBy  => ['Queue'],
        Function => ['ALL(Created-Resolved)'],
    );

    my $expected = {
           'thead' => [
                        {
                          'cells' => [
                               { 'rowspan' => 2, 'value' => 'Queue', 'type' => 'head' },
                               { 'colspan' => 4, 'value' => 'Created-Resolved', 'type' => 'head' }
                             ]
                        },
                        {
                          'cells' => [
                               { 'value' => 'Minimum', 'type' => 'head' },
                               { 'value' => 'Average', 'type' => 'head' },
                               { 'value' => 'Maximum', 'type' => 'head' },
                               { 'value' => 'Summary', 'type' => 'head' }
                             ]
                        }
                      ],
           'tfoot' => [
                        {
                          'cells' => [
                               { 'colspan' => 1, 'value' => 'Total', 'type' => 'label' },
                               { 'value' => '10 min', 'type' => 'value' },
                               { 'value' => '9 months', 'type' => 'value' },
                               { 'value' => '3 years', 'type' => 'value' },
                               { 'value' => '4 years', 'type' => 'value' }
                             ],
                          'even' => 1
                        }
                      ],
           'tbody' => [
                        {
                          'cells' => [
                               { 'value' => 'One', 'type' => 'label' },
                               { 'query' => '(Queue = 3)', 'value' => '3 min', 'type' => 'value' },
                               { 'query' => '(Queue = 3)', 'value' => '2 months', 'type' => 'value' },
                               { 'query' => '(Queue = 3)', 'value' => '9 months', 'type' => 'value' },
                               { 'query' => '(Queue = 3)', 'value' => '12 months', 'type' => 'value' }
                             ],
                          'even' => 1
                        },
                        {
                          'cells' => [
                               { 'value' => 'Two', 'type' => 'label' },
                               { 'query' => '(Queue = 4)', 'value' => '7 min', 'type' => 'value' },
                               { 'query' => '(Queue = 4)', 'value' => '6 months', 'type' => 'value' },
                               { 'query' => '(Queue = 4)', 'value' => '2 years', 'type' => 'value' },
                               { 'query' => '(Queue = 4)', 'value' => '3 years', 'type' => 'value' }
                             ],
                          'even' => 0
                        }
                      ]
         };


    my %table = $report->FormatTable( %columns );
    is_deeply( \%table, $expected, "basic table" );
}


sub add_tix_from_data {
    my @data = @_;
    my @res = ();

    my $created = RT::Date->new( $RT::SystemUser );
    $created->SetToNow;

    my $resolved = RT::Date->new( $RT::SystemUser );

    while (@data) {
        $resolved->Set( Value => $created->Unix );
        $resolved->AddSeconds( $data[0]{'Resolved'} );
        my $t = RT::Ticket->new($RT::SystemUser);
        my ( $id, undef $msg ) = $t->Create(
            %{ shift(@data) },
            Created => $created->ISO,
            Resolved => $resolved->ISO,
        );
        ok( $id, "ticket created" ) or diag("error: $msg");
        push @res, $t;
    }
    return @res;
}



#!/usr/bin/perl -w

use strict;
use warnings;

use RT::Test tests => 13;
use RT::Ticket;

my $q = RT::Test->load_or_create_queue( Name => 'Default' );
ok $q && $q->id, 'loaded or created queue';
my $queue = $q->Name;

my (%test) = (0, ());

my @tickets = add_tix_from_data(
    { Subject => 'n', Status => 'new' },
    { Subject => 'o', Status => 'open' },
    { Subject => 'o', Status => 'open' },
    { Subject => 's', Status => 'stalled' },
    { Subject => 's', Status => 'stalled' },
    { Subject => 's', Status => 'stalled' },
    { Subject => 'r', Status => 'resolved' },
    { Subject => 'r', Status => 'resolved' },
    { Subject => 'r', Status => 'resolved' },
    { Subject => 'r', Status => 'resolved' },
);

use_ok 'RT::Report::Tickets';

{
    my $report = RT::Report::Tickets->new( RT->SystemUser );
    my %columns = $report->SetupGroupings(
        Query    => 'Queue = '. $q->id,
        GroupBy  => ['Status'],
        Function => ['COUNT'],
    );

    my $expected = {
        'thead' => [ {
                'cells' => [
                    { 'value' => 'Status', 'type' => 'head' },
                    { 'rowspan' => 1, 'value' => 'Tickets', 'type' => 'head' },
                ],
        } ],
       'tfoot' => [ {
            'cells' => [
                { 'colspan' => 1, 'value' => 'Total', 'type' => 'label' },
                { 'value' => 10, 'type' => 'value' },
            ],
            'even' => 1
        } ],
       'tbody' => [
            {
                'cells' => [
                    { 'value' => 'new', 'type' => 'label' },
                    { 'query' => 'Status = \'new\'', 'value' => '1', 'type' => 'value' },
                ],
                'even' => 1
            },
            {
                'cells' => [
                    { 'value' => 'open', 'type' => 'label' },
                    { 'query' => 'Status = \'open\'', 'value' => '2', 'type' => 'value' }
                ],
                'even' => 0
            },
            {
                'cells' => [
                    { 'value' => 'resolved', 'type' => 'label' },
                    { 'query' => 'Status = \'resolved\'', 'value' => '4', 'type' => 'value' }
                ],
                'even' => 1
            },
            {
                'cells' => [
                    { 'value' => 'stalled', 'type' => 'label' },
                    { 'query' => 'Status = \'stalled\'', 'value' => '3', 'type' => 'value' }
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
    while (@data) {
        my $t = RT::Ticket->new($RT::SystemUser);
        my ( $id, undef $msg ) = $t->Create(
            Queue => $q->id,
            %{ shift(@data) },
        );
        ok( $id, "ticket created" ) or diag("error: $msg");
        push @res, $t;
    }
    return @res;
}


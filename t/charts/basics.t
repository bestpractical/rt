use strict;
use warnings;

use RT::Test tests => undef;
use RT::Ticket;

my $q = RT::Test->load_or_create_queue( Name => 'General' );
ok $q && $q->id, 'loaded or created queue';
my $queue = $q->Name;

my @tickets = add_tix_from_data(
    { Subject => 'n', Status => 'new' },
    { Subject => 'o', Status => 'open' },
    { Subject => 'o', Status => 'open' },
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
    $report->SortEntries;

    my @colors = RT->Config->Get("ChartColors");
    my $expected = {
        'thead' => [ {
                'cells' => [
                    { 'value' => 'Status', 'type' => 'head' },
                    { 'rowspan' => 1, 'value' => 'Ticket count', 'type' => 'head', 'color' => $colors[0] },
                ],
        } ],
       'tfoot' => [ {
            'cells' => [
                { 'colspan' => 1, 'value' => 'Total', 'type' => 'label' },
                { 'value' => 6, 'type' => 'value' },
            ],
            'even' => 0
        } ],
       'tbody' => [
            {
                'cells' => [
                    { 'value' => 'new', 'type' => 'label' },
                    { 'query' => '(Status = \'new\')', 'value' => '1', 'type' => 'value' },
                ],
                'even' => 1
            },
            {
                'cells' => [
                    { 'value' => 'open', 'type' => 'label' },
                    { 'query' => '(Status = \'open\')', 'value' => '2', 'type' => 'value' }
                ],
                'even' => 0
            },
            {
                'cells' => [
                    { 'value' => 'resolved', 'type' => 'label' },
                    { 'query' => '(Status = \'resolved\')', 'value' => '3', 'type' => 'value' }
                ],
                'even' => 1
            },
        ]
    };

    my %table = $report->FormatTable( %columns );
    is_deeply( \%table, $expected, "basic table" );
}

done_testing;


sub add_tix_from_data {
    my @data = @_;
    my @res = ();
    while (@data) {
        my %info = %{ shift(@data) };
        my $t = RT::Ticket->new($RT::SystemUser);
        my ( $id, undef, $msg ) = $t->Create( Queue => $q->id, %info );
        ok( $id, "ticket created" ) or diag("error: $msg");
        is $t->Status, $info{'Status'}, 'correct status';
        push @res, $t;
    }
    return @res;
}


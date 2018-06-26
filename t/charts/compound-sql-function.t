
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
    $report->SortEntries;

    my @colors = RT->Config->Get("ChartColors");
    my $expected = {
           'thead' => [
                        {
                          'cells' => [
                               { 'rowspan' => 2, 'value' => 'Queue', 'type' => 'head' },
                               { 'colspan' => 4, 'value' => 'Summary of Created-Resolved', 'type' => 'head' }
                             ]
                        },
                        {
                          'cells' => [
                               { 'value' => 'Minimum', 'type' => 'head', 'color' => $colors[0] },
                               { 'value' => 'Average', 'type' => 'head', 'color' => $colors[1] },
                               { 'value' => 'Maximum', 'type' => 'head', 'color' => $colors[2] },
                               { 'value' => 'Total', 'type' => 'head', 'color' => $colors[3] }
                             ]
                        }
                      ],
           'tfoot' => [
                        {
                          'cells' => [
                               { 'colspan' => 1, 'value' => 'Total', 'type' => 'label' },
                               { 'value' => '10m', 'type' => 'value' },
                               { 'value' => '8M 2W 3d', 'type' => 'value' },
                               { 'value' => '2Y 8M 2W', 'type' => 'value' },
                               { 'value' => '3Y 6M 3W', 'type' => 'value' }
                             ],
                          'even' => 1
                        }
                      ],
           'tbody' => [
                        {
                          'cells' => [
                               { 'value' => 'One', 'type' => 'label' },
                               { 'query' => '(Queue = 3)', 'value' => '3m', 'type' => 'value' },
                               { 'query' => '(Queue = 3)', 'value' => '2M 1W 5d', 'type' => 'value' },
                               { 'query' => '(Queue = 3)', 'value' => '8M 3W 6d', 'type' => 'value' },
                               { 'query' => '(Queue = 3)', 'value' => '11M 4W 8h', 'type' => 'value' }
                             ],
                          'even' => 1
                        },
                        {
                          'cells' => [
                               { 'value' => 'Two', 'type' => 'label' },
                               { 'query' => '(Queue = 4)', 'value' => '7m', 'type' => 'value' },
                               { 'query' => '(Queue = 4)', 'value' => '6M 4d 20h', 'type' => 'value' },
                               { 'query' => '(Queue = 4)', 'value' => '1Y 11M 3W', 'type' => 'value' },
                               { 'query' => '(Queue = 4)', 'value' => '2Y 6M 3W', 'type' => 'value' }
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
        my ( $id, undef, $msg ) = $t->Create(
            %{ shift(@data) },
            Created => $created->ISO,
            Resolved => $resolved->ISO,
        );
        ok( $id, "ticket created" ) or diag("error: $msg");
        push @res, $t;
    }
    return @res;
}



use strict;
use warnings;

use RT::Test
    tests => undef,
    config =>  <<THERE;
Set(%ServiceAgreements, (
    Default => '2',
    Levels => {
        '2' => {
            StartImmediately => 1,
            Response => { RealMinutes => 60 * 2 },
        },
        '4' => {
            StartImmediately => 1,
            Response => { RealMinutes => 60 * 4 },
        },
    },
));
THERE
use RT::Ticket;

my $q = RT::Test->load_or_create_queue( Name => 'test', SLADisabled => 0 );
ok $q && $q->id, 'loaded or created queue';
my $queue = $q->Name;

my $t1 = RT::Ticket->new( $RT::SystemUser );
my $t1_id = $t1->Create( Queue => $queue, Subject => 'test 1' );
ok $t1_id, "created ticket #$t1_id";
is $t1->SLA, '2', 'default sla';

my $t2 = RT::Ticket->new( $RT::SystemUser );
my $t2_id = $t2->Create( Queue => $queue, Subject => 'test 2' );
ok $t2_id, "created ticket #$t2_id";
is $t2->SLA, '2', 'default sla';
$t2->SetSLA('4');
is $t2->SLA, '4', 'new sla';

my $t3 = RT::Ticket->new($RT::SystemUser);
my $t3_id = $t3->Create( Queue => $queue, Subject => 'test 3' );
ok $t3_id, "created ticket #$t3_id";
is $t3->SLA, '2', 'default sla';

use_ok 'RT::Report::Tickets';

{
    my $report = RT::Report::Tickets->new( RT->SystemUser );
    my %columns = $report->SetupGroupings(
        Query    => 'Queue = '. $q->id,
        GroupBy  => ["SLA"],
        Function => ['COUNT'],
    );
    $report->SortEntries;

    my @colors = RT->Config->Get("ChartColors");
    my $expected = {
        'thead' => [ {
                'cells' => [
                    { 'value' => 'SLA', 'type' => 'head' },
                    { 'rowspan' => 1, 'value' => 'Ticket count', 'type' => 'head', 'color' => $colors[0] },
                ],
        } ],
       'tfoot' => [ {
            'cells' => [
                { 'colspan' => 1, 'value' => 'Total', 'type' => 'label' },
                { 'value' => 3, 'type' => 'value' },
            ],
            'even' => 1
        } ],
       'tbody' => [
            {
                'cells' => [
                    { 'value' => '2', 'type' => 'label' },
                    { 'query' => "(SLA = 2)", 'value' => '2', 'type' => 'value' },
                ],
                'even' => 1
            },
            {
                'cells' => [
                    { 'value' => '4', 'type' => 'label' },
                    { 'query' => "(SLA = 4)", 'value' => '1', 'type' => 'value' },
                ],
                'even' => 0
            },
        ]
    };

    my %table = $report->FormatTable( %columns );
    is_deeply( \%table, $expected, "basic table" );
}

done_testing;

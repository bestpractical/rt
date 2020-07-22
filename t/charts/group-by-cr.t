use strict;
use warnings;

use RT::Test tests => undef;
use RT::Ticket;

my $q = RT::Test->load_or_create_queue( Name => 'General' );
ok $q && $q->id, 'loaded or created queue';
my $queue = $q->Name;

my $cr = RT::CustomRole->new( RT->SystemUser );
my ( $id, $msg ) = $cr->Create( Name => 'Test', Queue => $q->id );
ok $id, $msg;
ok( $cr->AddToObject( ObjectId => $q->id ) );
my $cr_id = $cr->id;

my @tickets = RT::Test->create_tickets(
    {},
    { Subject => 't1', Status => 'new', "RT::CustomRole-$cr_id" => 'root@localhost' },
    { Subject => 't2', Status => 'new', "RT::CustomRole-$cr_id" => 'root@localhost' },
    { Subject => 't3', Status => 'new' },
);

use_ok 'RT::Report::Tickets';

{
    my $report  = RT::Report::Tickets->new( RT->SystemUser );
    my %columns = $report->SetupGroupings(
        Query    => 'Queue = ' . $q->id,
        GroupBy  => ["CustomRole.{$cr_id}.Name"],
        Function => ['COUNT'],
    );
    $report->SortEntries;

    my @colors   = RT->Config->Get("ChartColors");
    my $expected = {
        'thead' => [
            {   'cells' => [
                    { 'value'   => 'Test Name', 'type'  => 'head' },
                    { 'rowspan' => 1,           'value' => 'Ticket count', 'type' => 'head', 'color' => $colors[0] },
                ],
            }
        ],
        'tfoot' => [
            {   'cells' =>
                    [ { 'colspan' => 1, 'value' => 'Total', 'type' => 'label' }, { 'value' => 3, 'type' => 'value' }, ],
                'even' => 1,
            }
        ],
        'tbody' => [
            {   'cells' => [
                    {   'type'  => 'label',
                        'value' => '(no value)'
                    },
                    {   'query' => '(CustomRole.{1}.Name IS NULL)',
                        'type'  => 'value',
                        'value' => '1'
                    }
                ],
                'even' => 1
            },
            {   'cells' => [
                    {   'type'  => 'label',
                        'value' => 'root'
                    },
                    {   'value' => '2',
                        'query' => '(CustomRole.{1}.Name = \'root\')',
                        'type'  => 'value'
                    }
                ],
                'even' => 0
            },
        ],
    };

    my %table = $report->FormatTable(%columns);
    is_deeply( \%table, $expected, "basic table" );
}

done_testing;

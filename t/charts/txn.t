use strict;
use warnings;

use RT::Test tests => undef;
use RT::Report::Transactions;

my $ticket = RT::Test->create_ticket( Queue => 'General', Subject => 'test', TimeWorked => 20 );
$ticket->Comment( Content => 'test comment', TimeTaken => 5 );
$ticket->Comment( Content => 'test comment', TimeTaken => 15 );

my $report  = RT::Report::Transactions->new( RT->SystemUser );
my %columns = $report->SetupGroupings(
    Query    => q{Type = 'Create' OR Type = 'Comment'},
    GroupBy  => ['Creator'],
    Function => ['COUNT'],
);
$report->SortEntries;

my @colors   = RT->Config->Get("ChartColors");
my $expected = {
    'thead' => [
        {
            'cells' => [
                {
                    'type'  => 'head',
                    'value' => 'Creator'
                },
                {
                    'color'   => $colors[0],
                    'rowspan' => 1,
                    'type'    => 'head',
                    'value'   => 'Transaction count'
                }
            ]
        }
    ],
    'tbody' => [
        {
            'cells' => [
                {
                    'type'  => 'label',
                    'value' => 'RT_System'
                },
                {
                    'query' => '(Creator = \'RT_System\')',
                    'type'  => 'value',
                    'value' => '3'
                }
            ],
            'even' => 1
        }
    ],
    'tfoot' => [
        {
            'cells' => [
                {
                    'colspan' => 1,
                    'type'    => 'label',
                    'value'   => 'Total'
                },
                {
                    'type'  => 'value',
                    'value' => 3
                }
            ],
            'even' => 0
        }
    ],
};

my %table = $report->FormatTable(%columns);
is_deeply( \%table, $expected, "basic table" );

$report  = RT::Report::Transactions->new( RT->SystemUser );
%columns = $report->SetupGroupings(
    Query    => q{(Type = 'Create' OR Type = 'Comment') AND TimeTaken > 0},
    GroupBy  => ['Creator'],
    Function => ['ALL(TimeTaken)'],
);
$report->SortEntries;
$expected = {
    'thead' => [
        {
            'cells' => [
                {
                    'rowspan' => 2,
                    'type'    => 'head',
                    'value'   => 'Creator'
                },
                {
                    'colspan' => 4,
                    'type'    => 'head',
                    'value'   => 'Summary of Time Taken'
                }
            ]
        },
        {
            'cells' => [
                {
                    'color' => $colors[0],
                    'type'  => 'head',
                    'value' => 'Minimum'
                },
                {
                    'color' => $colors[1],
                    'type'  => 'head',
                    'value' => 'Average'
                },
                {
                    'color' => $colors[2],
                    'type'  => 'head',
                    'value' => 'Maximum'
                },
                {
                    'color' => $colors[3],
                    'type'  => 'head',
                    'value' => 'Total'
                }
            ]
        }
    ],
    'tbody' => [
        {
            'cells' => [
                {
                    'type'  => 'label',
                    'value' => 'RT_System'
                },
                {
                    'query' => '(Creator = \'RT_System\')',
                    'type'  => 'value',
                    'value' => '5m'
                },
                {
                    'query' => '(Creator = \'RT_System\')',
                    'type'  => 'value',
                    'value' => '13m 20s'
                },
                {
                    'query' => '(Creator = \'RT_System\')',
                    'type'  => 'value',
                    'value' => '20m'
                },
                {
                    'query' => '(Creator = \'RT_System\')',
                    'type'  => 'value',
                    'value' => '40m'
                }
            ],
            'even' => 1
        }
    ],
    'tfoot' => [
        {
            'cells' => [
                {
                    'colspan' => 1,
                    'type'    => 'label',
                    'value'   => 'Total'
                },
                {
                    'type'  => 'value',
                    'value' => '5m'
                },
                {
                    'type'  => 'value',
                    'value' => '13m 20s'
                },
                {
                    'type'  => 'value',
                    'value' => '20m'
                },
                {
                    'type'  => 'value',
                    'value' => '40m'
                }
            ],
            'even' => 0
        }
    ],
};
%table = $report->FormatTable(%columns);
is_deeply( \%table, $expected, "TimeTaken table" );

done_testing;

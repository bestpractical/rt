use strict;
use warnings;

use RT::Test::Assets tests => undef;
use RT::Report::Assets;

for my $status (qw/new in-use in-use allocated/) {    # 2 in-use assets
    create_asset( Catalog => 'General assets', Name => 'test', Status => $status );
}

my $report  = RT::Report::Assets->new( RT->SystemUser );
my %columns = $report->SetupGroupings(
    Query    => q{Catalog = 'General assets'},
    GroupBy  => ['Status'],
    Function => ['COUNT'],
);
$report->SortEntries;

my $expected = {
    'thead' => [
        {
            'cells' => [
                {
                    'type'  => 'head',
                    'value' => 'Status'
                },
                {
                    'rowspan' => 1,
                    'type'    => 'head',
                    'value'   => 'Asset count'
                }
            ]
        }
    ],
    'tbody' => [
        {
            'cells' => [
                {
                    'type'  => 'label',
                    'value' => 'allocated',
                },
                {
                    'query' => "(Status = 'allocated')",
                    'type'  => 'value',
                    'value' => '1',
                }
            ],
            'even' => 1
        },
        {
            'even'  => 0,
            'cells' => [
                {
                    'type'  => 'label',
                    'value' => 'in-use',
                },
                {
                    'query' => "(Status = 'in-use')",
                    'type'  => 'value',
                    'value' => '2',
                }
            ]
        },
        {
            'even'  => 1,
            'cells' => [
                {
                    'type'  => 'label',
                    'value' => 'new',
                },
                {
                    'query' => "(Status = 'new')",
                    'type'  => 'value',
                    'value' => '1',
                }
            ]
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
                    'value' => 4
                }
            ],
            'even' => 0
        }
    ],
};

my %table = $report->FormatTable(%columns);
is_deeply( \%table, $expected, "basic table" );

done_testing;

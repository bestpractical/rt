use strict;
use warnings;

use RT::Test tests => undef;
use RT::Ticket;
use RT::Report::Tickets;

my $q       = RT::Test->load_or_create_queue( Name => 'General' );
my $cost    = RT::Test->load_or_create_custom_field( Name => 'Cost', Type => 'FreeformSingle', Queue => $q->Id );
my $cost_id = $cost->Id;

{
    no warnings 'redefine';
    use RT::CustomField;
    *RT::CustomField::IsNumeric = sub {
        my $self = shift;
        return $self->Name eq 'Cost' ? 1 : 0;
    };

    # Get around Pg 14's trailing 0 format like 25.000
    *RT::CustomField::NumericPrecision = sub {
        my $self = shift;
        return $self->Name eq 'Cost' ? 0 : undef;
    };
}

my @tickets = RT::Test->create_tickets(
    { Subject => 'test' },
    { Status  => 'new',  'CustomField-' . $cost->Id => 10 },
    { Status  => 'open', 'CustomField-' . $cost->Id => 15 },
    { Status  => 'new',  'CustomField-' . $cost->Id => 40 },
);

my $report  = RT::Report::Tickets->new( RT->SystemUser );
my %columns = $report->SetupGroupings(
    Query    => 'Queue = ' . $q->id,
    GroupBy  => ['Status'],
    Function => ["ALL(CF.$cost_id)"],
);
$report->SortEntries;

my $expected = {
    'thead' => [
        {
            'cells' => [
                {
                    'rowspan' => 2,
                    'type'    => 'head',
                    'value'   => 'Status'
                },
                {
                    'colspan' => 4,
                    'type'    => 'head',
                    'value'   => 'Summary of Cost'
                }
            ]
        },
        {
            'cells' => [
                {
                    'type'  => 'head',
                    'value' => 'Minimum'
                },
                {
                    'type'  => 'head',
                    'value' => 'Average'
                },
                {
                    'type'  => 'head',
                    'value' => 'Maximum'
                },
                {
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
                    'value' => 'new'
                },
                {
                    'query' => '(Status = \'new\')',
                    'type'  => 'value',
                    'value' => 10
                },
                {
                    'query' => '(Status = \'new\')',
                    'type'  => 'value',
                    'value' => 25
                },
                {
                    'query' => '(Status = \'new\')',
                    'type'  => 'value',
                    'value' => 40
                },
                {
                    'query' => '(Status = \'new\')',
                    'type'  => 'value',
                    'value' => 50
                }
            ],
            'even' => 1
        },
        {
            'cells' => [
                {
                    'type'  => 'label',
                    'value' => 'open'
                },
                {
                    'query' => '(Status = \'open\')',
                    'type'  => 'value',
                    'value' => 15
                },
                {
                    'query' => '(Status = \'open\')',
                    'type'  => 'value',
                    'value' => 15
                },
                {
                    'query' => '(Status = \'open\')',
                    'type'  => 'value',
                    'value' => 15
                },
                {
                    'query' => '(Status = \'open\')',
                    'type'  => 'value',
                    'value' => 15
                }
            ],
            'even' => 0
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
                    'value' => 25
                },
                {
                    'type'  => 'value',
                    'value' => 40
                },
                {
                    'type'  => 'value',
                    'value' => 55
                },
                {
                    'type'  => 'value',
                    'value' => 65
                }
            ],
            'even' => 1
        }
    ],

};
my %table = $report->FormatTable(%columns);
is_deeply( \%table, $expected, "numeric custom field table" );

done_testing;

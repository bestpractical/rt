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

my $expected = {
    'thead' => [
        {
            'cells' => [
                {
                    'type'  => 'head',
                    'value' => 'Creator'
                },
                {
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

# Charts for non-SuperUsers: RT::Report::Transactions::SetupGroupings runs a
# helper query to filter transactions by rights. The ACL joins it adds make
# that query SELECT DISTINCT, so the default sort inherited from
# RT::Transactions::_Init must be cleared: Pg and Oracle reject ORDER BY
# columns that are not in the select list of a DISTINCT query.
my $staff = RT::Test->load_or_create_user( Name => 'staff', Password => 'password' );
ok( $staff->id, 'created staff user' );
ok( RT::Test->set_rights(
        {   Principal => 'Requestor',
            Object    => RT::Test->load_or_create_queue( Name => 'General' ),
            Right     => [qw(ShowTicket ShowTicketComments)],
        },
    ),
    'granted ShowTicket/ShowTicketComments to Requestor role'
);

my $staff_ticket = RT::Test->create_ticket(
    Queue     => 'General',
    Subject   => 'staff visible',
    Requestor => $staff->Name,
);
$staff_ticket->Comment( Content => 'staff visible comment', TimeTaken => 10 );

my $staff_user = RT::CurrentUser->new($staff);
ok( !$staff_user->HasRight( Right => 'SuperUser', Object => RT->System ), 'staff is not a SuperUser' );

$report  = RT::Report::Transactions->new($staff_user);
%columns = $report->SetupGroupings(
    Query    => q{Type = 'Create' OR Type = 'Comment'},
    GroupBy  => ['Creator'],
    Function => ['COUNT'],
);
$report->SortEntries;
%table = $report->FormatTable(%columns);

is( scalar @{ $table{tbody} }, 1, 'one row for non-SuperUser' );
is( $table{tbody}[0]{cells}[0]{value}, 'RT_System', 'row is grouped by creator' );
is( $table{tbody}[0]{cells}[1]{value}, 2, 'only transactions the staff user can see are counted' );

done_testing;

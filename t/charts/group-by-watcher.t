use strict;
use warnings;

use RT::Test tests => undef;
use RT::Ticket;

my $q = RT::Test->load_or_create_queue( Name => 'General' );
ok $q && $q->id, 'loaded or created queue';
my $queue = $q->Name;

my $user_cf = RT::CustomField->new( RT->SystemUser );
my ( $ret, $msg ) = $user_cf->Create(
    Name       => 'Department',
    Type       => 'Freeform',
    LookupType => RT::User->CustomFieldLookupType,
);
ok( $ret, $msg );
( $ret, $msg ) = $user_cf->AddToObject( RT::User->new( RT->SystemUser ) );
ok( $ret, $msg );

my $user_only_cf = RT::CustomField->new( RT->SystemUser );
( $ret, $msg ) = $user_only_cf->Create(
    Name       => 'Manager',
    Type       => 'Freeform',
    LookupType => RT::User->CustomFieldLookupType,
);
ok( $ret, $msg );
( $ret, $msg ) = $user_only_cf->AddToObject( RT::User->new( RT->SystemUser ) );
ok( $ret, $msg );


my $group_cf = RT::CustomField->new( RT->SystemUser );
( $ret, $msg ) = $group_cf->Create(
    Name       => 'Department',
    Type       => 'Freeform',
    LookupType => RT::Group->CustomFieldLookupType,
);
ok( $ret, $msg );

( $ret, $msg ) = $group_cf->AddToObject( RT::Group->new( RT->SystemUser ) );
ok( $ret, $msg );

my $root = RT::Test->load_or_create_user( Name => 'root' );
( $ret, $msg ) = $root->AddCustomFieldValue( Field => 'Department', Value => 'Research' );
ok( $ret, $msg );

my $alice = RT::Test->load_or_create_user( Name => 'alice', EmailAddress => 'alice@localhost' );
( $ret, $msg ) = $alice->AddCustomFieldValue( Field => 'Department', Value => 'Sales' );
ok( $ret, $msg );

( $ret, $msg ) = $alice->AddCustomFieldValue( Field => 'Manager', Value => 'root' );
ok( $ret, $msg );

my $engineers = RT::Test->load_or_create_group('Enginners');
( $ret, $msg ) = $engineers->AddCustomFieldValue( Field => 'Department', Value => 'Research' );
ok( $ret, $msg );

my $sales = RT::Test->load_or_create_group('Sales');
( $ret, $msg ) = $sales->AddCustomFieldValue( Field => 'Department', Value => 'Sales' );
ok( $ret, $msg );

my $bob = RT::Test->load_or_create_user( Name => 'bob', EmailAddress => 'bob@localhost' );
( $ret, $msg ) = $engineers->AddMember( $bob->Id );
ok( $ret, $msg );

my @tickets = RT::Test->create_tickets(
    {},
    { Subject => 't1', Status => 'new', Requestor => [ $engineers->Id, 'root' ], TimeWorked => 5 },
    { Subject => 't2', Status => 'new', Requestor => 'alice',                    TimeWorked => 0, },
    { Subject => 't3', Status => 'new', Requestor => $sales->Id,                 TimeWorked => 20 },
    { Subject => 't2', Status => 'new', Requestor => 'bob',                      TimeWorked => 0, },
    { Subject => 't5', Status => 'new' },
);

use_ok 'RT::Report::Tickets';

{
    my $report  = RT::Report::Tickets->new( RT->SystemUser );
    my %columns = $report->SetupGroupings(
        Query    => 'Queue = ' . $q->id,
        GroupBy  => ["Requestor.Name"],
        Function => ['COUNT'],
    );
    $report->SortEntries;

    my $expected = {
        'thead' => [
            {
                'cells' => [
                    {
                        'type'  => 'head',
                        'value' => 'Requestor Name'
                    },
                    {
                        'type'    => 'head',
                        'value'   => 'Ticket count',
                        'rowspan' => 1,
                        'color'   => '66cc66'
                    }
                ]
            }
        ],
        'tbody' => [
            {
                'cells' => [
                    {
                        'type'  => 'label',
                        'value' => '(no value)'
                    },
                    {
                        'query' => '(Requestor.Name SHALLOW IS NULL OR Requestor IS NULL)',
                        'type'  => 'value',
                        'value' => '1'
                    }
                ],
                'even' => 1
            },
            {
                'cells' => [
                    {
                        'type'  => 'label',
                        'value' => 'Group: Enginners'
                    },
                    {
                        'query' => '(Requestor.Name SHALLOW = \'Enginners\')',
                        'type'  => 'value',
                        'value' => '1'
                    }
                ],
                'even' => 0
            },
            {
                'cells' => [
                    {
                        'type'  => 'label',
                        'value' => 'Group: Sales'
                    },
                    {
                        'query' => '(Requestor.Name SHALLOW = \'Sales\')',
                        'type'  => 'value',
                        'value' => '1'
                    }
                ],
                'even' => 1
            },
            {
                'cells' => [
                    {
                        'type'  => 'label',
                        'value' => 'alice'
                    },
                    {
                        'query' => '(Requestor.Name SHALLOW = \'alice\')',
                        'type'  => 'value',
                        'value' => '1'
                    }
                ],
                'even' => 0
            },
            {
                'cells' => [
                    {
                        'type'  => 'label',
                        'value' => 'bob'
                    },
                    {
                        'query' => '(Requestor.Name SHALLOW = \'bob\')',
                        'type'  => 'value',
                        'value' => '1'
                    }
                ],
                'even' => 1
            },
            {
                'cells' => [
                    {
                        'type'  => 'label',
                        'value' => 'root'
                    },
                    {
                        'query' => '(Requestor.Name SHALLOW = \'root\')',
                        'type'  => 'value',
                        'value' => '1'
                    }
                ],
                'even' => 0
            }
        ],


        'tfoot' => [],
    };

    my %table = $report->FormatTable(%columns);
    is_deeply( \%table, $expected, "group by Requestor.Name table" );
}


{
    my $report  = RT::Report::Tickets->new( RT->SystemUser );
    my %columns = $report->SetupGroupings(
        Query    => 'Queue = ' . $q->id,
        GroupBy  => ["Requestor.EmailAddress"],
        Function => ['COUNT'],
    );
    $report->SortEntries;

    my $expected = {
        'thead' => [
            {
                'cells' => [
                    {
                        'type'  => 'head',
                        'value' => 'Requestor EmailAddress'
                    },
                    {
                        'color'   => '66cc66',
                        'rowspan' => 1,
                        'type'    => 'head',
                        'value'   => 'Ticket count'
                    }
                ]
            }
        ],
        'tbody' => [
            {
                'cells' => [
                    {
                        'type'  => 'label',
                        'value' => '(no value)'
                    },
                    {
                        'query' => '(Requestor.EmailAddress SHALLOW IS NULL OR Requestor IS NULL)',
                        'type'  => 'value',
                        'value' => '3'
                    }
                ],
                'even' => 1
            },
            {
                'cells' => [
                    {
                        'type'  => 'label',
                        'value' => 'alice@localhost'
                    },
                    {
                        'query' => '(Requestor.EmailAddress SHALLOW = \'alice@localhost\')',
                        'type'  => 'value',
                        'value' => '1'
                    }
                ],
                'even' => 0
            },
            {
                'cells' => [
                    {
                        'type'  => 'label',
                        'value' => 'bob@localhost'
                    },
                    {
                        'query' => '(Requestor.EmailAddress SHALLOW = \'bob@localhost\')',
                        'type'  => 'value',
                        'value' => '1'
                    }
                ],
                'even' => 1
            },
            {
                'cells' => [
                    {
                        'type'  => 'label',
                        'value' => 'root@localhost'
                    },
                    {
                        'query' => '(Requestor.EmailAddress SHALLOW = \'root@localhost\')',
                        'type'  => 'value',
                        'value' => '1'
                    }
                ],
                'even' => 0
            }
        ],

        'tfoot' => [],

    };


    my %table = $report->FormatTable(%columns);
    is_deeply( \%table, $expected, "group by Requestor.EmailAddress table" );
}


{
    my $report  = RT::Report::Tickets->new( RT->SystemUser );
    my %columns = $report->SetupGroupings(
        Query    => 'Queue = ' . $q->id,
        GroupBy  => ["Requestor.CustomField.{Department}"],
        Function => ['COUNT'],
    );
    $report->SortEntries;

    my $expected = {
        'thead' => [
            {
                'cells' => [
                    {
                        'type'  => 'head',
                        'value' => 'Requestor CustomField.{Department}'
                    },
                    {
                        'rowspan' => 1,
                        'type'    => 'head',
                        'value'   => 'Ticket count',
                        'color'   => '66cc66'
                    }
                ]
            }
        ],
        'tbody' => [
            {
                'cells' => [
                    {
                        'type'  => 'label',
                        'value' => '(no value)'
                    },
                    {
                        'query' => '(Requestor.CustomField.{Department} SHALLOW IS NULL OR Requestor IS NULL)',
                        'type'  => 'value',
                        'value' => '2'
                    }
                ],
                'even' => 1
            },
            {
                'cells' => [
                    {
                        'type'  => 'label',
                        'value' => 'Research'
                    },
                    {
                        'query' => '(Requestor.CustomField.{Department} SHALLOW = \'Research\')',
                        'type'  => 'value',
                        'value' => '1'
                    }
                ],
                'even' => 0
            },
            {
                'cells' => [
                    {
                        'type'  => 'label',
                        'value' => 'Sales'
                    },
                    {
                        'query' => '(Requestor.CustomField.{Department} SHALLOW = \'Sales\')',
                        'type'  => 'value',
                        'value' => '2'
                    }
                ],
                'even' => 1
            }
        ],

        'tfoot' => [],
    };

    my %table = $report->FormatTable(%columns);
    is_deeply( \%table, $expected, "group by Requestor.CustomField.{Department} table" );
}

{
    my $report  = RT::Report::Tickets->new( RT->SystemUser );
    my %columns = $report->SetupGroupings(
        Query    => 'Queue = ' . $q->id,
        GroupBy  => ["Requestor.CustomField.{Manager}"],
        Function => ['COUNT'],
    );
    $report->SortEntries;

    my $expected = {
        'thead' => [
            {
                'cells' => [
                    {
                        'type'  => 'head',
                        'value' => 'Requestor CustomField.{Manager}'
                    },
                    {
                        'rowspan' => 1,
                        'type'    => 'head',
                        'value'   => 'Ticket count',
                        'color'   => '66cc66'
                    }
                ]
            }
        ],
        'tbody' => [
            {
                'cells' => [
                    {
                        'type'  => 'label',
                        'value' => '(no value)'
                    },
                    {
                        'query' => '(Requestor.CustomField.{Manager} SHALLOW IS NULL OR Requestor IS NULL)',
                        'type'  => 'value',
                        'value' => '4'
                    }
                ],
                'even' => 1
            },
            {
                'cells' => [
                    {
                        'type'  => 'label',
                        'value' => 'root'
                    },
                    {
                        'query' => '(Requestor.CustomField.{Manager} SHALLOW = \'root\')',
                        'type'  => 'value',
                        'value' => '1'
                    }
                ],
                'even' => 0
            },
        ],
        'tfoot' => [],
    };

    my %table = $report->FormatTable(%columns);
    is_deeply( \%table, $expected, "group by Requestor.CustomField.{Manager} table" );
}


{
    my $report  = RT::Report::Tickets->new( RT->SystemUser );
    my %columns = $report->SetupGroupings(
        Query    => 'Queue = ' . $q->id,
        GroupBy  => ["Requestor.CustomField.{Department}"],
        Function => ['ALL(TimeWorked)'],
    );
    $report->SortEntries;

    my $expected = {
        'thead' => [
            {
                'cells' => [
                    {
                        'rowspan' => 2,
                        'type'    => 'head',
                        'value'   => 'Requestor CustomField.{Department}'
                    },
                    {
                        'colspan' => 4,
                        'type'    => 'head',
                        'value'   => 'Summary of time worked'
                    }
                ]
            },
            {
                'cells' => [
                    {
                        'color' => '66cc66',
                        'type'  => 'head',
                        'value' => 'Minimum'
                    },
                    {
                        'color' => 'ff6666',
                        'type'  => 'head',
                        'value' => 'Average'
                    },
                    {
                        'color' => 'ffcc66',
                        'type'  => 'head',
                        'value' => 'Maximum'
                    },
                    {
                        'color' => '663399',
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
                        'value' => '(no value)'
                    },
                    {
                        'query' => 'id=4 OR id=5',
                        'type'  => 'value',
                        'value' => '0s'
                    },
                    {
                        'query' => 'id=4 OR id=5',
                        'type'  => 'value',
                        'value' => '0s'
                    },
                    {
                        'query' => 'id=4 OR id=5',
                        'type'  => 'value',
                        'value' => '0s'
                    },
                    {
                        'query' => 'id=4 OR id=5',
                        'type'  => 'value',
                        'value' => '0s'
                    }
                ],
                'even' => 1
            },
            {
                'cells' => [
                    {
                        'type'  => 'label',
                        'value' => 'Research'
                    },
                    {
                        'query' => 'id=1',
                        'type'  => 'value',
                        'value' => '5m'
                    },
                    {
                        'query' => 'id=1',
                        'type'  => 'value',
                        'value' => '5m'
                    },
                    {
                        'query' => 'id=1',
                        'type'  => 'value',
                        'value' => '5m'
                    },
                    {
                        'query' => 'id=1',
                        'type'  => 'value',
                        'value' => '5m'
                    }
                ],
                'even' => 0
            },
            {
                'cells' => [
                    {
                        'type'  => 'label',
                        'value' => 'Sales'
                    },
                    {
                        'query' => 'id=2 OR id=3',
                        'type'  => 'value',
                        'value' => '0s'
                    },
                    {
                        'query' => 'id=2 OR id=3',
                        'type'  => 'value',
                        'value' => '10m'
                    },
                    {
                        'query' => 'id=2 OR id=3',
                        'type'  => 'value',
                        'value' => '20m'
                    },
                    {
                        'query' => 'id=2 OR id=3',
                        'type'  => 'value',
                        'value' => '20m'
                    }
                ],
                'even' => 1
            }
        ],

        'tfoot' => [],
    };

    my %table = $report->FormatTable(%columns);
    is_deeply( \%table, $expected, "Time worked group by Requestor.CustomField.{Department} table" );
}

done_testing;

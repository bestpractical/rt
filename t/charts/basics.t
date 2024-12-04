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
    { Subject => 'o', Status => 'open' },
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

    my $new_cell = [
        { 'value' => 'new', 'type' => 'label' },
        { 'query' => '(Status = \'new\')', 'value' => '1', 'type' => 'value' },
    ];
    my $open_cell = [
        { 'value' => 'open', 'type' => 'label' },
        { 'query' => '(Status = \'open\')', 'value' => '3', 'type' => 'value' }
    ];
    my $resolved_cell = [
        { 'value' => 'resolved', 'type' => 'label' },
        { 'query' => '(Status = \'resolved\')', 'value' => '2', 'type' => 'value' }
    ];

    my $expected = {
        'thead' => [ {
                'cells' => [
                    { 'value' => 'Status', 'type' => 'head' },
                    { 'rowspan' => 1, 'value' => 'Ticket count', 'type' => 'head' },
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
                'cells' => $new_cell,
                'even' => 1
            },
            {
                'cells' => $open_cell,
                'even' => 0
            },
            {
                'cells' => $resolved_cell,
                'even' => 1
            },
        ]
    };

    my %table = $report->FormatTable( %columns );
    is_deeply( \%table, $expected, "basic table" );

    $report->SortEntries( ChartOrderBy => 'label', ChartOrder => 'ASC' );
    %table = $report->FormatTable( %columns );
    is_deeply( \%table, $expected, "basic table sorted by label ASC" );

    $report->SortEntries( ChartOrderBy => 'label', ChartOrder => 'DESC' );
    %table = $report->FormatTable( %columns );
    @{$expected->{'tbody'}} = reverse @{$expected->{'tbody'}};
    is_deeply( \%table, $expected, "basic table sorted by label DESC" );

    $report->SortEntries( ChartOrderBy => 'value', ChartOrder => 'ASC' );
    %table = $report->FormatTable( %columns );
    $expected->{'tbody'} = [
        {
            'cells' => $new_cell,
            'even'  => 1
        },
        {
            'cells' => $resolved_cell,
            'even'  => 0,
        },
        {
            'cells' => $open_cell,
            'even'  => 1
        },
    ];
    is_deeply( \%table, $expected, "basic table sorted by value ASC" );

    $report->SortEntries( ChartOrderBy => 'value', ChartOrder => 'DESC' );
    %table = $report->FormatTable( %columns );
    @{$expected->{'tbody'}} = reverse @{$expected->{'tbody'}};
    is_deeply( \%table, $expected, "basic table sorted by value DESC" );

    $report->SortEntries( ChartOrderBy => 'value', ChartOrder => 'DESC', ChartLimit => 2 );
    %table = $report->FormatTable( %columns );
    pop @{$expected->{'tbody'}};
    $expected->{'tfoot'}[0]{'even'} = 1;
    $expected->{'tfoot'}[0]{'cells'}[1]{'value'} = 5;
    is_deeply( \%table, $expected, "basic table sorted by value DESC with 2 items" );

    $report->_DoSearch; # previous search removed an element
    $report->SortEntries( ChartOrderBy => 'value', ChartOrder => 'DESC', ChartLimit => 2, ChartLimitType => 'Bottom' );
    %table = $report->FormatTable( %columns );
    $expected->{'tbody'} = [
        {
            'cells' => $resolved_cell,
            'even'  => 1,
        },
        {
            'cells' => $new_cell,
            'even'  => 0,
        },
    ];
    $expected->{'tfoot'}[0]{'cells'}[1]{'value'} = 3;
    is_deeply( \%table, $expected, "basic table sorted by value DESC with 2 bottom items" );
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


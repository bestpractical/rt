use strict;
use warnings;

use RT::Test tests => undef;

my $q1 = RT::Test->load_or_create_queue( Name => 'One' );
ok $q1 && $q1->id, 'loaded or created queue';

my $q2 = RT::Test->load_or_create_queue( Name => 'Two' );
ok $q2 && $q2->id, 'loaded or created queue';

my $cf = RT::CustomField->new(RT->SystemUser);
my ($status) = $cf->Create(Name => 'Test', Type => 'Freeform', MaxValues => '1', LookupType => 'RT::Queue');
ok $status, 'CF created';

($status) = $cf->AddToObject($q1);
ok $status, 'CF added to queue One';

($status) = $q1->AddCustomFieldValue(Field => $cf->id, Value => 'QueueCfVal');
ok $status, 'CF value added';

my @tickets = RT::Test->create_tickets(
    {},
    { Queue => $q1->id, Subject => 't1', Status => 'new' },
    { Queue => $q2->id, Subject => 't2', Status => 'new' },
);

use_ok 'RT::Report::Tickets';

{
    my $report = RT::Report::Tickets->new( RT->SystemUser );
    my %columns = $report->SetupGroupings(
        Query    => "QueueCF.Test = 'QueueCfVal'",
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
                { 'value' => 1, 'type' => 'value' },
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
        ]
    };

    my %table = $report->FormatTable( %columns );
    is_deeply( \%table, $expected, "basic table" );
}

done_testing;

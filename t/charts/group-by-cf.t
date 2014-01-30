use strict;
use warnings;

use RT::Test tests => undef;
use RT::Ticket;

my $q = RT::Test->load_or_create_queue( Name => 'General' );
ok $q && $q->id, 'loaded or created queue';
my $queue = $q->Name;

my $cf = RT::CustomField->new(RT->SystemUser);
my ($id,$msg) = $cf->Create(Name => 'Test', Type => 'Freeform', MaxValues => '1', Queue => $q->id);
ok $id, $msg;
my $cfid = $cf->id;


my @tickets = RT::Test->create_tickets(
    {},
    { Subject => 't1', Status => 'new', CustomFields => { Test => 'a' } },
    { Subject => 't2', Status => 'open', CustomFields => { Test => 'b' } },
);

use_ok 'RT::Report::Tickets';

{
    my $report = RT::Report::Tickets->new( RT->SystemUser );
    my %columns = $report->SetupGroupings(
        Query    => 'Queue = '. $q->id,
        GroupBy  => ["CF.{$cfid}"], # TODO: CF.{Name} is not supported at the moment
        Function => ['COUNT'],
    );
    $report->SortEntries;

    my @colors = RT->Config->Get("ChartColors");
    my $expected = {
        'thead' => [ {
                'cells' => [
                    { 'value' => 'Custom field Test', 'type' => 'head' },
                    { 'rowspan' => 1, 'value' => 'Ticket count', 'type' => 'head', 'color' => $colors[0] },
                ],
        } ],
       'tfoot' => [ {
            'cells' => [
                { 'colspan' => 1, 'value' => 'Total', 'type' => 'label' },
                { 'value' => 2, 'type' => 'value' },
            ],
            'even' => 1
        } ],
       'tbody' => [
            {
                'cells' => [
                    { 'value' => 'a', 'type' => 'label' },
                    { 'query' => "(CF.{$cfid} = 'a')", 'value' => '1', 'type' => 'value' },
                ],
                'even' => 1
            },
            {
                'cells' => [
                    { 'value' => 'b', 'type' => 'label' },
                    { 'query' => "(CF.{$cfid} = 'b')", 'value' => '1', 'type' => 'value' },
                ],
                'even' => 0
            },
        ]
    };

    my %table = $report->FormatTable( %columns );
    is_deeply( \%table, $expected, "basic table" );
}

done_testing;

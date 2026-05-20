use strict;
use warnings;

use RT::Test tests => undef;
use Test::Warn;
use RT::Interface::Web; # This gets us HTML::Mason::Commands

{
    my $cf = 2;
    my %args = (
        'GroupingName' => {
            'Value'       => "bar",
            'Value-Magic' => 1
        },
    );

    my ($ret, $grouping) = HTML::Mason::Commands::_ValidateConsistentCustomFieldValues($cf, \%args);

    ok ( $ret, 'No duplicates found');
    is ( $grouping, 'GroupingName', 'Grouping is GroupingName');
}

{
    my $cf = 2;
    my %args = (
        'GroupingName'    => {
            'Value'       => "foo",
            'Value-Magic' => 1
        },
        'AnotherGrouping' => {
            'Value'       => "bar",
            'Value-Magic' => 1
        },
    );

    my ($ret, $grouping);
    warning_like {
        ($ret, $grouping) = HTML::Mason::Commands::_ValidateConsistentCustomFieldValues($cf, \%args);
    } qr/^CF 2 submitted with multiple differing values/i;

    ok ( !$ret, 'Caught duplicate values');
    is ( $grouping, 'AnotherGrouping', 'Defaulted to AnotherGrouping');
}

diag "ProcessObjectCustomFieldUpdates does not mutate the passed Object";
{
    my $cf = RT::Test->load_or_create_custom_field(
        Name  => 'TestCF',
        Queue => 0,
        Type  => 'FreeformSingle',
    );
    ok( $cf->id, 'Created global freeform CF' );

    my ( $ticket1, $ticket2 ) = RT::Test->create_tickets(
        { Queue => 'General' },
        { Subject => 'Child ticket' },
        { Subject => 'Parent ticket' },
    );
    ok( $ticket1->id, 'Created ticket 1' );
    ok( $ticket2->id, 'Created ticket 2' );

    my $ticket1_id = $ticket1->id;
    my $ticket2_id = $ticket2->id;
    my $cf_id      = $cf->id;

    # Only include CF args for ticket2, simulating a form where ticket1 (the
    # child) displays and submits ticket2's (the parent) CF fields. This makes
    # the test deterministic: without the fix, ProcessObjectCustomFieldUpdates
    # always loads ticket2 into the passed Object, mutating it away from ticket1.
    my %ARGS = (
        "Object-RT::Ticket-$ticket2_id-CustomField-$cf_id-Value" => 'value-for-ticket2',
    );

    local $HTML::Mason::Commands::session{CurrentUser} = RT->SystemUser;

    HTML::Mason::Commands::ProcessObjectCustomFieldUpdates(
        Object  => $ticket1,
        ARGSRef => \%ARGS,
    );

    is( $ticket1->id, $ticket1_id,
        'ticket1 object still refers to ticket1 after processing CF args for a different ticket' );

    my $t2 = RT::Ticket->new( RT->SystemUser );
    $t2->Load($ticket2_id);
    is( $t2->FirstCustomFieldValue('TestCF'), 'value-for-ticket2',
        'CF value was set on ticket2' );
}

done_testing;

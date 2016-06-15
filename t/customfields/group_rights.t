use strict;
use warnings;

use RT::Test tests => undef;

# These tests catch a previous issue that resulted in the CF
# canonicalize call failing because an internal cf object lacked
# sufficient context to properly do a rights check.

my $general = RT::Test->load_or_create_queue( Name => 'General' );
my $staff1 = RT::Test->load_or_create_user( EmailAddress => 'staff1@example.com', Name => 'staff1', Timezone => 'America/New_York');
my $staff2 = RT::Test->load_or_create_user( EmailAddress => 'staff2@example.com', Name => 'staff2', Timezone => 'America/New_York');

my $group = RT::Test->load_or_create_group(
    'Staff',
    Members => [$staff1, $staff2],
);

ok( RT::Test->add_rights( { Principal => $group, Object => $general,
    Right => [ qw(ModifyTicket CreateTicket SeeQueue ShowTicket SeeCustomField ModifyCustomField) ] } ));

my $cf_name = 'A Date and Time';
my $cf;
{
    $cf = RT::CustomField->new(RT->SystemUser);
    ok(
        $cf->Create(
            Name       => $cf_name,
            Type       => 'DateTime',
            MaxValues  => 1,
            LookupType => RT::Ticket->CustomFieldLookupType,
        ),
        'create cf date'
    );
    ok( $cf->AddToObject($general), 'date cf apply to queue' );
}

diag "Confirm DateTime CF is properly created for root";
{
    my $ticket = RT::Ticket->new( RT::CurrentUser->new( RT->SystemUser ) );
    my ($id) = $ticket->Create(
        Queue                   => $general->id,
        Subject                 => 'Test',
        'CustomField-'. $cf->id => '2016-05-01 00:00:00',
    );
    my $cf_value = $ticket->CustomFieldValues($cf_name)->First;

    is( $cf_value->Content, '2016-05-01 04:00:00', 'got correct value for datetime' );
}

diag "Confirm DateTime CF is properly created for staff1";
{
    my $ticket = RT::Ticket->new( RT::CurrentUser->new( $staff1 ) );
    my ($id) = $ticket->Create(
        Queue                   => $general->id,
        Subject                 => 'Test',
        'CustomField-'. $cf->id => '2016-05-01 00:00:00',
    );
    my $cf_value = $ticket->CustomFieldValues($cf_name)->First;

    is( $cf_value->Content, '2016-05-01 04:00:00', 'correct value' );

    $ticket = RT::Ticket->new( RT::CurrentUser->new( $staff2 ) );
    $ticket->Load($id);
    is( $ticket->FirstCustomFieldValue($cf_name), '2016-05-01 04:00:00', 'staff2 gets correct value' );
}

done_testing;

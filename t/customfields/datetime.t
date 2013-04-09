use Test::MockTime qw(set_fixed_time restore_time);

use warnings;
use strict;

use RT::Test tests => undef;

RT::Test->set_rights(
    { Principal => 'Everyone', Right => [qw(
        SeeQueue ShowTicket CreateTicket SeeCustomField ModifyCustomField
    )] },
);

my $q = RT::Test->load_or_create_queue( Name => 'General' );
ok $q && $q->id, 'loaded or created a queue';

my $user_m = RT::Test->load_or_create_user( Name => 'moscow', Timezone => 'Europe/Moscow' );
ok $user_m && $user_m->id;

my $user_b = RT::Test->load_or_create_user( Name => 'boston', Timezone => 'America/New_York' );
ok $user_b && $user_b->id;


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
    ok( $cf->AddToObject($q), 'date cf apply to queue' );
}

{
    my $ticket = RT::Ticket->new( RT::CurrentUser->new( $user_m ) );
    my ($id) = $ticket->Create(
        Queue                   => $q->id,
        Subject                 => 'Test',
        'CustomField-'. $cf->id => '2013-02-11 00:00:00',
    );
    my $cf_value = $ticket->CustomFieldValues($cf_name)->First;
    TODO: {
        local $TODO = 'questionable result, should we change?';
        # $Ticket->Created returns UTC, not user's date, but
        # ticket has ->CreatedObj method to get all required
        # transformation
        # No more TODO.
        is( $cf_value->Content, '2013-02-11 00:00:00', 'correct value' );
    }
    is( $cf_value->Content, '2013-02-10 20:00:00', 'correct value' );

    $ticket = RT::Ticket->new( RT::CurrentUser->new( $user_b ) );
    $ticket->Load($id);
    is( $ticket->FirstCustomFieldValue($cf_name), '2013-02-10 20:00:00', 'correct value' );
}

# in moscow it's already Feb 11, so tomorrow is Feb 12
set_fixed_time("2013-02-10T23:10:00Z");
{
    my $ticket = RT::Ticket->new( RT::CurrentUser->new( $user_m ) );
    my ($id) = $ticket->Create(
        Queue                   => $q->id,
        Subject                 => 'Test',
        'CustomField-'. $cf->id => 'tomorrow',
    );
    my $cf_value = $ticket->CustomFieldValues($cf_name)->First;
    is( $cf_value->Content, '2013-02-11 23:10:00', 'correct value' );
}

done_testing();

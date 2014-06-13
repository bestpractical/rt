use Test::MockTime qw(set_fixed_time restore_time);

use warnings;
use strict;

use RT::Test nodata => 1, tests => undef;

RT::Test->set_rights(
    { Principal => 'Everyone', Right => [qw(
        SeeQueue ShowTicket CreateTicket SeeCustomField ModifyCustomField
    )] },
);

my $q = RT::Test->load_or_create_queue( Name => 'General' );
ok $q && $q->id, 'loaded or created a queue';

my $user_m = RT::Test->load_or_create_user( Name => 'moscow', Timezone => 'Europe/Moscow' );
ok $user_m && $user_m->id;
$user_m = RT::CurrentUser->new( $user_m );

my $user_b = RT::Test->load_or_create_user( Name => 'boston', Timezone => 'America/New_York' );
ok $user_b && $user_b->id;
$user_b = RT::CurrentUser->new( $user_b );

my $cf = RT::CustomField->new(RT->SystemUser);
ok(
    $cf->Create(
        Name       => 'TestDate',
        Type       => 'Date',
        MaxValues  => 1,
        LookupType => RT::Ticket->CustomFieldLookupType,
    ),
    'create cf date'
);
ok( $cf->AddToObject($q), 'date cf apply to queue' );
my $cf_name = $cf->Name;

my $ticket = RT::Ticket->new(RT->SystemUser);

ok(
    $ticket->Create(
        Queue                    => $q->id,
        Subject                  => 'Test',
        'CustomField-' . $cf->id => '2010-05-04',
    ),
    'create ticket with cf set to 2010-05-04'
);

is( $ticket->CustomFieldValues->First->Content, '2010-05-04', 'date in db is' );

{

    my $tickets = RT::Tickets->new(RT->SystemUser);
    $tickets->LimitCustomField(
        CUSTOMFIELD => $cf->id,
        OPERATOR    => '=',
        VALUE       => '2010-05-04',
    );
    is( $tickets->Count, 1, 'found the ticket with exact date: 2010-05-04' );

}

{
    my $tickets = RT::Tickets->new(RT->SystemUser);
    $tickets->LimitCustomField(
        CUSTOMFIELD => $cf->id,
        OPERATOR    => '>',
        VALUE       => '2010-05-03',
    );

    is( $tickets->Count, 1, 'found ticket with > 2010-05-03' );
}

{
    my $tickets = RT::Tickets->new(RT->SystemUser);
    $tickets->LimitCustomField(
        CUSTOMFIELD => $cf->id,
        OPERATOR    => '<',
        VALUE       => '2010-05-05',
    );

    is( $tickets->Count, 1, 'found ticket with < 2010-05-05' );
}

{

    my $tickets = RT::Tickets->new(RT->SystemUser);
    $tickets->LimitCustomField(
        CUSTOMFIELD => $cf->id,
        OPERATOR    => '=',
        VALUE       => '2010-05-05',
    );

    is( $tickets->Count, 0, 'did not find the ticket with = 2010-05-05' );
}

{
    my $tickets = RT::Tickets->new(RT->SystemUser);
    $tickets->FromSQL( "'CF.{$cf_name}' = 'May 4 2010'" );
    is( $tickets->Count, 1, 'found the ticket with = May 4 2010' );

    $tickets->FromSQL( "'CF.{$cf_name}' < 'May 4 2010'" );
    is( $tickets->Count, 0, 'did not find the ticket with < May 4 2010' );

    $tickets->FromSQL( "'CF.{$cf_name}' < 'May 5 2010'" );
    is( $tickets->Count, 1, 'found the ticket with < May 5 2010' );

    $tickets->FromSQL( "'CF.{$cf_name}' > 'May 3 2010'" );
    is( $tickets->Count, 1, 'found the ticket with > May 3 2010' );
}


{

    my $tickets = RT::Tickets->new(RT->SystemUser);
    $tickets->LimitCustomField(
        CUSTOMFIELD => $cf->id,
        OPERATOR    => '<',
        VALUE       => '2010-05-03',
    );

    is( $tickets->Count, 0, 'did not find the ticket with < 2010-05-03' );
}

{

    my $tickets = RT::Tickets->new(RT->SystemUser);
    $tickets->LimitCustomField(
        CUSTOMFIELD => $cf->id,
        OPERATOR    => '>',
        VALUE       => '2010-05-05',
    );

    is( $tickets->Count, 0, 'did not find the ticket with > 2010-05-05' );
}

{
    my $tickets = RT::Tickets->new(RT->SystemUser);
    $tickets->LimitCustomField(
        CUSTOMFIELD => $cf->id,
        OPERATOR    => 'IS',
        VALUE       => 'NULL',
    );

    is( $tickets->Count, 0, 'did not find the ticket with date IS NULL' );
}

{
    my $tickets = RT::Tickets->new(RT->SystemUser);
    $tickets->LimitCustomField(
        CUSTOMFIELD => $cf->id,
        OPERATOR    => 'IS NOT',
        VALUE       => 'NULL',
    );

    is( $tickets->Count, 1, 'did find the ticket with date IS NOT NULL' );
}

# relative search by users in different TZs
{
    my $ticket = RT::Ticket->new(RT->SystemUser);
    my ($tid) = $ticket->Create(
        Queue                    => $q->id,
        Subject                  => 'Test',
        'CustomField-' . $cf->id => '2013-02-12',
    );

    set_fixed_time("2013-02-10T23:10:00Z");
    my $tickets = RT::Tickets->new($user_m);
    $tickets->FromSQL("'CustomField.{$cf_name}' = 'tomorrow' AND id = $tid");
    is( $tickets->Count, 1, 'found the ticket' );

    set_fixed_time("2013-02-10T15:10:00Z");
    $tickets = RT::Tickets->new($user_m);
    $tickets->FromSQL("'CustomField.{$cf_name}' = 'tomorrow' AND id = $tid");
    is( $tickets->Count, 0, 'found no tickets' );

    set_fixed_time("2013-02-10T23:10:00Z");
    $tickets = RT::Tickets->new($user_b);
    $tickets->FromSQL("'CustomField.{$cf_name}' = 'tomorrow' AND id = $tid");
    is( $tickets->Count, 0, 'found no tickets' );

    set_fixed_time("2013-02-11T23:10:00Z");
    $tickets = RT::Tickets->new($user_b);
    $tickets->FromSQL("'CustomField.{$cf_name}' = 'tomorrow' AND id = $tid");
    is( $tickets->Count, 1, 'found the tickets' );
}

done_testing;

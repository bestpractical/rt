use Test::MockTime qw(set_fixed_time restore_time);

use warnings;
use strict;

use RT::Test nodata => 1, tests => undef;
RT->Config->Set( 'Timezone' => 'EST5EDT' ); # -04:00

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
        Name       => 'TestDateTime',
        Type       => 'DateTime',
        MaxValues  => 1,
        LookupType => RT::Ticket->CustomFieldLookupType,
    ),
    'create cf datetime'
);
ok( $cf->AddToObject($q), 'date cf apply to queue' );
my $cf_name = $cf->Name;

my $ticket = RT::Ticket->new(RT->SystemUser);

ok(
    $ticket->Create(
        Queue                    => $q->id,
        Subject                  => 'Test',
        'CustomField-' . $cf->id => '2010-05-04 07:00:00',
    ),
    'create ticket with cf set to 2010-05-04 07:00:00( 2010-05-04 11:00:00 with UTC )'
);

is(
    $ticket->CustomFieldValues->First->Content,
    '2010-05-04 11:00:00',
    'date in db is in timezone UTC'
);

{

    my $tickets = RT::Tickets->new(RT->SystemUser);
    $tickets->LimitCustomField(
        CUSTOMFIELD => $cf->id,
        OPERATOR    => '=',
        VALUE       => '2010-05-04 07:00:00',    # this timezone is server
    );

    is( $tickets->Count, 1, 'found the ticket with exact date: 2010-05-04 07:00:00' );
}

{

    # TODO according to the code, if OPERATOR is '=', it means on that day
    # this will test this behavior
    my $tickets = RT::Tickets->new(RT->SystemUser);
    $tickets->LimitCustomField(
        CUSTOMFIELD => $cf->id,
        OPERATOR    => '=',
        VALUE       => '2010-05-04',
    );

    is( $tickets->Count, 1, 'found the ticket with rough date: 2010-05-04' );
}

{

    # TODO according to the code, if OPERATOR is '=', it means on that day
    # this will test this behavior
    my $tickets = RT::Tickets->new(RT->SystemUser);
    $tickets->LimitCustomField(
        CUSTOMFIELD => $cf->id,
        OPERATOR    => '=',
        VALUE       => '2010-05-05',
    );

    is( $tickets->Count, 0, 'did not find the ticket with wrong datetime: 2010-05-05' );
}

{
    my $tickets = RT::Tickets->new(RT->SystemUser);
    $tickets->FromSQL( "'CF.{$cf_name}' = 'May 4 2010 7am'" );
    is( $tickets->Count, 1, 'found the ticket with = May 4 2010 7am' );

    $tickets->FromSQL( "'CF.{$cf_name}' = 'May 4 2010 8am'" );
    is( $tickets->Count, 0, 'did not find the ticket with = May 4 2010 8am' );

    $tickets->FromSQL( "'CF.{$cf_name}' > 'May 3 2010 7am'" );
    is( $tickets->Count, 1, 'found the ticket with > May 3 2010 7am' );

    $tickets->FromSQL( "'CF.{$cf_name}' < 'May 4 2010 8am'" );
    is( $tickets->Count, 1, 'found the ticket with < May 4 2010 8am' );

}


my $tickets = RT::Tickets->new( RT->SystemUser );
$tickets->UnLimit;
while( my $ticket  = $tickets->Next ) {
    $ticket->Delete();
}

{
    ok(
        $ticket->Create(
            Queue                    => $q->id,
            Subject                  => 'Test',
            'CustomField-' . $cf->id => '2010-06-21 17:00:01',
        ),
'create ticket with cf set to 2010-06-21 17:00:01( 2010-06-21 21:00:01 with UTC )'
    );

    my $shanghai = RT::Test->load_or_create_user(
        Name     => 'shanghai',
        Timezone => 'Asia/Shanghai',
    );

    ok(
        $shanghai->PrincipalObj->GrantRight(
            Right  => 'SuperUser',
            Object => $RT::System,
        )
    );

    my $current_user = RT::CurrentUser->new($shanghai);
    my $tickets      = RT::Tickets->new($current_user);
    $tickets->LimitCustomField(
        CUSTOMFIELD => $cf->id,
        OPERATOR    => '=',
        VALUE       => '2010-06-22',
    );
    is( $tickets->Count, 1, 'found the ticket with rough datetime: 2010-06-22' );

    $tickets->UnLimit;
    $tickets->LimitCustomField(
        CUSTOMFIELD => $cf->id,
        OPERATOR    => '>',
        VALUE       => '2010-06-21',
    );
    is( $tickets->Count, 1, 'found the ticket with > 2010-06-21' );

    $tickets->UnLimit;
    $tickets->LimitCustomField(
        CUSTOMFIELD => $cf->id,
        OPERATOR    => '<',
        VALUE       => '2010-06-23',
    );
    is( $tickets->Count, 1, 'found the ticket with < 2010-06-23' );

    $tickets->UnLimit;
    $tickets->LimitCustomField(
        CUSTOMFIELD => $cf->id,
        OPERATOR    => '=',
        VALUE       => '2010-06-22 05:00:01',
    );
    is( $tickets->Count, 1, 'found the ticket with = 2010-06-22 01:00:01' );
}

# set timezone in all places to UTC
{
    RT->SystemUser->UserObj->__Set(Field => 'Timezone', Value => 'UTC')
                                if RT->SystemUser->UserObj->Timezone;
    RT->Config->Set( Timezone => 'UTC' );
}

# search by absolute date with '=', but date only
{
    my $ticket = RT::Ticket->new(RT->SystemUser);
    my ($tid) = $ticket->Create(
        Queue                    => $q->id,
        Subject                  => 'Test',
        'CustomField-' . $cf->id => '2013-02-11 23:14:15',
    );
    is $ticket->FirstCustomFieldValue($cf_name), '2013-02-11 23:14:15';

    my $tickets = RT::Tickets->new($user_m);
    $tickets->FromSQL("'CustomField.{$cf_name}' = '2013-02-11' AND id = $tid");
    is( $tickets->Count, 0);

    $tickets = RT::Tickets->new($user_m);
    $tickets->FromSQL("'CustomField.{$cf_name}' = '2013-02-12' AND id = $tid");
    is( $tickets->Count, 1);

    $tickets = RT::Tickets->new($user_b);
    $tickets->FromSQL("'CustomField.{$cf_name}' = '2013-02-11' AND id = $tid");
    is( $tickets->Count, 1);

    $tickets = RT::Tickets->new($user_b);
    $tickets->FromSQL("'CustomField.{$cf_name}' = '2013-02-12' AND id = $tid");
    is( $tickets->Count, 0);
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

    is( $tickets->Count, 2, 'did find the ticket with date IS NOT NULL' );
}


# search by relative date with '=', but date only
{
    my $ticket = RT::Ticket->new(RT->SystemUser);
    my ($tid) = $ticket->Create(
        Queue                    => $q->id,
        Subject                  => 'Test',
        'CustomField-' . $cf->id => '2013-02-11 23:14:15',
    );
    is $ticket->FirstCustomFieldValue($cf_name), '2013-02-11 23:14:15';

    set_fixed_time("2013-02-10T16:10:00Z");
    my $tickets = RT::Tickets->new($user_m);
    $tickets->FromSQL("'CustomField.{$cf_name}' = 'tomorrow' AND id = $tid");
    is( $tickets->Count, 0);

    set_fixed_time("2013-02-10T23:10:00Z");
    $tickets = RT::Tickets->new($user_m);
    $tickets->FromSQL("'CustomField.{$cf_name}' = 'tomorrow' AND id = $tid");
    is( $tickets->Count, 1);

    set_fixed_time("2013-02-10T23:10:00Z");
    $tickets = RT::Tickets->new($user_b);
    $tickets->FromSQL("'CustomField.{$cf_name}' = 'tomorrow' AND id = $tid");
    is( $tickets->Count, 1);

    set_fixed_time("2013-02-10T02:10:00Z");
    $tickets = RT::Tickets->new($user_b);
    $tickets->FromSQL("'CustomField.{$cf_name}' = 'tomorrow' AND id = $tid");
    is( $tickets->Count, 0);
}

done_testing;

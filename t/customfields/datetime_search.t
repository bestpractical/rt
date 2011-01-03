#!/usr/bin/perl

use warnings;
use strict;

use RT::Test nodata => 1, tests => 14;
RT->Config->Set( 'Timezone' => 'EST5EDT' ); # -04:00

my $q = RT::Queue->new(RT->SystemUser);
ok( $q->Create( Name => 'DateTimeCFTest' . $$ ), 'create queue' );

my $cf = RT::CustomField->new(RT->SystemUser);
ok(
    $cf->Create(
        Name       => 'datetime-' . $$,
        Type       => 'DateTime',
        MaxValues  => 1,
        LookupType => RT::Ticket->CustomFieldLookupType,
    ),
    'create cf datetime'
);
ok( $cf->AddToObject($q), 'date cf apply to queue' );

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

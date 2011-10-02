
use warnings;
use strict;

use RT::Test nodata => 1, tests => 17;

my $q = RT::Queue->new(RT->SystemUser);
ok( $q->Create( Name => 'DateCFTest' . $$ ), 'create queue' );

my $cf = RT::CustomField->new(RT->SystemUser);
ok(
    $cf->Create(
        Name       => 'date-' . $$,
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

$ticket = RT::Ticket->new(RT->SystemUser);

ok(
    $ticket->Create(
        Queue                    => $q->id,
        Subject                  => 'Test',
        'CustomField-' . $cf->id => '2010-05-04 11:34:56',
    ),
    'create ticket with cf set to 2010-05-04 11:34:56'
);

is( $ticket->CustomFieldValues->First->Content,
    '2010-05-04', 'date in db only has date' );


#!/usr/bin/perl

use strict;
use warnings;

use RT::Test tests => 102;

my ( $baseurl, $agent ) = RT::Test->started_ok;
ok( $agent->login, 'log in' );

my $q = RT::Queue->new($RT::SystemUser);
$q->Load('General');
my $ip_cf = RT::CustomField->new($RT::SystemUser);

my ( $val, $msg ) = $ip_cf->Create(
    Name       => 'IP',
    Type       => 'IPAddress',
    LookupType => 'RT::Queue-RT::Ticket'
);
ok( $val, $msg );
my $cf_id = $val;
$ip_cf->AddToObject($q);
use_ok('RT');

my $cf;
diag "load and check basic properties of the IP CF" if $ENV{'TEST_VERBOSE'};
{
    my $cfs = RT::CustomFields->new($RT::SystemUser);
    $cfs->Limit( FIELD => 'Name', VALUE => 'IP' );
    is( $cfs->Count, 1, "found one CF with name 'IP'" );

    $cf = $cfs->First;
    is( $cf->Type,       'IPAddress',            'type check' );
    is( $cf->LookupType, 'RT::Queue-RT::Ticket', 'lookup type check' );
    ok( !$cf->MaxValues, "unlimited number of values" );
    ok( !$cf->Disabled,  "not disabled" );
}

diag "check that CF applies to queue General" if $ENV{'TEST_VERBOSE'};
{
    my $cfs = $q->TicketCustomFields;
    $cfs->Limit( FIELD => 'id', VALUE => $cf->id, ENTRYAGGREGATOR => 'AND' );
    is( $cfs->Count, 1, 'field applies to queue' );
}

my %valid = (
    'abcd:' x 7 . 'abcd' => 'abcd:' x 7 . 'abcd',
    '034:' x 7 . '034'   => '0034:' x 7 . '0034',
    'abcd::'             => 'abcd:' . '0000:' x 6 . '0000',
    '::abcd'             => '0000:' x 7 . 'abcd',
    'abcd::034'          => 'abcd:' . '0000:' x 6 . '0034',
    'abcd::192.168.1.1'  => 'abcd:' . '0000:' x 5 . 'c0a8:0101',
    '::192.168.1.1'      => '0000:' x 6 . 'c0a8:0101',
    '::'                 => '0000:' x 7 . '0000',
);

diag "create a ticket via web and set IP" if $ENV{'TEST_VERBOSE'};
{
    for my $ip ( keys %valid ) {
        ok $agent->goto_create_ticket($q), "go to create ticket";
        my $cf_field = "Object-RT::Ticket--CustomField-$cf_id-Values";
        $agent->submit_form(
            form_name => 'TicketCreate',
            fields    => {
                Subject   => 'test ip',
                $cf_field => $ip,
            }
        );

        $agent->content_contains( $valid{$ip}, "IP on the page" );
        my ($id) = $agent->content =~ /Ticket (\d+) created/;
        ok( $id, "created ticket $id" );

        my $ticket = RT::Ticket->new($RT::SystemUser);
        $ticket->Load($id);
        ok( $ticket->id, 'loaded ticket' );
        is( $ticket->FirstCustomFieldValue('IP'), $valid{$ip},
            'correct value' );

        my $tickets = RT::Tickets->new($RT::SystemUser);
        $tickets->FromSQL("id = $id AND CF.{IP} = '$ip'");
        ok( $tickets->Count, "found tickets" );
    }
}

diag "create a ticket and edit IP field using Edit page"
  if $ENV{'TEST_VERBOSE'};

{
    my $ip = 'abcd::034';

    ok $agent->goto_create_ticket($q), "go to create ticket";
    $agent->submit_form(
        form_name => 'TicketCreate',
        fields    => { Subject => 'test ip', }
    );

    my ($id) = $agent->content =~ /Ticket (\d+) created/;
    ok( $id, "created ticket $id" );
    my $cf_field = "Object-RT::Ticket-$id-CustomField-$cf_id-Values";

    $agent->follow_link_ok( { text => 'Basics', n => "1" },
        "Followed 'Basics' link" );
    $agent->form_name('TicketModify');

    is( $agent->value($cf_field), '', 'IP is empty' );
    $agent->field( $cf_field => $valid{$ip} );
    $agent->click('SubmitTicket');

    $agent->content_contains( $valid{$ip}, "IP on the page" );

    my $ticket = RT::Ticket->new($RT::SystemUser);
    $ticket->Load($id);
    ok( $ticket->id, 'loaded ticket' );
    my $values = $ticket->CustomFieldValues('IP');
    is( $ticket->FirstCustomFieldValue('IP'), $valid{$ip}, 'correct value' );

    diag "set IP with spaces around" if $ENV{'TEST_VERBOSE'};
    my $new_ip    = '::3141';
    my $new_value = '0000:' x 7 . '3141';

    $agent->follow_link_ok( { text => 'Basics', n => "1" },
        "Followed 'Basics' link" );
    $agent->form_name('TicketModify');
    is( $agent->value($cf_field), $valid{$ip}, 'IP is in input box' );
    $agent->field( $cf_field => $new_ip );
    $agent->click('SubmitTicket');

    $agent->content_contains( $new_value, "IP on the page" );

    $ticket = RT::Ticket->new($RT::SystemUser);
    $ticket->Load($id);
    ok( $ticket->id, 'loaded ticket' );
    is( $ticket->FirstCustomFieldValue('IP'), $new_value, 'correct value' );
}

diag "check that we parse correct IPs only" if $ENV{'TEST_VERBOSE'};
{

    my $cf_field = "Object-RT::Ticket--CustomField-$cf_id-Values";
    my @invalid =
      ( 'abcd:', 'efgh', 'abcd:' x 8 . 'abcd', 'abcd::abcd::abcd' );
    for my $invalid (@invalid) {
        ok $agent->goto_create_ticket($q), "go to create ticket";
        $agent->submit_form(
            form_name => 'TicketCreate',
            fields    => {
                Subject   => 'test ip',
                $cf_field => $invalid,
            }
        );

        $agent->content_contains( 'can not be parsed as an IP address',
            'ticket fails to create' );
    }
}

diag "create two tickets with different IPs and check several searches"
  if $ENV{'TEST_VERBOSE'};
{
    ok $agent->goto_create_ticket($q), "go to create ticket";
    my $cf_field = "Object-RT::Ticket--CustomField-$cf_id-Values";
    $agent->submit_form(
        form_name => 'TicketCreate',
        fields    => {
            Subject   => 'test ip',
            $cf_field => 'abcd::',
        }
    );

    my ($id1) = $agent->content =~ /Ticket (\d+) created/;
    ok( $id1, "created first ticket $id1" );

    ok $agent->goto_create_ticket($q), "go to create ticket";
    $agent->submit_form(
        form_name => 'TicketCreate',
        fields    => {
            Subject   => 'test ip',
            $cf_field => 'bbcd::',
        }
    );

    my ($id2) = $agent->content =~ /Ticket (\d+) created/;
    ok( $id2, "created second ticket $id2" );

    my $tickets = RT::Tickets->new($RT::SystemUser);
    $tickets->FromSQL("id = $id1 OR id = $id2");
    is( $tickets->Count, 2, "found both tickets by 'id = x OR y'" );

    # IP
    $tickets = RT::Tickets->new($RT::SystemUser);
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = 'abcd::'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'),
        'abcd' . ':0000' x 7, "correct value" );
    $tickets = RT::Tickets->new($RT::SystemUser);
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = 'bbcd::'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'),
        'bbcd' . ':0000' x 7, "correct value" );

    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} <= 'abcd::'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'),
        'abcd' . ':0000' x 7, "correct value" );
    $tickets = RT::Tickets->new($RT::SystemUser);
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} >= 'bbcd::'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'),
        'bbcd' . ':0000' x 7, "correct value" );

    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} > 'bbcd::'");
    is( $tickets->Count, 0, "no tickets found" );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} < 'abcd::'");
    is( $tickets->Count, 0, "no tickets found" );

    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} < 'bbcd::'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'),
        'abcd' . ':0000' x 7, "correct value" );

    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} > 'abcd::'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'),
        'bbcd' . ':0000' x 7, "correct value" );
}

diag "create a ticket with an IP of abcd:23:: and search for doesn't match 'abcd:23'."
  if $ENV{'TEST_VERBOSE'};
{
    ok $agent->goto_create_ticket($q), "go to create ticket";
    my $cf_field = "Object-RT::Ticket--CustomField-$cf_id-Values";
    $agent->submit_form(
        form_name => 'TicketCreate',
        fields    => {
            Subject   => 'local',
            $cf_field => 'abcd:23::',
        }
    );

    my ($id) = $agent->content =~ /Ticket (\d+) created/;
    ok( $id, "created first ticket $id" );

    my $tickets = RT::Tickets->new($RT::SystemUser);
    $tickets->FromSQL("id=$id AND CF.{IP} NOT LIKE 'abcd:23'");

    SKIP: {
        skip "partical ip parse can causes ambiguity", 1;
        is( $tickets->Count, 0, "should not have found the ticket" );
    }
}


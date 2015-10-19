
use strict;
use warnings;

use RT::Test tests => 158;

my ($baseurl, $agent) =RT::Test->started_ok;
ok( $agent->login, 'log in' );

my $q = RT::Queue->new($RT::SystemUser);
$q->Load('General');
my $ip_cf = RT::CustomField->new($RT::SystemUser);

my ($val,$msg) = $ip_cf->Create(Name => 'IP', Type =>'IPAddressRange', LookupType => 'RT::Queue-RT::Ticket');
ok($val,$msg);
my $cf_id = $val;
$ip_cf->AddToObject($q);
use_ok('RT');

my $cf;
diag "load and check basic properties of the IP CF" if $ENV{'TEST_VERBOSE'};
{
    my $cfs = RT::CustomFields->new( $RT::SystemUser );
    $cfs->Limit( FIELD => 'Name', VALUE => 'IP', CASESENSITIVE => 0 );
    is( $cfs->Count, 1, "found one CF with name 'IP'" );

    $cf = $cfs->First;
    is( $cf->Type, 'IPAddressRange', 'type check' );
    is( $cf->LookupType, 'RT::Queue-RT::Ticket', 'lookup type check' );
    ok( !$cf->MaxValues, "unlimited number of values" );
    ok( !$cf->Disabled, "not disabled" );
}

diag "check that CF applies to queue General" if $ENV{'TEST_VERBOSE'};
{
    my $cfs = $q->TicketCustomFields;
    $cfs->Limit( FIELD => 'id', VALUE => $cf->id, ENTRYAGGREGATOR => 'AND' );
    is( $cfs->Count, 1, 'field applies to queue' );
}

my %valid = (
    'abcd:' x 7 . 'abcd' => 'abcd:' x 7 . 'abcd',
    '034:' x 7 . '034'   => '34:' x 7 . '34',
    'abcd::'             => 'abcd::',
    '::abcd'             => '::abcd',
    'abcd::034'          => 'abcd::34',
    'abcd::192.168.1.1'  => 'abcd::c0a8:101',
    '::192.168.1.1'      => '::c0a8:101',
    '::'                 => '::',
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

        $agent->content_like( qr/$valid{$ip}/, "IP on the page" );
        my ($id) = $agent->content =~ /Ticket (\d+) created/;
        ok( $id, "created ticket $id" );

        my $ticket = RT::Ticket->new($RT::SystemUser);
        $ticket->Load($id);
        ok( $ticket->id, 'loaded ticket' );
        is( $ticket->FirstCustomFieldValue('IP'), $valid{$ip},
            'correct value' );
    }
}

diag "create a ticket via web with CIDR" if $ENV{'TEST_VERBOSE'};
{
    my $val = 'abcd:034::/31';
    ok $agent->goto_create_ticket($q), "go to create ticket";
    my $cf_field = "Object-RT::Ticket--CustomField-$cf_id-Values";
    $agent->submit_form(
        form_name => 'TicketCreate',
        fields    => {
            Subject                                       => 'test ip',
            $cf_field => $val,
        }
    );

    my ($id) = $agent->content =~ /Ticket (\d+) created/;
    ok( $id, "created ticket $id" );

    my $ticket = RT::Ticket->new($RT::SystemUser);
    $ticket->Load($id);
    ok( $ticket->id, 'loaded ticket' );
    is(
        $ticket->FirstCustomFieldValue('IP'),
'abcd:34::-abcd:35:ffff:ffff:ffff:ffff:ffff:ffff',
        'correct value'
    );
}

diag "create a ticket and edit IP field using Edit page" if $ENV{'TEST_VERBOSE'};
{
    my $val = 'abcd' . ':abcd' x 7;
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
    $agent->field( $cf_field => $val );
    $agent->click('SubmitTicket');

    $agent->content_contains( $val, "IP on the page" );

    my $ticket = RT::Ticket->new($RT::SystemUser);
    $ticket->Load($id);
    ok( $ticket->id, 'loaded ticket' );
    is( $ticket->FirstCustomFieldValue('IP'), $val, 'correct value' );

    diag "set IP with spaces around" if $ENV{'TEST_VERBOSE'};
    $agent->follow_link_ok( { text => 'Basics', n => "1" },
        "Followed 'Basics' link" );
    $agent->form_name('TicketModify');
    is( $agent->value($cf_field), $val, 'IP is in input box' );
    $val = 'bbcd' . ':abcd' x 7;
    $agent->field( $cf_field => "   $val   " );
    $agent->click('SubmitTicket');

    $agent->content_contains( $val, "IP on the page" );

    $ticket = RT::Ticket->new($RT::SystemUser);
    $ticket->Load($id);
    ok( $ticket->id, 'loaded ticket' );
    is( $ticket->FirstCustomFieldValue('IP'), $val, 'correct value' );

    diag "replace IP with a range" if $ENV{'TEST_VERBOSE'};
    $agent->follow_link_ok( { text => 'Basics', n => "1" },
        "Followed 'Basics' link" );
    $agent->form_name('TicketModify');
    is( $agent->value($cf_field), $val, 'IP is in input box' );
    $val = 'abcd::' . '-' . 'abcd' . ':ffff' x 7;
    $agent->field( $cf_field => 'abcd::/16' );
    $agent->click('SubmitTicket');

    $agent->content_contains( $val, "IP on the page" );

    $ticket = RT::Ticket->new($RT::SystemUser);
    $ticket->Load($id);
    ok( $ticket->id, 'loaded ticket' );
    is( $ticket->FirstCustomFieldValue('IP'), $val, 'correct value' );

    diag "delete range, add another range using CIDR" if $ENV{'TEST_VERBOSE'};
    $agent->follow_link_ok( { text => 'Basics', n => "1" },
        "Followed 'Basics' link" );
    $agent->form_name('TicketModify');
    is( $agent->value($cf_field), $val, 'IP is in input box' );
    $val = 'bb::' . '-' . 'bbff' . ':ffff' x 7;
    $agent->field( $cf_field => $val );
    $agent->click('SubmitTicket');

    $agent->content_contains( $val, "IP on the page" );

    $ticket = RT::Ticket->new($RT::SystemUser);
    $ticket->Load($id);
    ok( $ticket->id, 'loaded ticket' );
    is( $ticket->FirstCustomFieldValue('IP'), $val, 'correct value' );
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

        $agent->content_like( qr/is not a valid IP address range/,
            'ticket fails to create' );
    }

}

diag "search tickets by IP" if $ENV{'TEST_VERBOSE'};
{
    my $val = 'abcd::/16';
    ok $agent->goto_create_ticket($q), "go to create ticket";
    my $cf_field = "Object-RT::Ticket--CustomField-$cf_id-Values";
    $agent->submit_form(
        form_name => 'TicketCreate',
        fields    => {
            Subject   => 'test ip',
            $cf_field => $val,
        }
    );

    my ($id) = $agent->content =~ /Ticket (\d+) created/;
    ok( $id, "created ticket $id" );

    my $ticket = RT::Ticket->new($RT::SystemUser);
    $ticket->Load($id);
    ok( $ticket->id, 'loaded ticket' );

    my $tickets = RT::Tickets->new($RT::SystemUser);
    $tickets->FromSQL("id = $id AND CF.{IP} = 'abcd::/16'");
    ok( $tickets->Count, "found tickets" );
    is(
        $ticket->FirstCustomFieldValue('IP'),
'abcd::-abcd:ffff:ffff:ffff:ffff:ffff:ffff:ffff',
        'correct value'
    );
}

diag "search tickets by IP range" if $ENV{'TEST_VERBOSE'};
{
    my $val = 'abcd:ef00::/24';
    ok $agent->goto_create_ticket($q), "go to create ticket";
    my $cf_field = "Object-RT::Ticket--CustomField-$cf_id-Values";
    $agent->submit_form(
        form_name => 'TicketCreate',
        fields    => {
            Subject   => 'test ip',
            $cf_field => $val,
        }
    );

    my ($id) = $agent->content =~ /Ticket (\d+) created/;
    ok( $id, "created ticket $id" );

    my $ticket = RT::Ticket->new($RT::SystemUser);
    $ticket->Load($id);
    ok( $ticket->id, 'loaded ticket' );

    my $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL("id = $id AND CF.{IP} =
            'abcd:ef::-abcd:efff:ffff:ffff:ffff:ffff:ffff:ffff'");
    ok( $tickets->Count, "found tickets" );

    is(
        $ticket->FirstCustomFieldValue('IP'),
'abcd:ef00::-abcd:efff:ffff:ffff:ffff:ffff:ffff:ffff',
        'correct value'
    );
}

diag "create two tickets with different IPs and check several searches" if $ENV{'TEST_VERBOSE'};
{
    ok $agent->goto_create_ticket($q), "go to create ticket";
    my $cf_field = "Object-RT::Ticket--CustomField-$cf_id-Values";
    my $first_ip = 'cbcd::';
    my $second_ip = 'cbdd::';
    $agent->submit_form(
        form_name => 'TicketCreate',
        fields    => {
            Subject   => 'test ip',
            $cf_field => $first_ip,
        }
    );

    my ($id1) = $agent->content =~ /Ticket (\d+) created/;
    ok( $id1, "created first ticket $id1" );

    ok $agent->goto_create_ticket($q), "go to create ticket";
    $agent->submit_form(
        form_name => 'TicketCreate',
        fields    => {
            Subject   => 'test ip',
            $cf_field => $second_ip,
        }
    );

    my ($id2) = $agent->content =~ /Ticket (\d+) created/;
    ok( $id2, "created second ticket $id2" );

    my $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL("id = $id1 OR id = $id2");
    is( $tickets->Count, 2, "found both tickets by 'id = x OR y'" );

    # IP
    $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '$first_ip'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'), $first_ip, "correct value" );
    $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '$second_ip'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'), $second_ip, "correct value" );

    # IP/32 - one address
    $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = 'cbcd::/16'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'), $first_ip, "correct value" );
    $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = 'cbdd::/16'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'), $second_ip, "correct value" );

    # IP range
    $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL(
        "(id = $id1 OR id = $id2) AND CF.{IP} = '$first_ip-cbcf::'"
    );
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'), $first_ip, "correct value" );
    $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL(
        "(id = $id1 OR id = $id2) AND CF.{IP} = '$second_ip-cbdf::'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'), $second_ip, "correct value" );

    # IP range, with start IP greater than end
    $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} =
            'cbcf::-$first_ip'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'), $first_ip,, "correct value" );
    $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = 'cbdf::-$second_ip'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'), $second_ip, "correct value" );

    # CIDR/12
    $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = 'cbcd::/12'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'), $first_ip, "correct value" );
    $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = 'cbdd::/12'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'), $second_ip, "correct value" );

    # IP is not in CIDR/24
    $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} != 'cbcd::/12'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'), $second_ip,, "correct value" );
    $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} != 'cbdd::/12'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'), $first_ip, "correct value" );

    # CIDR or CIDR
    $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND "
        ."(CF.{IP} = 'cbcd::/12' OR CF.{IP} = 'cbdd::/12')");
    is( $tickets->Count, 2, "found both tickets" );
}

diag "create two tickets with different IP ranges and check several searches" if $ENV{'TEST_VERBOSE'};
{
    ok $agent->goto_create_ticket($q), "go to create ticket";
    my $cf_field = "Object-RT::Ticket--CustomField-$cf_id-Values";
    $agent->submit_form(
        form_name => 'TicketCreate',
        fields    => {
            Subject   => 'test ip',
            $cf_field => 'ddcd::/16',
        }
    );

    my ($id1) = $agent->content =~ /Ticket (\d+) created/;
    ok( $id1, "created first ticket $id1" );

    ok $agent->goto_create_ticket($q), "go to create ticket";
    $agent->submit_form(
        form_name => 'TicketCreate',
        fields    => {
            Subject   => 'test ip',
            $cf_field => 'edcd::/16',
        }
    );

    my ($id2) = $agent->content =~ /Ticket (\d+) created/;
    ok( $id2, "created ticket $id2" );

    my $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL("id = $id1 OR id = $id2");
    is( $tickets->Count, 2, "found both tickets by 'id = x OR y'" );

    # IP
    $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = 'ddcd::'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->id, $id1, "correct value" );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = 'ddcd:abcd::'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->id, $id1, "correct value" );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = 'ddcd:ffff::'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->id, $id1, "correct value" );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = 'edcd::abcd'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->id, $id2, "correct value" );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = 'edcd::ffff'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->id, $id2, "correct value" );
    $tickets->FromSQL(
"(id = $id1 OR id = $id2) AND CF.{IP} = 'edcd:ffff:ffff:ffff:ffff:ffff:ffff:ffff'"
    );
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->id, $id2, "correct value" );

    # IP/32 - one address
    $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = 'ddcd::/32'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->id, $id1, "correct value" );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = 'edcd::/32'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->id, $id2, "correct value" );

    # IP range, lower than both
    $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = 'abcd::/32'");
    is( $tickets->Count, 0, "didn't finnd ticket" ) or diag "but found ". $tickets->First->id;

    # IP range, intersect with the first range
    $tickets->FromSQL(
        "(id = $id1 OR id = $id2) AND CF.{IP} = 'ddcc::-ddcd:ab::'"
    );
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->id, $id1, "correct value" );

    # IP range, equal to the first range
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = 'ddcd::/16'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->id, $id1, "correct value" );

    # IP range, lay inside the first range
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = 'ddcd:ab::'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->id, $id1, "correct value" );

    # IP range, intersect with the ranges
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = 'ddcc::-edcd:ab::'");
    is( $tickets->Count, 2, "found both tickets" );

    # IP range, equal to range from the starting IP of the first ticket to the ending IP of the second
    $tickets->FromSQL(
        "(id = $id1 OR id = $id2) AND CF.{IP} = 'ddcd::-edcd:ffff:ffff:ffff:ffff:ffff:ffff:ffff'"
    );
    is( $tickets->Count, 2, "found both tickets" );

    # IP range, has the both ranges inside it
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = 'd000::/2'");
    is( $tickets->Count, 2, "found both tickets" );

    # IP range, greater than both
    $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = 'ffff::/16'");
    is( $tickets->Count, 0, "didn't find ticket" ) or diag "but found ". $tickets->First->id;
}



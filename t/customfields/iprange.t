
use strict;
use warnings;

use RT::Test tests => 133;

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

diag "create a ticket via web and set IP" if $ENV{'TEST_VERBOSE'};
{
    my $val = '192.168.20.1';
    ok $agent->goto_create_ticket($q), "go to create ticket";
    my $cf_field = "Object-RT::Ticket--CustomField-$cf_id-Values";
    $agent->submit_form(
        form_name => 'TicketCreate',
        fields    => {
            Subject                                       => 'test ip',
            $cf_field => $val,
        },
        button => 'SubmitTicket',
    );

    $agent->content_like( qr/\Q$val/, "IP on the page" );
    my ($id) = $agent->content =~ /Ticket (\d+) created/;
    ok( $id, "created ticket $id" );

    my $ticket = RT::Ticket->new($RT::SystemUser);
    $ticket->Load($id);
    ok( $ticket->id, 'loaded ticket' );
    is( $ticket->FirstCustomFieldValue('IP'), $val, 'correct value' );
}

diag "create a ticket via web with CIDR" if $ENV{'TEST_VERBOSE'};
{
    my $val = '172.16.20/31';
    ok $agent->goto_create_ticket($q), "go to create ticket";
    my $cf_field = "Object-RT::Ticket--CustomField-$cf_id-Values";
    $agent->submit_form(
        form_name => 'TicketCreate',
        fields    => {
            Subject                                       => 'test ip',
            $cf_field => $val,
        },
        button => 'SubmitTicket',
    );

    my ($id) = $agent->content =~ /Ticket (\d+) created/;
    ok( $id, "created ticket $id" );

    my $ticket = RT::Ticket->new($RT::SystemUser);
    $ticket->Load($id);
    ok( $ticket->id, 'loaded ticket' );
    is( $ticket->FirstCustomFieldValue('IP'), '172.16.20.0-172.16.20.1', 'correct value' );
}

diag "create a ticket and edit IP field using Edit page" if $ENV{'TEST_VERBOSE'};
{
    my $val = '172.16.0.1';
    ok $agent->goto_create_ticket($q), "go to create ticket";
    $agent->submit_form(
        form_name => 'TicketCreate',
        fields    => { Subject => 'test ip', },
        button => 'SubmitTicket',
    );

    my ($id) = $agent->content =~ /Ticket (\d+) created/;
    ok( $id, "created ticket $id" );
    my $cf_field = "Object-RT::Ticket-$id-CustomField-$cf_id-Values";

    $agent->follow_link_ok( { text => 'Basics', n => "1" },
        "Followed 'Basics' link" );
    $agent->form_name('TicketModify');

    like( $agent->value($cf_field), qr/^\s*$/, 'IP is empty' );
    $agent->field( $cf_field => $val );
    $agent->click('SubmitTicket');

    $agent->content_like( qr/\Q$val/, "IP on the page" );

    my $ticket = RT::Ticket->new($RT::SystemUser);
    $ticket->Load($id);
    ok( $ticket->id, 'loaded ticket' );
    is( $ticket->FirstCustomFieldValue('IP'), $val, 'correct value' );

    diag "set IP with spaces around" if $ENV{'TEST_VERBOSE'};
    $val = "  172.16.0.2  \n  ";
    $agent->follow_link_ok( { text => 'Basics', n => "1" },
        "Followed 'Basics' link" );
    $agent->form_name('TicketModify');
    like( $agent->value($cf_field),
        qr/^\s*\Q172.16.0.1\E\s*$/, 'IP is in input box' );
    $agent->field( $cf_field => $val );
    $agent->click('SubmitTicket');

    $agent->content_like( qr/\Q172.16.0.2/, "IP on the page" );

    $ticket = RT::Ticket->new($RT::SystemUser);
    $ticket->Load($id);
    ok( $ticket->id, 'loaded ticket' );
    is( $ticket->FirstCustomFieldValue('IP'), '172.16.0.2', 'correct value' );

    diag "replace IP with a range" if $ENV{'TEST_VERBOSE'};
    $val = '172.16.0.0-172.16.0.255';
    $agent->follow_link_ok( { text => 'Basics', n => "1" },
        "Followed 'Basics' link" );
    $agent->form_name('TicketModify');
    like( $agent->value($cf_field),
        qr/^\s*\Q172.16.0.2\E\s*$/, 'IP is in input box' );
    $agent->field( $cf_field => $val );
    $agent->click('SubmitTicket');

    $agent->content_like( qr/\Q$val/, "IP on the page" );

    $ticket = RT::Ticket->new($RT::SystemUser);
    $ticket->Load($id);
    ok( $ticket->id, 'loaded ticket' );
    is( $ticket->FirstCustomFieldValue('IP'), $val, 'correct value' );

    diag "delete range, add another range using CIDR" if $ENV{'TEST_VERBOSE'};
    $val = '172.16/16';
    $agent->follow_link_ok( { text => 'Basics', n => "1" },
        "Followed 'Basics' link" );
    $agent->form_name('TicketModify');
    is( $agent->value($cf_field),
        '172.16.0.0-172.16.0.255', 'IP is in input box' );
    $agent->field( $cf_field => $val );
    $agent->click('SubmitTicket');

    $agent->content_like( qr/\Q$val/, "IP on the page" );

    $ticket = RT::Ticket->new($RT::SystemUser);
    $ticket->Load($id);
    ok( $ticket->id, 'loaded ticket' );
    is( $ticket->FirstCustomFieldValue('IP'),
        '172.16.0.0-172.16.255.255', 'correct value' );
}

diag "check that we parse correct IPs only" if $ENV{'TEST_VERBOSE'};
{

    my $cf_field = "Object-RT::Ticket--CustomField-$cf_id-Values";
    for my $valid (qw/1.0.0.0 255.255.255.255/) {
        ok $agent->goto_create_ticket($q), "go to create ticket";
        $agent->submit_form(
            form_name => 'TicketCreate',
            fields    => {
                Subject   => 'test ip',
                $cf_field => $valid,
            },
            button => 'SubmitTicket',
        );

        my ($id) = $agent->content =~ /Ticket (\d+) created/;
        ok( $id, "created ticket $id" );
        my $ticket = RT::Ticket->new($RT::SystemUser);
        $ticket->Load($id);
        is( $ticket->id, $id, 'loaded ticket' );

        is( $ticket->FirstCustomFieldValue('IP'), $valid, 'correct value' );
    }

    for my $invalid (qw{255.255.255.256 355.255.255.255 8.13.8/8.13.0/1.0}) {
        ok $agent->goto_create_ticket($q), "go to create ticket";
        $agent->submit_form(
            form_name => 'TicketCreate',
            fields    => {
                Subject   => 'test ip',
                $cf_field => $invalid,
            },
            button => 'SubmitTicket',
        );

        $agent->content_like( qr/is not a valid IP address range/, 'ticket fails to create' );
    }

}

diag "search tickets by IP" if $ENV{'TEST_VERBOSE'};
{
    my $val = '172.16.1/31';
    ok $agent->goto_create_ticket($q), "go to create ticket";
    my $cf_field = "Object-RT::Ticket--CustomField-$cf_id-Values";
    $agent->submit_form(
        form_name => 'TicketCreate',
        fields    => {
            Subject   => 'test ip',
            $cf_field => $val,
        },
        button => 'SubmitTicket',
    );

    my ($id) = $agent->content =~ /Ticket (\d+) created/;
    ok( $id, "created ticket $id" );

    my $ticket = RT::Ticket->new($RT::SystemUser);
    $ticket->Load($id);
    ok( $ticket->id, 'loaded ticket' );

    my $tickets = RT::Tickets->new($RT::SystemUser);
    $tickets->FromSQL("id = $id AND CF.{IP} = '172.16.1.1'");
    ok( $tickets->Count, "found tickets" );

    is( $ticket->FirstCustomFieldValue('IP'),
        '172.16.1.0-172.16.1.1', 'correct value' );
}

diag "search tickets by IP range" if $ENV{'TEST_VERBOSE'};
{
    my $val = '172.16.2/26';
    ok $agent->goto_create_ticket($q), "go to create ticket";
    my $cf_field = "Object-RT::Ticket--CustomField-$cf_id-Values";
    $agent->submit_form(
        form_name => 'TicketCreate',
        fields    => {
            Subject   => 'test ip',
            $cf_field => $val,
        },
        button => 'SubmitTicket',
    );

    my ($id) = $agent->content =~ /Ticket (\d+) created/;
    ok( $id, "created ticket $id" );

    my $ticket = RT::Ticket->new($RT::SystemUser);
    $ticket->Load($id);
    ok( $ticket->id, 'loaded ticket' );

    my $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL("id = $id AND CF.{IP} = '172.16.2.0-172.16.2.255'");
    ok( $tickets->Count, "found tickets" );

    is( $ticket->FirstCustomFieldValue('IP'),
        '172.16.2.0-172.16.2.63', 'correct value' );
}

diag "create two tickets with different IPs and check several searches" if $ENV{'TEST_VERBOSE'};
{
    ok $agent->goto_create_ticket($q), "go to create ticket";
    my $cf_field = "Object-RT::Ticket--CustomField-$cf_id-Values";
    $agent->submit_form(
        form_name => 'TicketCreate',
        fields    => {
            Subject   => 'test ip',
            $cf_field => '192.168.21.10',
        },
        button => 'SubmitTicket',
    );

    my ($id1) = $agent->content =~ /Ticket (\d+) created/;
    ok( $id1, "created first ticket $id1" );

    ok $agent->goto_create_ticket($q), "go to create ticket";
    $agent->submit_form(
        form_name => 'TicketCreate',
        fields    => {
            Subject   => 'test ip',
            $cf_field => '192.168.22.10',
        },
        button => 'SubmitTicket',
    );

    my ($id2) = $agent->content =~ /Ticket (\d+) created/;
    ok( $id2, "created second ticket $id2" );

    my $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL("id = $id1 OR id = $id2");
    is( $tickets->Count, 2, "found both tickets by 'id = x OR y'" );

    # IP
    $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168.21.10'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'), '192.168.21.10', "correct value" );
    $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168.22.10'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'), '192.168.22.10', "correct value" );

    # IP/32 - one address
    $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168.21.10/32'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'), '192.168.21.10', "correct value" );
    $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168.22.10/32'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'), '192.168.22.10', "correct value" );

    # IP range
    $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168.21.0-192.168.21.255'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'), '192.168.21.10', "correct value" );
    $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168.22.0-192.168.22.255'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'), '192.168.22.10', "correct value" );

    # IP range, with start IP greater than end
    $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168.21.255-192.168.21.0'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'), '192.168.21.10', "correct value" );
    $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168.22.255-192.168.22.0'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'), '192.168.22.10', "correct value" );

    # CIDR/24
    $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168.21.0/24'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'), '192.168.21.10', "correct value" );
    $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168.22.0/24'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'), '192.168.22.10', "correct value" );

    # IP is not in CIDR/24
    $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} != '192.168.21.0/24'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'), '192.168.22.10', "correct value" );
    $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} != '192.168.22.0/24'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'), '192.168.21.10', "correct value" );

    # CIDR or CIDR
    $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND "
        ."(CF.{IP} = '192.168.21.0/24' OR CF.{IP} = '192.168.22.0/24')");
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
            $cf_field => '192.168.21.0-192.168.21.127',
        },
        button => 'SubmitTicket'
    );

    my ($id1) = $agent->content =~ /Ticket (\d+) created/;
    ok( $id1, "created first ticket $id1" );

    ok $agent->goto_create_ticket($q), "go to create ticket";
    $agent->submit_form(
        form_name => 'TicketCreate',
        fields    => {
            Subject   => 'test ip',
            $cf_field => '192.168.21.128-192.168.21.255',
        },
        button => 'SubmitTicket'
    );

    my ($id2) = $agent->content =~ /Ticket (\d+) created/;
    ok( $id2, "created ticket $id2" );

    my $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL("id = $id1 OR id = $id2");
    is( $tickets->Count, 2, "found both tickets by 'id = x OR y'" );

    # IP
    $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168.21.0'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->id, $id1, "correct value" );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168.21.64'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->id, $id1, "correct value" );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168.21.127'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->id, $id1, "correct value" );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168.21.128'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->id, $id2, "correct value" );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168.21.191'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->id, $id2, "correct value" );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168.21.255'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->id, $id2, "correct value" );

    # IP/32 - one address
    $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168.21.63/32'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->id, $id1, "correct value" );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168.21.191/32'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->id, $id2, "correct value" );

    # IP range, lower than both
    $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168.20.0-192.168.20.255'");
    is( $tickets->Count, 0, "didn't finnd ticket" ) or diag "but found ". $tickets->First->id;

    # IP range, intersect with the first range
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168.20.0-192.168.21.63'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->id, $id1, "correct value" );

    # IP range, equal to the first range
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168.21.0-192.168.21.127'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->id, $id1, "correct value" );

    # IP range, lay inside the first range
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168.21.31-192.168.21.63'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->id, $id1, "correct value" );

    # IP range, intersect with the ranges
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168.21.31-192.168.21.191'");
    is( $tickets->Count, 2, "found both tickets" );

    # IP range, equal to range from the starting IP of the first ticket to the ending IP of the second
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168.21.0-192.168.21.255'");
    is( $tickets->Count, 2, "found both tickets" );

    # IP range, has the both ranges inside it
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168/16'");
    is( $tickets->Count, 2, "found both tickets" );

    # IP range, greater than both
    $tickets = RT::Tickets->new( $RT::SystemUser );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168.22/24'");
    is( $tickets->Count, 0, "didn't find ticket" ) or diag "but found ". $tickets->First->id;
}


diag "test the operators in search page" if $ENV{'TEST_VERBOSE'};
{
    $agent->get_ok( $baseurl . "/Search/Build.html?Query=Queue='General'" );
    $agent->content_contains('CF.{IP}', 'got CF.{IP}');
    my $form = $agent->form_name('BuildQuery');
    my $op = $form->find_input("CF.{IP}Op");
    ok( $op, "found CF.{IP}Op" );
    is_deeply( [ $op->possible_values ], [ '=', '!=', '<', '>' ], 'op values' );
}


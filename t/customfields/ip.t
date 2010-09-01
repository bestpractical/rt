#!/usr/bin/perl

use strict;
use warnings;

use RT::IR::Test tests => 489;

RT::Test->started_ok;
my $agent = default_agent();

use_ok('RT::IR');

my $cf;
diag "load and check basic properties of the IP CF" if $ENV{'TEST_VERBOSE'};
{
    my $cfs = RT::CustomFields->new( $RT::SystemUser );
    $cfs->Limit( FIELD => 'Name', VALUE => 'IP' );
    is( $cfs->Count, 1, "found one CF with name 'IP'" );

    $cf = $cfs->First;
    is( $cf->Type, 'Freeform', 'type check' );
    is( $cf->LookupType, 'RT::Queue-RT::Ticket', 'lookup type check' );
    ok( !$cf->MaxValues, "unlimited number of values" );
    ok( !$cf->Disabled, "not disabled" );
}

diag "check that CF applies to all RTIR's queues" if $ENV{'TEST_VERBOSE'};
{
    foreach ( 'Incidents', 'Incident Reports', 'Investigations', 'Blocks' ) {
        my $queue = RT::Queue->new( $RT::SystemUser );
        $queue->Load( $_ );
        ok( $queue->id, 'loaded queue '. $_ );
        my $cfs = $queue->TicketCustomFields;
        $cfs->Limit( FIELD => 'id', VALUE => $cf->id, ENTRYAGGREGATOR => 'AND' );
        is( $cfs->Count, 1, 'field applies to queue' );
    }
}
my $rtir_user = RT::CurrentUser->new( rtir_user() );

diag "create a ticket via web and set IP" if $ENV{'TEST_VERBOSE'};
{
    my $i = 0;
    my $incident_id; # block couldn't be created without incident id
    foreach my $queue( 'Incidents', 'Incident Reports', 'Investigations', 'Blocks' ) {
        diag "create a ticket in the '$queue' queue" if $ENV{'TEST_VERBOSE'};

        my $val = '192.168.20.'. ++$i;
        my $id = $agent->create_rtir_ticket_ok(
            $queue,
            {
                Subject => "test ip",
                ( $queue eq 'Blocks' ? ( Incident => $incident_id ) : () ),
            },
            { IP => $val },
        );
        $incident_id = $id if $queue eq 'Incidents';

        $agent->display_ticket( $id);
        $agent->content_like( qr/\Q$val/, "IP on the page" );

        my $ticket = RT::Ticket->new( $RT::SystemUser );
        $ticket->Load( $id );
        ok( $ticket->id, 'loaded ticket' );
        is( $ticket->FirstCustomFieldValue('IP'), $val, 'correct value' );
    }
}

diag "create a ticket via web with IP in message" if $ENV{'TEST_VERBOSE'};
{
    my $i = 0;
    my $incident_id; # block couldn't be created without incident id
    foreach my $queue( 'Incidents', 'Incident Reports', 'Investigations', 'Blocks' ) {
        diag "create a ticket in the '$queue' queue" if $ENV{'TEST_VERBOSE'};

        my $val = '192.168.20.'. ++$i;
        my $id = $agent->create_rtir_ticket_ok(
            $queue,
            {
                Subject => "test ip in message",
                ($queue eq 'Blocks'? (Incident => $incident_id): ()),
                Content => "$val",
            },
        );
        $incident_id = $id if $queue eq 'Incidents';

        $agent->display_ticket( $id);
        $agent->content_like( qr/\Q$val/, "IP on the page" );

        my $ticket = RT::Ticket->new( $RT::SystemUser );
        $ticket->Load( $id );
        ok( $ticket->id, 'loaded ticket' );
        is( $ticket->FirstCustomFieldValue('IP'), $val, 'correct value' );
    }
}

diag "create a ticket via web with CIDR" if $ENV{'TEST_VERBOSE'};
{
    my $i = 0;
    my $incident_id; # block couldn't be created without incident id
    foreach my $queue( 'Incidents', 'Incident Reports', 'Investigations', 'Blocks' ) {
        diag "create a ticket in the '$queue' queue" if $ENV{'TEST_VERBOSE'};

        my $val = '172.16.'. ++$i .'/31'; # add two hosts
        my $id = $agent->create_rtir_ticket_ok(
            $queue,
            {
                Subject => "test ip",
                ($queue eq 'Blocks'? (Incident => $incident_id): ()),
            },
            { IP => $val },
        );
        $incident_id = $id if $queue eq 'Incidents';

        $agent->display_ticket( $id);
        $agent->content_like( qr/172\.16\.$i\.0-172\.16\.$i\.1/, "IP range on the page" );

        my $ticket = RT::Ticket->new( $RT::SystemUser );
        $ticket->Load( $id );
        ok( $ticket->id, 'loaded ticket' );
        my $values = $ticket->CustomFieldValues('IP');
        my %has = map { $_->Content => 1 } @{ $values->ItemsArrayRef };
        ok( $has{ "172.16.$i.0-172.16.$i.1" }, "has value" )
            or diag "but has values ". join ", ", keys %has;
    }
}

diag "create a ticket via web with CIDR in message" if $ENV{'TEST_VERBOSE'};
{
    my $i = 0;
    my $incident_id; # block couldn't be created without incident id
    foreach my $queue( 'Incidents', 'Incident Reports', 'Investigations', 'Blocks' ) {
        diag "create a ticket in the '$queue' queue" if $ENV{'TEST_VERBOSE'};

        my $val = '172.16.'. ++$i .'/31'; # add two hosts
        my $id = $agent->create_rtir_ticket_ok(
            $queue,
            {
                Subject => "test ip in message",
                ($queue eq 'Blocks'? (Incident => $incident_id): ()),
                Content => "$val",
            },
        );
        $incident_id = $id if $queue eq 'Incidents';

        $agent->display_ticket( $id);
        $agent->content_like( qr/172\.16\.$i\.0-172\.16\.$i\.1/, "IP range on the page" );

        my $ticket = RT::Ticket->new( $RT::SystemUser );
        $ticket->Load( $id );
        ok( $ticket->id, 'loaded ticket' );
        my $values = $ticket->CustomFieldValues('IP');
        my %has = map { $_->Content => 1 } @{ $values->ItemsArrayRef };
        ok( $has{ "172.16.$i.0-172.16.$i.1" }, "has value" )
            or diag "but has values ". join ", ", keys %has;
    }
}

diag "create a ticket and edit IP field using Edit page" if $ENV{'TEST_VERBOSE'};
{
    my $i = 0;
    my $incident_id; # block couldn't be created without incident id
    foreach my $queue( 'Incidents', 'Incident Reports', 'Investigations', 'Blocks' ) {
        diag "create a ticket in the '$queue' queue" if $ENV{'TEST_VERBOSE'};

        my $id = $agent->create_rtir_ticket_ok(
            $queue,
            {
                Subject => "test ip in message",
                ($queue eq 'Blocks'? (Incident => $incident_id): ()),
            },
        );
        $incident_id = $id if $queue eq 'Incidents';
        $agent->display_ticket( $id);

        my $field_name = "Object-RT::Ticket-$id-CustomField-". $cf->id ."-Values";

diag "set IP" if $ENV{'TEST_VERBOSE'};
        my $val = '172.16.0.1';
        $agent->follow_link_ok({text => 'Edit', n => "1"}, "Followed 'Edit' link");
        $agent->form_number(3);
        like( $agent->value($field_name), qr/^\s*$/, 'IP is empty' );
        $agent->field( $field_name => $val );
        $agent->click('SaveChanges');

        $agent->content_like( qr/\Q$val/, "IP on the page" );

        my $ticket = RT::Ticket->new( $RT::SystemUser );
        $ticket->Load( $id );
        ok( $ticket->id, 'loaded ticket' );
        my $values = $ticket->CustomFieldValues('IP');
        my %has = map { $_->Content => 1 } @{ $values->ItemsArrayRef };
        is( scalar values %has, 1, "one IP were added");
        ok( $has{ $val }, "has value" )
            or diag "but has values ". join ", ", keys %has;

diag "set IP with spaces around" if $ENV{'TEST_VERBOSE'};
        $val = "  172.16.0.2  \n  ";
        $agent->follow_link_ok({text => 'Edit', n => "1"}, "Followed 'Edit' link");
        $agent->form_number(3);
        like( $agent->value($field_name), qr/^\s*\Q172.16.0.1\E\s*$/, 'IP is in input box' );
        $agent->field( $field_name => $val );
        $agent->click('SaveChanges');

        $agent->content_like( qr/\Q172.16.0.2/, "IP on the page" );

        $ticket = RT::Ticket->new( $RT::SystemUser );
        $ticket->Load( $id );
        ok( $ticket->id, 'loaded ticket' );
        $values = $ticket->CustomFieldValues('IP');
        %has = map { $_->Content => 1 } @{ $values->ItemsArrayRef };
        is( scalar values %has, 1, "one IP were added");
        ok( $has{ '172.16.0.2' }, "has value" )
            or diag "but has values ". join ", ", keys %has;

diag "replace IP with a range" if $ENV{'TEST_VERBOSE'};
        $val = '172.16.0.0-172.16.0.255';
        $agent->follow_link_ok({text => 'Edit', n => "1"}, "Followed 'Edit' link");
        $agent->form_number(3);
        like( $agent->value($field_name), qr/^\s*\Q172.16.0.2\E\s*$/, 'IP is in input box' );
        $agent->field( $field_name => $val );
        $agent->click('SaveChanges');

        $agent->content_like( qr/\Q$val/, "IP on the page" );

        $ticket = RT::Ticket->new( $RT::SystemUser );
        $ticket->Load( $id );
        ok( $ticket->id, 'loaded ticket' );
        $values = $ticket->CustomFieldValues('IP');
        %has = map { $_->Content => 1 } @{ $values->ItemsArrayRef };
        is( scalar values %has, 1, "one IP were added");
        ok( $has{ $val }, "has value" )
            or diag "but has values ". join ", ", keys %has;

diag "delete range, add another range using CIDR" if $ENV{'TEST_VERBOSE'};
        $val = '172.16/16';
        $agent->follow_link_ok({text => 'Edit', n => "1"}, "Followed 'Edit' link");
        $agent->form_number(3);
        like( $agent->value($field_name), qr/^\s*\Q172.16.0.0-172.16.0.255\E\s*$/, 'IP is empty' );
        $agent->field( $field_name => $val );
        $agent->click('SaveChanges');

        $agent->content_like( qr/\Q$val/, "IP on the page" );

        $ticket = RT::Ticket->new( $RT::SystemUser );
        $ticket->Load( $id );
        ok( $ticket->id, 'loaded ticket' );
        $values = $ticket->CustomFieldValues('IP');
        %has = map { $_->Content => 1 } @{ $values->ItemsArrayRef };
        is( scalar values %has, 1, "one IP were added");
        ok( $has{ '172.16.0.0-172.16.255.255' }, "has value" )
            or diag "but has values ". join ", ", keys %has;
    }
}

diag "check that we parse correct IPs only" if $ENV{'TEST_VERBOSE'};
{
    my $id = $agent->create_ir( { Subject => "test ip", Content => '1.0.0.0' } );
    ok($id, "created a ticket");

    my $ticket = RT::Ticket->new( $RT::SystemUser );
    $ticket->Load( $id );
    is( $ticket->id, $id, 'loaded ticket' );

    my %has = ();
    $has{ $_->Content }++ foreach @{ $ticket->CustomFieldValues('IP')->ItemsArrayRef };
    is(scalar values %has, 1, "one IP was added");
    ok($has{'1.0.0.0'}, 'correct value');

    $id = $agent->create_ir( { Subject => "test ip", Content => '255.255.255.255' } );
    ok($id, "created a ticket");

    $ticket = RT::Ticket->new( $RT::SystemUser );
    $ticket->Load( $id );
    is($ticket->id, $id, 'loaded ticket');

    %has = ();
    $has{ $_->Content }++ foreach @{ $ticket->CustomFieldValues('IP')->ItemsArrayRef };
    is(scalar values %has, 1, "one IP was added");
    ok($has{'255.255.255.255'}, 'correct value');

    $id = $agent->create_ir( { Subject => "test ip", Content => '255.255.255.256' } );
    ok($id, "created a ticket");

    $ticket = RT::Ticket->new( $RT::SystemUser );
    $ticket->Load( $id );
    is($ticket->id, $id, 'loaded ticket');
    is($ticket->CustomFieldValues('IP')->Count, 0, "IP wasn't added");

    $id = $agent->create_ir( { Subject => "test ip", Content => '355.255.255.255' } );
    ok($id, "created a ticket");

    $ticket = RT::Ticket->new( $RT::SystemUser );
    $ticket->Load( $id );
    is($ticket->id, $id, 'loaded ticket');
    is($ticket->CustomFieldValues('IP')->Count, 0, "IP wasn't added");

    $id = $agent->create_ir( { Subject => "test ip", Content => '8.13.8/8.13.0/1.0' } );
    ok($id, "created a ticket");

    $ticket = RT::Ticket->new( $RT::SystemUser );
    $ticket->Load( $id );
    is($ticket->id, $id, 'loaded ticket');
    is($ticket->CustomFieldValues('IP')->Count, 0, "IP wasn't added");
}

diag "check that IPs in messages don't add duplicates" if $ENV{'TEST_VERBOSE'};
{
    my $id = $agent->create_ir( {
        Subject => "test ip",
        Content => '192.168.20.2 192.168.20.2 192.168.20.2/32'
    } );
    ok($id, "created first ticket");

    my $ticket = RT::Ticket->new( $RT::SystemUser );
    $ticket->Load( $id );
    ok( $ticket->id, 'loaded ticket' );

    my $values = $ticket->CustomFieldValues('IP');
    my %has;
    $has{ $_->Content }++ foreach @{ $values->ItemsArrayRef };
    is(scalar values %has, 1, "one IP were added");
    ok(!grep( $_ != 1, values %has ), "no duplicated values");
    ok($has{'192.168.20.2'}, "IP is there");
}

diag "check IPs separated by commas and semicolons" if $ENV{'TEST_VERBOSE'};
{
    my $id = $agent->create_ir( {
        Subject => "test ip",
        Content => '64.64.64.64, 32.32.32.32; 16.16.16.16.'
    } );
    ok($id, "created first ticket");

    my $ticket = RT::Ticket->new( $RT::SystemUser );
    $ticket->Load( $id );
    ok( $ticket->id, 'loaded ticket' );

    my $values = $ticket->CustomFieldValues('IP');
    my %has;
    $has{ $_->Content }++ foreach @{ $values->ItemsArrayRef };
    is(scalar values %has, 3, "three IPs were added");
    ok(!grep( $_ != 1, values %has ), "no duplicated values");
    ok($has{'64.64.64.64'}, "IP is there");
    ok($has{'32.32.32.32'}, "IP is there");
    ok($has{'16.16.16.16'}, "IP is there");
}

diag "search tickets by IP" if $ENV{'TEST_VERBOSE'};
{
    my $id = $agent->create_ir( {
        Subject => "test ip",
        Content => '172.16.1/31'
    } );
    ok($id, "created first ticket");

    my $tickets = RT::Tickets->new( $rtir_user );
    $tickets->FromSQL("id = $id AND CF.{IP} = '172.16.1.1'");
    ok( $tickets->Count, "found tickets" );

    my $flag = 1;
    while ( my $ticket = $tickets->Next ) {
        my %has = map { $_->Content => 1 } @{ $ticket->CustomFieldValues('IP')->ItemsArrayRef };
        next if $has{'172.16.1.0-172.16.1.1'};
        $flag = 0;
        ok(0, "ticket #". $ticket->id ." has no IP 172.16.1.1, but should")
            or diag "but has values ". join ", ", keys %has;
        last;
    }
    ok(1, "all tickets has IP 172.16.1.1") if $flag;
}

diag "search tickets by IP range" if $ENV{'TEST_VERBOSE'};
{
    my $id = $agent->create_ir( {
        Subject => "test ip",
        Content => '172.16.2/26'
    } );
    ok($id, "created first ticket");

    my $tickets = RT::Tickets->new( $rtir_user );
    $tickets->FromSQL("id = $id AND CF.{IP} = '172.16.2.0-172.16.2.255'");
    ok( $tickets->Count, "found tickets" );

    my $flag = 1;
    while ( my $ticket = $tickets->Next ) {
        my %has = map { $_->Content => 1 } @{ $ticket->CustomFieldValues('IP')->ItemsArrayRef };
        next if grep /^172\.16\.2\./, keys %has;
        $flag = 0;
        ok(0, "ticket #". $ticket->id ." has no IP from 172.16.2.0-172.16.2.255, but should");
        last;
    }
    ok(1, "all tickets have at least one IP from 172.16.2.0-172.16.2.255") if $flag;
}

diag "create two tickets with different IPs and check several searches" if $ENV{'TEST_VERBOSE'};
{
    my $id1 = $agent->create_ir( { Subject => "test ip" }, { IP => '192.168.21.10' } );
    ok($id1, "created first ticket");
    my $id2 = $agent->create_ir( { Subject => "test ip" }, { IP => '192.168.22.10' } );
    ok($id2, "created second ticket");

    my $tickets = RT::Tickets->new( $rtir_user );
    $tickets->FromSQL("id = $id1 OR id = $id2");
    is( $tickets->Count, 2, "found both tickets by 'id = x OR y'" );

    # IP
    $tickets = RT::Tickets->new( $rtir_user );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168.21.10'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'), '192.168.21.10', "correct value" );
    $tickets = RT::Tickets->new( $rtir_user );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168.22.10'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'), '192.168.22.10', "correct value" );

    # IP/32 - one address
    $tickets = RT::Tickets->new( $rtir_user );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168.21.10/32'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'), '192.168.21.10', "correct value" );
    $tickets = RT::Tickets->new( $rtir_user );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168.22.10/32'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'), '192.168.22.10', "correct value" );

    # IP range
    $tickets = RT::Tickets->new( $rtir_user );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168.21.0-192.168.21.255'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'), '192.168.21.10', "correct value" );
    $tickets = RT::Tickets->new( $rtir_user );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168.22.0-192.168.22.255'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'), '192.168.22.10', "correct value" );

    # IP range, with start IP greater than end
    $tickets = RT::Tickets->new( $rtir_user );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168.21.255-192.168.21.0'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'), '192.168.21.10', "correct value" );
    $tickets = RT::Tickets->new( $rtir_user );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168.22.255-192.168.22.0'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'), '192.168.22.10', "correct value" );

    # CIDR/24
    $tickets = RT::Tickets->new( $rtir_user );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168.21.0/24'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'), '192.168.21.10', "correct value" );
    $tickets = RT::Tickets->new( $rtir_user );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168.22.0/24'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'), '192.168.22.10', "correct value" );

    # IP is not in CIDR/24
    $tickets = RT::Tickets->new( $rtir_user );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} != '192.168.21.0/24'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'), '192.168.22.10', "correct value" );
    $tickets = RT::Tickets->new( $rtir_user );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} != '192.168.22.0/24'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->FirstCustomFieldValue('IP'), '192.168.21.10', "correct value" );

    # CIDR or CIDR
    $tickets = RT::Tickets->new( $rtir_user );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND "
        ."(CF.{IP} = '192.168.21.0/24' OR CF.{IP} = '192.168.22.0/24')");
    is( $tickets->Count, 2, "found both tickets" );
}

diag "create two tickets with different IP ranges and check several searches" if $ENV{'TEST_VERBOSE'};
{
    my $id1 = $agent->create_ir( { Subject => "test ip" }, { IP => '192.168.21.0-192.168.21.127' } );
    ok($id1, "created first ticket");
    my $id2 = $agent->create_ir( { Subject => "test ip" }, { IP => '192.168.21.128-192.168.21.255' } );
    ok($id2, "created second ticket");

    my $tickets = RT::Tickets->new( $rtir_user );
    $tickets->FromSQL("id = $id1 OR id = $id2");
    is( $tickets->Count, 2, "found both tickets by 'id = x OR y'" );

    # IP
    $tickets = RT::Tickets->new( $rtir_user );
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
    $tickets = RT::Tickets->new( $rtir_user );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168.21.63/32'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->id, $id1, "correct value" );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168.21.191/32'");
    is( $tickets->Count, 1, "found one ticket" );
    is( $tickets->First->id, $id2, "correct value" );

    # IP range, lower than both
    $tickets = RT::Tickets->new( $rtir_user );
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
    $tickets = RT::Tickets->new( $rtir_user );
    $tickets->FromSQL("(id = $id1 OR id = $id2) AND CF.{IP} = '192.168.22/24'");
    is( $tickets->Count, 0, "didn't finnd ticket" ) or diag "but found ". $tickets->First->id;
}

diag "merge ticket, IPs should be merged";
{
    my $incident_id = $agent->create_rtir_ticket_ok(
        'Incidents',
        { Subject => "test" },
    );
    my $b1_id = $agent->create_block(
        {
            Subject => "test ip",
            Incident => $incident_id,
        },
        { IP => '172.16.0.1' },
    );
    my $b2_id = $agent->create_block(
        {
            Subject => "test ip",
            Incident => $incident_id,
        },
        { IP => '172.16.0.2' },
    );

    $agent->display_ticket( $b1_id);
    $agent->follow_link_ok({ text => 'Merge' }, "Followed merge link");
    $agent->form_number(3);
    $agent->field('SelectedTicket', $b2_id);
    $agent->submit;
    $agent->ok_and_content_like( qr{Merge Successful}, 'Merge Successful');

    my $ticket = RT::Ticket->new( $RT::SystemUser );
    $ticket->Load( $b1_id );
    ok $ticket->id, 'loaded ticket';
    my $values = $ticket->CustomFieldValues('IP');
    my %has = map { $_->Content => 1 } @{ $values->ItemsArrayRef };
    is( scalar values %has, 2, "both IPs are there");
    ok( $has{ '172.16.0.1' }, "has value" )
        or diag "but has values ". join ", ", keys %has;
    ok( $has{ '172.16.0.2' }, "has value" )
        or diag "but has values ". join ", ", keys %has;
}

diag "merge ticket with the same IP";
{
    my $incident_id = $agent->create_rtir_ticket_ok(
        'Incidents',
        { Subject => "test" },
    );
    my $b1_id = $agent->create_block(
        {
            Subject => "test ip",
            Incident => $incident_id,
        },
        { IP => '172.16.0.1' },
    );
    my $b2_id = $agent->create_block(
        {
            Subject => "test ip",
            Incident => $incident_id,
        },
        { IP => '172.16.0.1' },
    );

    $agent->display_ticket( $b1_id);
    $agent->follow_link_ok({ text => 'Merge' }, "Followed merge link");
    $agent->form_number(3);
    $agent->field('SelectedTicket', $b2_id);
    $agent->submit;
    $agent->ok_and_content_like( qr{Merge Successful}, 'Merge Successful');

    my $ticket = RT::Ticket->new( $RT::SystemUser );
    $ticket->Load( $b1_id );
    ok $ticket->id, 'loaded ticket';
    my $values = $ticket->CustomFieldValues('IP');
    my @has = map $_->Content, @{ $values->ItemsArrayRef };
    is( scalar @has, 1, "only one IP") or diag "values: @has";
    is( $has[0], '172.16.0.1', "has value" );
}


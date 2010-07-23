#!/usr/bin/perl

use strict;
use warnings;

use RT::Test tests => 29;
RT->Config->Set( 'Timezone' => 'US/Eastern' );
my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in as root';
my $root = RT::User->new( $RT::SystemUser );
ok( $root->Load('root'), 'load root user' );

my $cf_name = 'test cf date';

my $cfid;
diag "Create a CF" if $ENV{'TEST_VERBOSE'};
{
    $m->follow_link( text => 'Configuration' );
    $m->title_is(q/RT Administration/, 'admin screen');
    $m->follow_link( text => 'Custom Fields' );
    $m->title_is(q/Select a Custom Field/, 'admin-cf screen');
    $m->follow_link( text => 'Create' );
    $m->submit_form(
        form_name => "ModifyCustomField",
        fields => {
            Name          => $cf_name,
            TypeComposite => 'Date-1',
            LookupType    => 'RT::Queue-RT::Ticket',
        },
    );
    $m->content_like( qr/Object created/, 'created CF sucessfully' );
    $cfid = $m->form_name('ModifyCustomField')->value('id');
    ok $cfid, "found id of the CF in the form, it's #$cfid";
}

diag "apply the CF to General queue" if $ENV{'TEST_VERBOSE'};
my $queue = RT::Test->load_or_create_queue( Name => 'General' );
ok $queue && $queue->id, 'loaded or created queue';

{
    $m->follow_link( text => 'Queues' );
    $m->title_is(q/Admin queues/, 'admin-queues screen');
    $m->follow_link( text => 'General' );
    $m->title_is(q/Editing Configuration for queue General/, 'admin-queue: general');
    $m->follow_link( text => 'Ticket Custom Fields' );
    $m->title_is(q/Edit Custom Fields for General/, 'admin-queue: general cfid');

    $m->form_name('EditCustomFields');
    $m->tick( "AddCustomField" => $cfid );
    $m->click('UpdateCFs');

    $m->content_like( qr/Object created/, 'TCF added to the queue' );
}

diag 'check valid inputs with various timezones in ticket create page' if $ENV{'TEST_VERBOSE'};
{
    my ( $ticket, $id );

    $m->submit_form(
        form_name => "CreateTicketInQueue",
        fields => { Queue => 'General' },
    );
    $m->content_like(qr/Select date/, 'has cf field');
    # Calendar link is added via js, so can't test it as link
    $m->content_like(qr/Calendar/, 'has Calendar');

    $m->submit_form(
        form_name => "TicketCreate",
        fields    => {
            Subject                                       => 'test',
            Content                                       => 'test',
            "Object-RT::Ticket--CustomField-$cfid-Values" => '2010-05-04 08:00:00',
        },
    );
    ok( ($id) = $m->content =~ /Ticket (\d+) created/,
        "created ticket $id" );

    $ticket = RT::Ticket->new( $RT::SystemUser );
    $ticket->Load($id);
    is(
        $ticket->CustomFieldValues($cfid)->First->Content,
        '2010-05-04 12:00:00',
        'date in db is in UTC'
    );

    $m->content_like(qr/test cf date:/, 'has no cf date field on the page');
    $m->content_like(qr/Tue May 04 08:00:00 2010/, 'has cf date value on the page');

    $root->SetTimezone( 'Asia/Shanghai' ); # +08:00
    # interesting that $m->reload doesn't work
    $m->get_ok( $m->uri );
    $m->content_like(qr/Tue May 04 20:00:00 2010/, 'cf date value respects user timezone');

    $m->submit_form(
        form_name => "CreateTicketInQueue",
        fields => { Queue => 'General' },
    );
    $m->submit_form(
        form_name => "TicketCreate",
        fields    => {
            Subject                                       => 'test',
            Content                                       => 'test',
            "Object-RT::Ticket--CustomField-$cfid-Values" => '2010-05-04 08:00:00',
        },
    );
    ok( ($id) = $m->content =~ /Ticket (\d+) created/,
        "created ticket $id" );
    $ticket = RT::Ticket->new( $RT::SystemUser );
    $ticket->Load($id);
    is(
        $ticket->CustomFieldValues($cfid)->First->Content,
        '2010-05-04 00:00:00',
        'date in db is in UTC'
    );

    $m->content_like(qr/test cf date:/, 'has no cf date field on the page');
    $m->content_like(qr/Tue May 04 08:00:00 2010/, 'cf date input respects user timezone');
    $root->SetTimezone( 'US/Eastern' ); # back to -04:00
    $m->get_ok( $m->uri );
    $m->content_like(qr/Mon May 03 20:00:00 2010/, 'cf date value respects user timezone');
}



diag 'check invalid inputs' if $ENV{'TEST_VERBOSE'};
{
    $m->submit_form(
        form_name => "CreateTicketInQueue",
        fields => { Queue => 'General' },
    );
    my $form = $m->form_name("TicketCreate");

    $m->submit_form(
        form_name => "TicketCreate",
        fields    => {
            Subject                                       => 'test',
            Content                                       => 'test',
            "Object-RT::Ticket--CustomField-$cfid-Values" => 'foodate',
        },
    );
    $m->content_like(qr/Ticket \d+ created/, "a ticket is created succesfully");

    $m->content_like(qr/test cf date:/, 'has no cf date field on the page');
    $m->content_unlike(qr/foodate/, 'invalid dates not set');
}


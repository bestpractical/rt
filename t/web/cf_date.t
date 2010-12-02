#!/usr/bin/perl

use strict;
use warnings;

use RT::Test tests => 35;

my ( $baseurl, $m ) = RT::Test->started_ok;
ok $m->login, 'logged in as root';
my $root = RT::User->new(RT->SystemUser);
ok( $root->Load('root'), 'load root user' );

my $cf_name = 'test cf date';

my $cfid;
diag "Create a CF";
{
    $m->follow_link( id => 'tools-config-custom-fields-create');
    $m->submit_form(
        form_name => "ModifyCustomField",
        fields    => {
            Name          => $cf_name,
            TypeComposite => 'Date-1',
            LookupType    => 'RT::Queue-RT::Ticket',
        },
    );
    $m->content_contains('Object created', 'created CF sucessfully' );
    $cfid = $m->form_name('ModifyCustomField')->value('id');
    ok $cfid, "found id of the CF in the form, it's #$cfid";
}

diag "apply the CF to General queue";
my $queue = RT::Test->load_or_create_queue( Name => 'General' );
ok $queue && $queue->id, 'loaded or created queue';

{
    $m->follow_link( id => 'tools-config-queues-select');
    $m->title_is( q/Admin queues/, 'admin-queues screen' );
    $m->follow_link( text => 'General' );
    $m->title_is( q/Configuration for queue General/,
        'admin-queue: general' );
    $m->follow_link( text => 'Ticket Custom Fields' );
    $m->title_is( q/Custom Fields for queue General/,
        'admin-queue: general cfid' );

    $m->form_name('EditCustomFields');
    $m->tick( "AddCustomField" => $cfid );
    $m->click('UpdateCFs');

    $m->content_contains('Object created', 'TCF added to the queue' );
}

diag 'check valid inputs with various timezones in ticket create page';
{
    my ( $ticket, $id );

    $m->submit_form(
        form_name => "CreateTicketInQueue",
        fields    => { Queue => 'General' },
    );
    $m->content_contains('Select date', 'has cf field' );

    $m->submit_form(
        form_name => "TicketCreate",
        fields    => {
            Subject                                       => 'test 2010-05-04',
            Content                                       => 'test',
            "Object-RT::Ticket--CustomField-$cfid-Values" => '2010-05-04',
        },
    );
    ok( ($id) = $m->content =~ /Ticket (\d+) created/, "created ticket $id" );

    $ticket = RT::Ticket->new(RT->SystemUser);
    $ticket->Load($id);
    is( $ticket->CustomFieldValues($cfid)->First->Content,
        '2010-05-04', 'date in db' );

    $m->content_contains('test cf date:', 'has no cf date field on the page' );
    $m->content_contains('Tue May 04 2010',
        'has cf date value on the page' );
}

diag 'check search build page';
{
    $m->get_ok( $baseurl . '/Search/Build.html?Query=Queue=1' );

    $m->form_name('BuildQuery');
    my ($cf_op) =
      $m->find_all_inputs( type => 'option', name_regex => qr/test cf date/ );
    is_deeply(
        [ $cf_op->possible_values ],
        [ '<', '=', '>' ],
        'right oprators'
    );

    my ($cf_field) =
      $m->find_all_inputs( type => 'text', name_regex => qr/test cf date/ );
    $m->submit_form(
        fields => {
            $cf_op->name    => '=',
            $cf_field->name => '2010-05-04'
        },
        button => 'DoSearch',
    );

    $m->content_contains( 'Found 1 ticket', 'Found 1 ticket' );
    $m->content_contains( '2010-05-04',     'got the right ticket' );
    $m->content_lacks( '2010-05-06', 'did not get the wrong ticket' );

    $m->get_ok( $baseurl . '/Search/Build.html?Query=Queue=1' );
    $m->form_name('BuildQuery');
    $m->submit_form(
        fields => {
            $cf_op->name    => '<',
            $cf_field->name => '2010-05-05'
        },
        button => 'DoSearch',
    );
    $m->content_contains( 'Found 1 ticket', 'Found 1 ticket' );

    $m->get_ok( $baseurl . '/Search/Build.html?Query=Queue=1' );
    $m->form_name('BuildQuery');
    $m->submit_form(
        fields => {
            $cf_op->name    => '>',
            $cf_field->name => '2010-05-03',
        },
        button => 'DoSearch',
    );
    $m->content_contains( 'Found 1 ticket', 'Found 1 ticket' );

    $m->get_ok( $baseurl . '/Search/Build.html?Query=Queue=1' );
    $m->form_name('BuildQuery');
    $m->submit_form(
        fields => {
            $cf_op->name    => '=',
            $cf_field->name => '2010-05-05',
        },
        button => 'DoSearch',
    );
    $m->content_contains( 'Found 0 tickets', 'Found 0 tickets' );

    $m->get_ok( $baseurl . '/Search/Build.html?Query=Queue=1' );
    $m->form_name('BuildQuery');
    $m->submit_form(
        fields => {
            $cf_op->name    => '<',
            $cf_field->name => '2010-05-03',
        },
        button => 'DoSearch',
    );
    $m->content_contains( 'Found 0 tickets', 'Found 0 tickets' );

    $m->get_ok( $baseurl . '/Search/Build.html?Query=Queue=1' );
    $m->form_name('BuildQuery');
    $m->submit_form(
        fields => {
            $cf_op->name    => '>',
            $cf_field->name => '2010-05-05',
        },
        button => 'DoSearch',
    );
    $m->content_contains( 'Found 0 tickets', 'Found 0 tickets' );
}

diag 'check invalid inputs';
{
    $m->submit_form(
        form_name => "CreateTicketInQueue",
        fields    => { Queue => 'General' },
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
    $m->content_like( qr/Ticket \d+ created/,
        "a ticket is created succesfully" );

    $m->content_contains('test cf date:', 'has no cf date field on the page' );
    $m->content_lacks('foodate', 'invalid dates not set' );
}

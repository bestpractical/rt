#!/usr/bin/perl

use strict;
use warnings;

use RT::Test tests => 46;

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in as root';

my $cf_name = 'test select one value';

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
            TypeComposite => 'Select-1',
            LookupType    => 'RT::Queue-RT::Ticket',
        },
    );
    $m->content_like( qr/Object created/, 'created CF sucessfully' );
    $cfid = $m->form_name('ModifyCustomField')->value('id');
    ok $cfid, "found id of the CF in the form, it's #$cfid";
}

diag "add 'qwe', 'ASD', '0' and ' foo ' as values to the CF" if $ENV{'TEST_VERBOSE'};
{
    foreach my $value(qw(qwe ASD 0), 'foo ') {
        $m->submit_form(
            form_name => "ModifyCustomField",
            fields => {
                "CustomField-". $cfid ."-Value-new-Name" => $value,
            },
            button => 'Update',
        );
        $m->content_like( qr/Object created/, 'added a value to the CF' ); # or diag $m->content;
        my $v = $value;
        $v =~ s/^\s+$//;
        $v =~ s/\s+$//;
        $m->content_like( qr/value="$v"/, 'the added value is right' );
    }
}

my $queue = RT::Test->load_or_create_queue( Name => 'General' );
ok $queue && $queue->id, 'loaded or created queue';

diag "apply the CF to General queue" if $ENV{'TEST_VERBOSE'};
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

my $tid;
diag "create a ticket using API with 'asd'(not 'ASD') as value of the CF"
    if $ENV{'TEST_VERBOSE'};
{
    my $ticket = RT::Ticket->new( $RT::SystemUser );
    my ($txnid, $msg);
    ($tid, $txnid, $msg) = $ticket->Create(
        Subject => 'test',
        Queue => $queue->id,
        "CustomField-$cfid" => 'asd',
    );
    ok $tid, "created ticket";
    diag $msg if $msg && $ENV{'TEST_VERBOSE'};

    # we use lc as we really don't care about case
    # so if later we'll add canonicalization of value
    # test should work
    is lc $ticket->FirstCustomFieldValue( $cf_name ),
       'asd', 'assigned value of the CF';
}

diag "check that values of the CF are case insensetive(asd vs. ASD)"
    if $ENV{'TEST_VERBOSE'};
{
    ok $m->goto_ticket( $tid ), "opened ticket's page";
    $m->follow_link( text => 'Custom Fields' );
    $m->title_like(qr/Modify ticket/i, 'modify ticket');
    $m->content_like(qr/\Q$cf_name/, 'CF on the page');

    my $value = $m->form_number(3)->value("Object-RT::Ticket-$tid-CustomField-$cfid-Values");
    is lc $value, 'asd', 'correct value is selected';
    $m->submit;
    $m->content_unlike(qr/\Q$cf_name\E.*?changed/mi, 'field is not changed');

    $value = $m->form_number(3)->value("Object-RT::Ticket-$tid-CustomField-$cfid-Values");
    is lc $value, 'asd', 'the same value is still selected';

    my $ticket = RT::Ticket->new( $RT::SystemUser );
    $ticket->Load( $tid );
    ok $ticket->id, 'loaded the ticket';
    is lc $ticket->FirstCustomFieldValue( $cf_name ),
       'asd', 'value is still the same';
}

diag "check that 0 is ok value of the CF"
    if $ENV{'TEST_VERBOSE'};
{
    ok $m->goto_ticket( $tid ), "opened ticket's page";
    $m->follow_link( text => 'Custom Fields' );
    $m->title_like(qr/Modify ticket/i, 'modify ticket');
    $m->content_like(qr/\Q$cf_name/, 'CF on the page');

    my $value = $m->form_number(3)->value("Object-RT::Ticket-$tid-CustomField-$cfid-Values");
    is lc $value, 'asd', 'correct value is selected';
    $m->select("Object-RT::Ticket-$tid-CustomField-$cfid-Values" => 0 );
    $m->submit;
    $m->content_like(qr/\Q$cf_name\E.*?changed/mi, 'field is changed');
    $m->content_unlike(qr/0 is no longer a value for custom field/mi, 'no bad message in results');

    $value = $m->form_number(3)->value("Object-RT::Ticket-$tid-CustomField-$cfid-Values");
    is lc $value, '0', 'new value is selected';

    my $ticket = RT::Ticket->new( $RT::SystemUser );
    $ticket->Load( $tid );
    ok $ticket->id, 'loaded the ticket';
    is lc $ticket->FirstCustomFieldValue( $cf_name ),
       '0', 'API returns correct value';
}

diag "check that we can set empty value when the current is 0"
    if $ENV{'TEST_VERBOSE'};
{
    ok $m->goto_ticket( $tid ), "opened ticket's page";
    $m->follow_link( text => 'Custom Fields' );
    $m->title_like(qr/Modify ticket/i, 'modify ticket');
    $m->content_like(qr/\Q$cf_name/, 'CF on the page');

    my $value = $m->form_number(3)->value("Object-RT::Ticket-$tid-CustomField-$cfid-Values");
    is lc $value, '0', 'correct value is selected';
    $m->select("Object-RT::Ticket-$tid-CustomField-$cfid-Values" => '' );
    $m->submit;
    $m->content_like(qr/0 is no longer a value for custom field/mi, '0 is no longer a value');

    $value = $m->form_number(3)->value("Object-RT::Ticket-$tid-CustomField-$cfid-Values");
    is $value, '', '(no value) is selected';

    my $ticket = RT::Ticket->new( $RT::SystemUser );
    $ticket->Load( $tid );
    ok $ticket->id, 'loaded the ticket';
    is $ticket->FirstCustomFieldValue( $cf_name ),
       undef, 'API returns correct value';
}


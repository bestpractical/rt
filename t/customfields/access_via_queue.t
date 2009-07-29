#!/usr/bin/perl -w

use strict;
use warnings;

use RT::Test tests => 35;
use RT::Ticket;
use RT::CustomField;

my $queue_name = "CFSortQueue-$$";
my $queue = RT::Test->load_or_create_queue( Name => $queue_name );
ok($queue && $queue->id, "$queue_name - test queue creation");

diag "create a CF\n" if $ENV{TEST_VERBOSE};
my $cf_name = "Rights$$";
my $cf;
{
    $cf = RT::CustomField->new( $RT::SystemUser );
    my ($ret, $msg) = $cf->Create(
        Name  => $cf_name,
        Queue => $queue->id,
        Type  => 'FreeformSingle',
    );
    ok($ret, "Custom Field Order created");
}

my $tester = RT::Test->load_or_create_user(
    Name => 'tester', Password => 'password',
);
ok $tester && $tester->id, 'loaded or created user';

my $cc_role = RT::Group->new( $queue->CurrentUser );
$cc_role->LoadQueueRoleGroup( Type => 'Cc', Queue => $queue->id );

my $owner_role = RT::Group->new( $queue->CurrentUser );
$owner_role->LoadQueueRoleGroup( Type => 'Owner', Queue => $queue->id );

ok( RT::Test->set_rights(
    { Principal => $tester, Right => [qw(SeeQueue ShowTicket CreateTicket ReplyToTicket Watch OwnTicket TakeTicket)] },
    { Principal => $cc_role, Object => $queue, Right => [qw(SeeCustomField)] },
    { Principal => $owner_role, Object => $queue, Right => [qw(ModifyCustomField)] },
), 'set rights');

{
    my $ticket = RT::Ticket->new( $tester );
    my ($tid, $msg) = $ticket->Create( Queue => $queue, Subject => 'test' );
    ok $tid, "created ticket";

    ok !$ticket->CustomFields->First, "see no fields";
}

{
    my $ticket = RT::Ticket->new( $tester );
    my ($tid, $msg) = $ticket->Create( Queue => $queue, Subject => 'test', Cc => $tester->id );
    ok $tid, "created ticket";

    my $cf = $ticket->CustomFields->First;
    ok $cf, "Ccs see cf";
}

{
    my $ticket = RT::Ticket->new( $tester );
    my ($tid, $msg) = $ticket->Create( Queue => $queue, Subject => 'test', Cc => $tester->id );
    ok $tid, "created ticket";

    (my $status, $msg) = $ticket->AddCustomFieldValue( Field => $cf->Name, Value => 'test' );
    ok !$status, "Can not change CF";
}

{
    my $ticket = RT::Ticket->new( $tester );
    my ($tid, $msg) = $ticket->Create( Queue => $queue, Subject => 'test', Cc => $tester->id, Owner => $tester->id );
    ok $tid, "created ticket";

    (my $status, $msg) = $ticket->AddCustomFieldValue( Field => $cf->Name, Value => 'test' );
    ok $status, "Changed CF";
    is $ticket->FirstCustomFieldValue( $cf->Name ), 'test';

    ($status, $msg) = $ticket->DeleteCustomFieldValue( Field => $cf->Name, Value => 'test' );
    ok $status, "Changed CF";
    is $ticket->FirstCustomFieldValue( $cf->Name ), undef;
}

{
    my $ticket = RT::Ticket->new( $tester );
    my ($tid, $msg) = $ticket->Create( Queue => $queue, Subject => 'test', Cc => $tester->id, Owner => $tester->id );
    ok $tid, "created ticket";

    (my $status, $msg) = $ticket->AddCustomFieldValue( Field => $cf->id, Value => 'test' );
    ok $status, "Changed CF";
    is $ticket->FirstCustomFieldValue( $cf->id ), 'test';

    ($status, $msg) = $ticket->DeleteCustomFieldValue( Field => $cf->id, Value => 'test' );
    ok $status, "Changed CF";
    is $ticket->FirstCustomFieldValue( $cf->id ), undef;
}

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login( tester => 'password' ), 'logged in';

diag "check that we have no the CF on the create" if $ENV{'TEST_VERBOSE'};
{
    $m->submit_form(
        form_name => "CreateTicketInQueue",
        fields => { Queue => $queue->Name },
    );

    my $form = $m->form_name("TicketCreate");
    my $cf_field = "Object-RT::Ticket--CustomField-". $cf->id ."-Value";
    ok !$form->find_input( $cf_field ), 'no form field on the page';

    $m->submit_form(
        form_name => "TicketCreate",
        fields => { Subject => 'test' },
    );
    my ($tid) = ($m->content =~ /Ticket (\d+) created/i);
    ok $tid, "created a ticket succesfully";
    $m->content_unlike(qr/$cf_name/, "don't see CF");

    $m->follow_link( text => 'Custom Fields' );
    $form = $m->form_number(3);
    $cf_field = "Object-RT::Ticket-$tid-CustomField-". $cf->id ."-Value";
    ok !$form->find_input( $cf_field ), 'no form field on the page';
}

diag "check that we see CF as Cc" if $ENV{'TEST_VERBOSE'};
{
    my $ticket = RT::Ticket->new( $tester );
    my ($tid, $msg) = $ticket->Create( Queue => $queue, Subject => 'test', Cc => $tester->id );
    ok $tid, "created ticket";

    ok $m->goto_ticket( $tid ), "opened ticket";
    $m->content_like(qr/$cf_name/, "see CF");
}

diag "check that owner can see and edit CF" if $ENV{'TEST_VERBOSE'};
{
    my $ticket = RT::Ticket->new( $tester );
    my ($tid, $msg) = $ticket->Create( Queue => $queue, Subject => 'test', Cc => $tester->id, Owner => $tester->id );
    ok $tid, "created ticket";

    ok $m->goto_ticket( $tid ), "opened ticket";
    $m->content_like(qr/$cf_name/, "see CF");

    $m->follow_link( text => 'Custom Fields' );
    my $form = $m->form_number(3);
    my $cf_field = "Object-RT::Ticket-$tid-CustomField-". $cf->id ."-Value";
    ok $form->find_input( $cf_field ), 'form field on the page';

    $m->submit_form(
        form_number => 3,
        fields => {
            $cf_field => "changed cf",
        },
    );

    ok $m->goto_ticket( $tid ), "opened ticket";
    $m->content_like(qr/$cf_name/, "changed cf");
}


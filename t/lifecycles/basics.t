#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;

BEGIN {require  't/lifecycles/utils.pl'};

my $general = RT::Test->load_or_create_queue(
    Name => 'General',
);
ok $general && $general->id, 'loaded or created a queue';

my $tstatus = sub {
    DBIx::SearchBuilder::Record::Cachable->FlushCache;
    my $ticket = RT::Ticket->new( RT->SystemUser );
    $ticket->Load( $_[0] );
    return $ticket->Status;
};

diag "check basic API";
{
    my $schema = $general->Lifecycle;
    isa_ok($schema, 'RT::Lifecycle');
    is $schema->name, 'default', "it's a default schema";
    is join(', ', sort $schema->valid),
        join(', ', sort qw(new open stalled resolved rejected deleted)),
        'this is the default set from our config file';
}

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in';

diag "check status input on create";
{
    $m->goto_create_ticket( $general );

    my $form = $m->form_name('TicketCreate');
    ok my $input = $form->find_input('Status'), 'found status selector';

    my @form_values = $input->possible_values;
    ok scalar @form_values, 'some options in the UI';

    my $valid = 1;
    foreach ( @form_values ) {
        next if $general->Lifecycle->is_valid($_);
        $valid = 0;
        diag("$_ doesn't appear to be a valid status, but it was in the form");
    }


    ok $valid, 'all statuses in the form are valid';
}

diag "create a ticket";
my $tid;
{
    my $ticket = RT::Ticket->new( RT->SystemUser );
    ($tid) = $ticket->Create( Queue => $general->id, Subject => 'test' );
    ok $tid, "created a ticket #$tid";
    is $ticket->Status, 'new', 'correct status';
}

diag "new ->(open it)-> open";
{
    ok $m->goto_ticket( $tid ), 'opened a ticket';

    {
        my @links = $m->followable_links;
        ok scalar @links, 'found links';
        my $found = 1;
        foreach my $t ('Open It', 'Resolve', 'Reject', 'Delete') {
            $found = 0 unless grep {($_->text ||'') eq $t} @links;
        }
        ok $found, 'found all transitions';

        $found = 0;
        foreach my $t ('Stall', 'Re-open', 'Undelete') {
            $found = 1 if grep {($_->text||'') eq $t} @links;
        }
        ok !$found, 'no unwanted transitions';
    }

    $m->follow_link_ok({text => 'Open It'});
    $m->form_name('TicketUpdate');
    $m->click('SubmitTicket');

    is $tstatus->($tid), 'open', 'changed status';
}

diag "open ->(stall)-> stalled";
{
    is $tstatus->($tid), 'open', 'ticket is open';

    ok $m->goto_ticket( $tid ), 'opened a ticket';

    {
        my @links = $m->followable_links;
        ok scalar @links, 'found links';
        my $found = 1;
        foreach my $t ('Stall', 'Resolve', 'Reject') {
            $found = 0 unless grep { ($_->text ||'') eq $t} @links;
        }
        ok $found, 'found all transitions';

        $found = 0;
        foreach my $t ('Open It', 'Delete', 'Re-open', 'Undelete') {
            $found = 1 if grep { ($_->text ||'') eq $t} @links;
        }
        ok !$found, 'no unwanted transitions';
    }

    $m->follow_link_ok({text => 'Stall'});
    $m->form_name('TicketUpdate');
    $m->click('SubmitTicket');

    is $tstatus->($tid), 'stalled', 'changed status';
}

diag "stall ->(open it)-> open";
{
    is $tstatus->($tid), 'stalled', 'ticket is stalled';

    ok $m->goto_ticket( $tid ), 'opened a ticket';

    {
        my @links = $m->followable_links;
        ok scalar @links, 'found links';
        my $found = 1;
        foreach my $t ('Open It') {
            $found = 0 unless grep {($_->text ||'')eq $t} @links;
        }
        ok $found, 'found all transitions';

        $found = 0;
        foreach my $t ('Delete', 'Re-open', 'Undelete', 'Stall', 'Resolve', 'Reject') {
            $found = 1 if grep { ($_->text ||'') eq $t} @links;
        }
        ok !$found, 'no unwanted transitions';
    }

    $m->follow_link_ok({text => 'Open It'});

    is $tstatus->($tid), 'open', 'changed status';
}

diag "open -> deleted, only via modify";
{
    is $tstatus->($tid), 'open', 'ticket is open';

    $m->get_ok( '/Ticket/Modify.html?id='. $tid );
    my $form = $m->form_name('TicketModify');
    ok my $input = $form->find_input('Status'), 'found status selector';

    my @form_values = $input->possible_values;
    ok scalar @form_values, 'some options in the UI';

    ok grep($_ eq 'deleted', @form_values), "has deleted";

    $m->select( Status => 'deleted' );
    $m->submit;

    is $tstatus->($tid), 'deleted', 'deleted ticket';
}

diag "deleted -> X via modify, only open is available";
{
    is $tstatus->($tid), 'deleted', 'ticket is deleted';

    $m->get_ok( '/Ticket/Modify.html?id='. $tid );
    my $form = $m->form_name('TicketModify');
    ok my $input = $form->find_input('Status'), 'found status selector';

    my @form_values = $input->possible_values;
    ok scalar @form_values, 'some options in the UI';

    is join('-', @form_values), '-open', 'only open and default available';
}

diag "check illegal values and transitions";
{
    {
        my $ticket = RT::Ticket->new( RT->SystemUser );
        my ($id, $msg) = $ticket->Create(
            Queue => $general->id,
            Subject => 'test',
            Status => 'illegal',
        );
        ok !$id, 'have not created a ticket';
    }
    {
        my $ticket = RT::Ticket->new( RT->SystemUser );
        my ($id, $msg) = $ticket->Create(
            Queue => $general->id,
            Subject => 'test',
            Status => 'new',
        );
        ok $id, 'created a ticket';
    }
    {
        my $ticket = RT::Ticket->new( RT->SystemUser );
        my ($id, $msg) = $ticket->Create(
            Queue => $general->id,
            Subject => 'test',
            Status => 'new',
        );
        ok $id, 'created a ticket';

        (my $status, $msg) = $ticket->SetStatus( 'illeagal' );
        ok !$status, "couldn't set illeagal status";
        is $ticket->Status, 'new', 'status is steal the same';

        ($status, $msg) = $ticket->SetStatus( 'stalled' );
        ok !$status, "couldn't set status, transition is illeagal";
        is $ticket->Status, 'new', 'status is steal the same';
    }
}

#!/usr/bin/perl

use strict;
use warnings;

use RT::Test tests => 14;

# TODO:
# Test the rest of the conditions.
# Test actions.
# Test templates?
# Test cleanup scripts.

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, "logged in";

$m->follow_link_ok({id => 'tools-config-global-scrips-create'});

sub prepare_code_with_value {
    my $value = shift;

    # changing the ticket is an easy scrip check for a test
    return
        '$self->TicketObj->SetSubject(' .
        '$self->TicketObj->Subject . ' .
        $value .
        ')';
}

{
    # preserve order for checking the subject string later
    my @values_for_actions = (
        [4 => '"Fwd"'],
        [5 => '"FwdTicket"'],
        [6 => '"FwdTransaction"'],
    );

    foreach my $data (@values_for_actions) {
        my ($condition, $prepare_code_value) = @$data;
        diag "Create Scrip (Cond #$condition)" if $ENV{TEST_VERBOSE};
        $m->follow_link_ok({id => 'tools-config-global-scrips-create'});
        my $prepare_code = prepare_code_with_value($prepare_code_value);
        $m->form_name('ModifyScrip');
        $m->set_fields(
            'Scrip-new-ScripCondition'    => $condition,
            'Scrip-new-ScripAction'       => 15, # User Defined
            'Scrip-new-Template'          => 1,  # Blank
            'Scrip-new-CustomPrepareCode' => $prepare_code,
        );
        $m->submit;
    }

    my $ticket_obj = RT::Test->create_ticket(
        Subject => 'subject',
        Content => 'stuff',
        Queue   => 1,
    );
    my $ticket = $ticket_obj->id;
    $m->get("$baseurl/Ticket/Display.html?id=$ticket");

    $m->follow_link_ok(
        { id => 'page-actions-forward' },
        'follow 1st Forward to forward ticket'
    );

    diag "Forward Ticket" if $ENV{TEST_VERBOSE};
    $m->submit_form(
        form_name => 'ForwardMessage',
        fields    => {
            To => 'rt-test, rt-to@example.com',
        },
        button => 'ForwardAndReturn'
    );

    $m->text_contains("#${ticket}: subjectFwdFwdTicket");

    diag "Forward Transaction" if $ENV{TEST_VERBOSE};
    # get the first transaction on the ticket
    my ($transaction) = $ticket_obj->Transactions->First->id;
    $m->get(
        "$baseurl/Ticket/Forward.html?id=1&QuoteTransaction=$transaction"
    );
    $m->submit_form(
        form_name => 'ForwardMessage',
        fields    => {
            To => 'rt-test, rt-to@example.com',
        },
        button => 'ForwardAndReturn'
    );

    $m->text_contains("#${ticket}: subjectFwdFwdTicketFwdFwdTransaction");

    RT::Test->clean_caught_mails;
}

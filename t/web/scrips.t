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
        '"|" . ' . $value .
        ')';
}

{
    # preserve order for checking the subject string later
    my @values_for_actions;

    my $conds = RT::ScripConditions->new(RT->SystemUser);
    foreach my $cond_value ('On Forward', 'On Forward Ticket', 'On Forward Transaction') {
        $conds->Limit(
            FIELD           => 'name',
            VALUE           => $cond_value,
            ENTRYAGGREGATOR => 'OR',
        );
    }

    while (my $rec = $conds->Next) {
        push @values_for_actions, [$rec->Id, '"' . $rec->Name . '"'];
    }

    @values_for_actions = sort { $a->[0] cmp $b->[0] } @values_for_actions;

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
    $m->goto_ticket($ticket);

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

    $m->text_contains("#${ticket}: subject|On Forward|On Forward Ticket");

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

    $m->text_contains("#${ticket}: subject|On Forward|On Forward Ticket|On Forward|On Forward Transaction");

    RT::Test->clean_caught_mails;
}

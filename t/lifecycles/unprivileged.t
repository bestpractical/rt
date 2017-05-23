use strict;
use warnings;

BEGIN { require './t/lifecycles/utils.pl' }

my $triage = RT::Test->load_or_create_queue(
    Name      => 'triage',
    Lifecycle => 'triage',
);
ok $triage && $triage->id, 'loaded or created a queue';

my $user = RT::User->new( RT->SystemUser );
$user->Create( Name => "SelfService", Password => "password", Privileged => 0 );

ok( RT::Test->add_rights(
        { Principal => 'Everyone', Object => $triage, Right => [qw(CreateTicket ShowTicket ModifyTicket)] }
    )
  );

# disable autoopen scrip to make tests more straightforward
# otherwise, RT System will automatically set tickets from "untriaged"
# to "ordinary". there's little other recourse because unprivileged can
# only use the reply page to update tickets
my $scrip = RT::Scrip->new( RT->SystemUser );
$scrip->LoadByCols( Description => 'On Correspond Open Inactive Tickets' );
my ( $ok, $msg ) = $scrip->SetDisabled(1);
ok( $ok, $msg );

my $tstatus = sub {
    DBIx::SearchBuilder::Record::Cachable->FlushCache;
    my $ticket = RT::Ticket->new( RT->SystemUser );
    $ticket->Load( $_[0] );
    return $ticket->Status;
};

my $txn_creator = sub {
    DBIx::SearchBuilder::Record::Cachable->FlushCache;
    my $ticket = RT::Ticket->new( RT->SystemUser );
    $ticket->Load( $_[0] );
    my $txns = $ticket->Transactions;
    $txns->Limit( FIELD => 'Type', VALUE => 'Status' );
    die "Got " . $txns->Count . " transactions; expected 1" if $txns->Count != 1;
    return $txns->First->Creator;
};

my ($baseurl) = RT::Test->started_ok;
my $m = RT::Test::Web->new;
$m->get_ok("$baseurl/index.html?user=SelfService&pass=password");

my $ticket_id;

diag "create a ticket";
{
    $m->get_ok( "$baseurl/SelfService/Create.html?Queue=" . $triage->Id );
    $m->text_contains( "Create a ticket in #" . $triage->Id );
    $m->submit_form_ok( { with_fields => { Subject => "can't see queue" }, } );
    $m->text_like(qr/Ticket \d+ created in queue 'triage'/);
    ($ticket_id) = ( $m->content =~ /Ticket (\d+) created in queue/ );
    is( $tstatus->($ticket_id), 'untriaged', 'used default status' );
}

diag "update a ticket without any special permissions required";
{
    $m->follow_link_ok( { text => 'Reply' }, "reply to the ticket" );
    $m->text_contains( "Update ticket #" . $ticket_id );
    ok my $form  = $m->form_name('TicketUpdate'), 'found form';
    ok my $input = $form->find_input('Status'),   'found status selector';
    my @form_values = $input->possible_values;
    is_deeply( \@form_values, [ '', 'untriaged', 'ordinary', ], "possible statuses" );

    $m->submit_form_ok(
        {   with_fields => {
                Status        => "ordinary",
                UpdateContent => "hello world",
            },
            button => 'SubmitTicket',
        }
    );
    $m->text_contains("Correspondence added");
    $m->text_contains("Status changed from 'untriaged' to 'ordinary'");
    $m->text_lacks("Permission Denied");
    is( $tstatus->($ticket_id),     "ordinary", "updated ticket" );
    is( $txn_creator->($ticket_id), $user->Id,  "txn creator" );
}

my $ticket2_id;

diag "create a ticket";
{
    $m->get_ok( "$baseurl/SelfService/Create.html?Queue=" . $triage->Id );
    $m->text_contains( "Create a ticket in #" . $triage->Id );
    $m->submit_form_ok( { with_fields => { Subject => "can't see queue" }, } );
    $m->text_like(qr/Ticket \d+ created in queue 'triage'/);
    ($ticket2_id) = ( $m->content =~ /Ticket (\d+) created in queue/ );
    is( $tstatus->($ticket2_id), 'untriaged', 'used default status' );
}

diag "update a ticket with necessary special permissions missing";
{
    $m->follow_link_ok( { text => 'Reply' }, "reply to the ticket" );
    $m->text_contains( "Update ticket #" . $ticket2_id );
    ok my $form  = $m->form_name('TicketUpdate'), 'found form';
    ok my $input = $form->find_input('Status'),   'found status selector';
    my @form_values = $input->possible_values;
    is_deeply( \@form_values, [ '', 'untriaged', 'ordinary', ], "possible statuses" );

    $m->submit_form_ok(
        {   with_fields => {
                Status        => "escalated",
                UpdateContent => "hello world",
            },
            button => 'SubmitTicket',
        }
    );
    $m->text_contains("Correspondence added");
    $m->text_contains("Permission Denied");
    $m->text_lacks("Status changed from 'untriaged' to 'escalated'");
    is( $tstatus->($ticket2_id), "untriaged", "no update" );
}

ok( RT::Test->add_rights( { Principal => 'Everyone', Object => $triage, Right => [qw(EscalateTicket)] } ) );

diag "update a ticket with necessary special permissions granted";
{
    $m->follow_link_ok( { text => 'Reply' }, "reply to the ticket" );
    $m->text_contains( "Update ticket #" . $ticket2_id );
    ok my $form  = $m->form_name('TicketUpdate'), 'found form';
    ok my $input = $form->find_input('Status'),   'found status selector';
    my @form_values = $input->possible_values;
    is_deeply( \@form_values, [ '', 'untriaged', 'ordinary', 'escalated', ], "possible statuses" );

    $m->submit_form_ok(
        {   with_fields => {
                Status        => "escalated",
                UpdateContent => "hello world",
            },
            button => 'SubmitTicket',
        }
    );
    $m->text_contains("Correspondence added");
    $m->text_contains("Status changed from 'untriaged' to 'escalated'");
    $m->text_lacks("Permission Denied");
    is( $tstatus->($ticket2_id),     "escalated", "now updated" );
    is( $txn_creator->($ticket2_id), $user->Id,   "txn creator" );
}

done_testing;

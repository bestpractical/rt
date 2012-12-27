use strict;
use warnings;

use RT::Test tests => 19;

my $queue = RT::Test->load_or_create_queue( Name => 'Test' );
ok $queue && $queue->id, 'loaded or created queue';

my $user_a = RT::Test->load_or_create_user(
    Name            => 'user_a',
    EmailAddress    => 'user_a@example.com',
    Password        => 'password',
);
ok $user_a && $user_a->id, 'loaded or created user';

RT->Config->Set( AutocompleteOwners => 0 );
my ($baseurl, $agent_root) = RT::Test->started_ok;

ok( RT::Test->set_rights({
    Principal   => 'Requestor',
    Object      => $queue,
    Right       => [qw(OwnTicket)]
}), 'set rights');

ok $agent_root->login('root', 'password'), 'logged in as user root';

diag "user_a doesn't show up in create form";
{
    $agent_root->get_ok('/', 'open home page');
    $agent_root->form_name('CreateTicketInQueue');
    $agent_root->select( 'Queue', '1' );
    $agent_root->submit;

    $agent_root->content_contains('Create a new ticket', 'opened create ticket page');
    my $form = $agent_root->form_name('TicketCreate');
    my $input = $form->find_input('Owner');
    is $input->value, RT->Nobody->Id, 'correct owner selected';
    ok((not scalar grep { $_ == $user_a->Id } $input->possible_values), 'no user_a value in dropdown');
    $form->value('Requestors', 'user_a@example.com');
    $agent_root->submit;

    $agent_root->content_like(qr/Ticket \d+ created in queue/i, 'created ticket');
    my ($id) = ($agent_root->content =~ /Ticket (\d+) created in queue/);
    ok $id, 'found id of the ticket';

    my $ticket = RT::Ticket->new( RT->SystemUser );
    $ticket->Load( $id );
    ok $ticket->id, 'loaded the ticket';
    is $ticket->Queue, '1', 'correct queue';
    is $ticket->Owner, RT->Nobody->Id, 'correct owner';
    is $ticket->RequestorAddresses, 'user_a@example.com', 'correct requestor';
}

diag "user_a doesn't appear in owner list after being made requestor";
{
    $agent_root->get("/Ticket/Modify.html?id=1");
    my $form = $agent_root->form_name('TicketModify');
    my $input = $form->find_input('Owner');
    is $input->value, RT->Nobody->Id, 'correct owner selected';
    ok((not scalar grep { $_ == $user_a->Id } $input->possible_values), 'no user_a value in dropdown');
}


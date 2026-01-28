use strict;
use warnings;

BEGIN {require './t/lifecycles/utils.pl'};
my ( $url, $agent ) = RT::Test->started_ok;

diag 'Test web UI for ticket status without SeeQueue right';
{

    my $delivery = RT::Test->load_or_create_queue(
        Name => 'delivery',
        Lifecycle => 'delivery',
    );
    ok $delivery && $delivery->id, 'loaded or created a queue';

    my $ticket = RT::Test->create_ticket(Queue => 'Delivery');
    ok $ticket && $ticket->Id;

    my $user_a = RT::Test->load_or_create_user(
        Name => 'user_a', Password => 'password', Privileged => 1,
    );
    ok $user_a && $user_a->id, 'loaded or created user';

    RT::Test->set_rights(
        { Principal => 'Everyone',  Right => [qw(ModifyTicket ShowTicket)] },
    );

    ok( $agent->login( 'user_a' , 'password' ), 'logged in as user_a');

    $agent->get_ok($url . '/Ticket/ModifyAll.html?id=' . $ticket->Id);
    $agent->form_name('TicketModifyAll');

    my ($inputs) = $agent->find_all_inputs(
        type       => 'option',
        name       => 'Status',
    );

    $agent->get_ok($url . '/Ticket/ModifyAll.html?id=' . $ticket->Id);
    $agent->form_name('TicketModifyAll');

    # Refresh page after rights update
    ($inputs) = $agent->find_all_inputs(
        type       => 'option',
        name       => 'Status',
    );

    ok $inputs->value_names > 2, 'We are able to transition to other statuses with role rights';

}

diag 'Test status rights cleanup';
{
    ok( $agent->login( 'root', 'password', logout => 1 ), 'logged in as root' );
    $agent->get_ok('/Admin/Lifecycles/Rights.html?Type=ticket;Name=default');

    $agent->submit_form_ok(
        {   form_name => 'ModifyLifecycleRights',
            fields    => {
                'Right-From-1' => '*',
                'Right-To-1'   => 'stalled',
                'Right-Name-1' => 'StallTicket',
            },
            button => 'Update',
        },
        'Created StallTicket right'
    );
    $agent->text_contains('Lifecycle updated');

    $agent->get_ok('/Admin/Global/GroupRights.html');
    $agent->text_contains('StallTicket', 'New right shows up on Rights page');

    $agent->get_ok('/Admin/Lifecycles/Rights.html?Type=ticket;Name=default');
    $agent->submit_form_ok(
        {   form_name => 'ModifyLifecycleRights',
            fields    => { 'Delete-1' => 1, },
            button    => 'Update',
        },
        'Deleted StallTicket right'
    );
    $agent->text_contains('Lifecycle updated');

    $agent->get_ok('/Admin/Global/GroupRights.html');
    $agent->text_lacks('StallTicket', 'Deleted right is gone on Rights page');
}

diag 'Test that queue rights page only shows rights for its lifecycle';
{
    # General queue uses 'default' lifecycle which has no custom status rights
    # The 'triage' lifecycle defines 'EscalateTicket' right
    # That right should NOT appear on General queue's rights page

    $agent->get_ok('/Admin/Queues/GroupRights.html?id=1');
    $agent->text_lacks( 'EscalateTicket', 'Rights from other lifecycles should not appear on queue rights page' );

    # Now test a queue using the 'triage' lifecycle DOES show EscalateTicket
    my $triage_queue = RT::Test->load_or_create_queue(
        Name      => 'triage',
        Lifecycle => 'triage',
    );
    ok $triage_queue && $triage_queue->id, 'loaded or created triage queue';

    $agent->get_ok('/Admin/Queues/GroupRights.html?id=' . $triage_queue->id);
    $agent->text_contains( 'EscalateTicket', 'Rights from queue lifecycle should appear on queue rights page' );
}

done_testing;

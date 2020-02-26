use strict;
use warnings;

BEGIN {require './t/lifecycles/utils.pl'};

diag 'Test web UI for ticket status without SeeQueue right';
{
    my ( $url, $agent ) = RT::Test->started_ok;

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

    $agent->get_ok($url . '/Ticket/Modify.html?id=' . $ticket->Id);
    $agent->form_name('TicketModify');

    my ($inputs) = $agent->find_all_inputs(
        type       => 'option',
        name       => 'Status',
    );

    $agent->get_ok($url . '/Ticket/Modify.html?id=' . $ticket->Id);
    $agent->form_name('TicketModify');

    # Refresh page after rights update
    ($inputs) = $agent->find_all_inputs(
        type       => 'option',
        name       => 'Status',
    );

    ok $inputs->value_names > 2, 'We are able to transition to other statuses with role rights';

}

done_testing;

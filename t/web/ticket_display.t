use strict;
use warnings;

use RT::Test tests => undef;

my $queue = RT::Test->load_or_create_queue( Name => 'General' );

my $user = RT::Test->load_or_create_user(
    Name     => 'user',
    Password => 'password',
);

my $cf = RT::Test->load_or_create_custom_field( Name => 'test_cf', Queue => $queue->Name, Type => 'FreeformSingle' );
my $cf_form_id = 'Object-RT::Ticket--CustomField-'.$cf->Id.'-Value';
my $cf_test_value = "some string for test_cf $$";

my ( $baseurl, $m ) = RT::Test->started_ok;
ok(
    RT::Test->set_rights(
        { Principal => $user, Right => [qw(SeeQueue CreateTicket)] },
        { Principal => $user, Object => $queue, Right => [qw(SeeCustomField ModifyCustomField)] }
    ),
    'set rights'
);

ok $m->login( 'user', 'password' ), 'logged in as user';

diag "test ShowTicket right";
{

    $m->get_ok( '/Ticket/Create.html?Queue=' . $queue->id,
        'go to ticket create page' );
    my $form = $m->form_name('TicketCreate');
    $m->submit_form( fields => { Subject => 'ticket foo', $cf_form_id => $cf_test_value } );

    my $ticket = RT::Test->last_ticket;
    ok( $ticket->id, 'ticket is created' );
    my $id = $ticket->id;

    $m->content_lacks( "Ticket $id created", 'created ticket' );
    $m->content_contains( "No permission to view newly created ticket #$id",
        'got no permission msg' );
    $m->warning_like( qr/No permission to view newly created ticket #$id/,
        'got no permission warning' );


    $m->goto_ticket($id, undef, HTTP::Status::HTTP_FORBIDDEN);
    is($m->status, HTTP::Status::HTTP_FORBIDDEN, 'No permission');
    $m->content_contains( "No permission to view ticket",
        'got no permission msg' );
    $m->warning_like( qr/No permission to view ticket/, 'got warning' );
    $m->title_is('RT Error');

    ok(
        RT::Test->add_rights(
            { Principal => $user, Right => [qw(ShowTicket)] },
        ),
        'add ShowTicket right'
    );

    $m->reload;

    $m->content_lacks( "No permission to view ticket", 'no error msg' );
    $m->title_is( "#$id: ticket foo", 'we can it' );
    $m->content_contains($cf_test_value, "Custom Field was submitted and saved");
}


done_testing();

use strict;
use warnings;

use RT::Test tests => undef;
use RT::Lifecycle;

# populate lifecycles
my $lifecycles = RT->Config->Get('Lifecycles');
RT->Config->Set(
    Lifecycles => %{$lifecycles},
    foo        => {
        initial  => ['initial'],
        active   => ['open'],
        inactive => ['resolved'],
    }
);
RT::Lifecycle->FillCache();

# populate test queues and test user
my $queue1 = RT::Test->load_or_create_queue( Name => 'General' );
my $queue2 = RT::Test->load_or_create_queue( Name => 'Another queue' );
my $user   = RT::Test->load_or_create_user(
    Name     => 'user',
    Password => 'password',
);

my ( $baseurl, $m ) = RT::Test->started_ok;

#set up lifecycle for one of the queues
ok $m->login;
$m->get_ok( '/Admin/Queues/Modify.html?id=' . $queue1->id );
$m->form_name('ModifyQueue');
$m->submit_form( fields => { Lifecycle => 'foo' } );

# set up custom field
my $cf = RT::Test->load_or_create_custom_field( Name => 'test_cf', Queue => $queue1->Name, Type => 'FreeformSingle' );
my $cf_form_id    = 'Object-RT::Ticket--CustomField-' . $cf->Id . '-Value';
my $cf_test_value = "some string for test_cf $$";

# load initial ticket create page without specifying queue
# should have default queue with no custom fields
note('load create ticket page with defaults');
$m->get_ok('/');
$m->submit_form( form_name => "CreateTicketInQueue", );

ok( !$m->form_name('TicketCreate')->find_input($cf_form_id), 'custom field not present' );
is( $m->form_name('TicketCreate')->value('Queue'), $queue2->id, 'Queue selection dropdown populated and pre-selected' );
is( $m->form_name('TicketCreate')->value('Status'), 'new', 'Status selection dropdown populated and pre-selected' );

$m->get_ok( '/Ticket/Create.html', 'go to ticket create page with no queue id' );
ok( !$m->form_name('TicketCreate')->find_input($cf_form_id), 'custom field not present' );
is( $m->form_name('TicketCreate')->value('Queue'), $queue2->id, 'Queue selection dropdown populated and pre-selected' );
is( $m->form_name('TicketCreate')->value('Status'), 'new', 'Status selection dropdown populated and pre-selected' );

# test ticket creation on reload from selected queue, specifying queue with custom fields
note('reload ticket create page with selected queue');
$m->get_ok( '/Ticket/Create.html?Queue=' . $queue1->id, 'go to ticket create page' );

is( $m->form_name('TicketCreate')->value('Queue'), $queue1->id, 'Queue selection dropdown populated and pre-selected' );
ok( $m->form_name('TicketCreate')->find_input($cf_form_id), 'custom field present' );
is( $m->form_name('TicketCreate')->value($cf_form_id), '', 'custom field present and empty' );

my $form         = $m->form_name('TicketCreate');
my $status_input = $form->find_input('Status');
is_deeply(
    [ $status_input->possible_values ],
    [ 'initial', 'open', 'resolved' ],
    'status selectbox shows custom lifecycle for queue'
);

note('submit populated form');
$m->submit_form( fields => { Subject => 'ticket foo', 'Queue' => $queue1->id, $cf_form_id => $cf_test_value }, button => 'SubmitTicket' );
$m->text_contains( 'test_cf',      'custom field populated in display' );
$m->text_contains( $cf_test_value, 'custom field populated in display' );

my $ticket = RT::Test->last_ticket;
ok( $ticket->id, 'ticket is created' );
is( $ticket->QueueObj->id, $queue1->id, 'Ticket created with correct queue' );

ok( $m->logout, 'Logged out' );
ok( $m->login( 'user', 'password' ), 'logged in as user' );
$m->submit_form_ok( { form_name => 'CreateTicketInQueue' }, 'Try to create ticket' );
$m->content_contains('Permission Denied', 'No permission to create ticket');
$m->warning_like(qr/Permission Denied/, 'Permission denied warning' );

ok( $user->PrincipalObj->GrantRight( Right => 'SeeQueue', Object => RT->System ), 'Grant SeeQueue right' );
$m->submit_form_ok( { form_name => 'CreateTicketInQueue' }, 'Try to create ticket' );
$m->content_contains( 'Permission Denied', 'No permission to create ticket even with SeeQueue' );
$m->warning_like(qr/Permission Denied/, 'Permission denied warning' );

ok( $user->PrincipalObj->GrantRight( Right => 'CreateTicket', Object => $queue2 ), 'Grant CreateTicket right' );
$m->submit_form_ok( { form_name => 'CreateTicketInQueue' }, 'Try to create ticket' );
$m->content_lacks( 'Permission Denied', 'Has permission to create ticket' );
$form = $m->form_name('TicketCreate');
is_deeply( [ $form->find_input('Queue','option')->possible_values ], [ $queue2->id ], 'Only Another queue is listed' );

diag 'Test DefaultQueue setting with and without SeeQueue rights';

RT::Test->stop_server;
RT->Config->Set(DefaultQueue => 'General');
( $baseurl, $m ) = RT::Test->started_ok;

ok( $user->PrincipalObj->RevokeRight( Right => 'SeeQueue', Object => RT->System ), 'Revoke SeeQueue right' );
ok( $m->login( 'user', 'password' ), 'Logged in as user' );
$m->submit_form_ok( { form_name => 'CreateTicketInQueue' }, 'Try to create ticket' );
$m->text_contains('Permission Denied', 'No permission to create ticket without SeeQueue');
$m->warning_like(qr/Permission Denied/, 'Permission denied warning' );

ok( $user->PrincipalObj->GrantRight( Right => 'SeeQueue', Object => $queue2 ), 'Grant SeeQueue right to Another queue' );
$m->submit_form_ok( { form_name => 'CreateTicketInQueue' }, 'Try to create ticket' );
$m->content_lacks( 'Permission Denied', 'Has permission to create ticket' );
$form = $m->form_name('TicketCreate');
is( $form->value('Queue'), $queue2->id, 'Queue selection dropdown populated and pre-selected with ' . $queue2->Name );
is_deeply( [ $form->find_input('Queue','option')->possible_values ], [ $queue2->id ], 'Only queue listed is ' . $queue2->Name );

done_testing();

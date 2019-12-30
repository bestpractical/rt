use strict;
use warnings;
use Test::HTML::Form;

use RT::Test tests => undef;
use RT::Lifecycle;

# populate lifecycles
my $lifecycles = RT->Config->Get('Lifecycles');
RT->Config->Set( Lifecycles => %{$lifecycles},
                 foo => {
                     initial  => ['initial'],
                     active   => ['open'],
                     inactive => ['resolved'],
                 }
);
RT::Lifecycle->FillCache();

# populate test queues and test user
my $queue1 = RT::Test->load_or_create_queue( Name => 'General' );
my $queue2 = RT::Test->load_or_create_queue( Name => 'Specific' );
my $queue3 = RT::Test->load_or_create_queue( Name => 'Bugs' );
my $user = RT::Test->load_or_create_user(
    Name     => 'user',
    Password => 'password',
);

my ( $baseurl, $m ) = RT::Test->started_ok;

#set up lifecycle for one of the queues
ok $m->login;
$m->get_ok( '/Admin/Queues/Modify.html?id='.$queue1->id );
$m->form_name('ModifyQueue');
$m->submit_form( fields => { Lifecycle => 'foo' } );

# set up custom field
my $cf = RT::Test->load_or_create_custom_field( Name => 'test_cf', Queue => $queue1->Name, Type => 'FreeformSingle' );
my $cf_form_id = 'Object-RT::Ticket--CustomField-'.$cf->Id.'-Value';
my $cf_test_value = "some string for test_cf $$";

# load initial ticket create page without specifying queue
# should have default queue with no custom fields
note('load create ticket page with defaults');
$m->get_ok( '/Ticket/Create.html', 'go to ticket create page with no queue id' );
no_tag($m,'input',{ name => $cf_form_id }, 'no custom field');
form_field_value_matches($m, 'Queue', $queue3->id, 'TicketCreate', 'queue id set in hidden field');
form_select_field_matches($m, { field_name => 'SelectedQueue', selected => $queue3->id,
                                form_name => 'TicketCreate'}, 'Queue selection dropdown populated');
form_select_field_matches($m, { field_name => 'Status', selected => "new",
                                form_name => 'TicketCreate'}, 'Status selection dropdown populated');

# test ticket creation on reload from selected queue, specifying queue with custom fields
note('reload ticket create page with selected queue');
$m->get_ok( '/Ticket/Create.html?queue-changed-reload=1&Queue='.$queue1->id.'&SelectedQueue=' . $queue1->id,
            'go to ticket create page' );

form_select_field_matches($m, { field_name => 'SelectedQueue', selected => $queue1->id,
                                form_name => 'TicketCreate'}, 'Queue selection dropdown populated and pre-selected');
form_field_value_matches($m, 'Queue', $queue1->id, 'TicketCreate', 'queue id set in hidden field');
form_field_value_matches($m, $cf_form_id, "", 'TicketCreate', 'custom field is present');

my $form = $m->form_name('TicketCreate');
my $status_input = $form->find_input('Status');
is_deeply( [ $status_input->possible_values ], [ 'initial', 'open', 'resolved' ], 'status selectbox shows custom lifecycle for queue' );

note('submit populated form');
$m->submit_form( fields => { Subject => 'ticket foo', 'Queue' => $queue1->id, $cf_form_id => $cf_test_value } );
$m->text_contains('test_cf', 'custom field populated in display');
$m->text_contains($cf_test_value, 'custom field populated in display');

my $ticket = RT::Test->last_ticket;
ok( $ticket->id, 'ticket is created' );
is($ticket->QueueObj->id, $queue1->id, 'Ticket created with correct queue');

done_testing();

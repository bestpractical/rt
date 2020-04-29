use strict;
use warnings;

use RT::Test tests => undef;

my ( $baseurl, $m ) = RT::Test->started_ok;
ok $m->login, 'logged in as root';

my $customrole_name = 'test customrole';

diag( 'Create custom role' );

# create custom role
$m->follow_link_ok({ id => 'admin-custom-roles-create' }, "Followed link to 'Admin > Custom Roles > Create'" );
$m->submit_form(
    form_name => 'ModifyCustomRole',
    fields => {
        Name => $customrole_name,
    },
);
$m->content_contains( 'Custom role created', 'Created customrole' );

my $customrole_id = $m->form_name( 'ModifyCustomRole' )->value( 'id' );

# set applies to
$m->follow_link_ok({ id => 'page-applies-to' }, "Followed link to 'Applies to'" );
$m->form_name( 'AddRemoveCustomRole' );
$m->current_form->find_input( 'AddRole-1' )->check;
$m->click_ok( 'Update', "Added '$customrole_name' to General queue" );
$m->content_contains( "$customrole_name added to queue General" );

diag( 'Verify visibility is shown by default' );

# ensure all pages are set visible by default
$m->follow_link_ok({ id => 'page-visibility' }, "Followed link to 'Visibility'" );
ok( !$m->form_name( 'Visibility' )->value( 'hide-/Ticket/Create.html' ), 'Ticket create is set visible by default' );
ok( !$m->form_name( 'Visibility' )->value( 'hide-/Ticket/Display.html' ), 'Ticket display is set visible by default' );
ok( !$m->form_name( 'Visibility' )->value( 'hide-/Ticket/ModifyPeople.html' ), 'Ticket modify people is set visible by default' );
ok( !$m->form_name( 'Visibility' )->value( 'hide-/Ticket/ModifyAll.html' ), 'Ticket jumbo is set visible by default' );

# confirm each page is visible by default
$m->get_ok( '/Ticket/Create.html?Queue=1' );
$m->content_contains( "$customrole_name" );

$m->submit_form(
    form_name => 'TicketCreate',
    fields => {
        Subject => 'test ticket',
    },
    button => 'SubmitTicket',
);
$m->content_contains( 'Ticket 1 created in queue', 'Created ticket' );

$m->get_ok( '/Ticket/Display.html?id=1' );
$m->content_contains( "$customrole_name" );
$m->get_ok( '/Ticket/ModifyPeople.html?id=1' );
$m->content_contains( "$customrole_name" );
$m->get_ok( '/Ticket/ModifyAll.html?id=1' );
$m->content_contains( "$customrole_name" );

diag( 'Remove visibility' );

# set each visibility to hidden
$m->follow_link_ok({ id => 'admin-custom-roles-select' }, "Followed link to 'Admin > Custom Roles > Select'" );
$m->follow_link_ok({ text => $customrole_name }, "Followed link to '$customrole_name'" );
$m->follow_link_ok({ id => 'page-visibility' }, "Followed link to 'Visibility'" );
$m->form_name( 'Visibility' );
$m->current_form->find_input( 'hide-/Ticket/Create.html' )->check;
$m->current_form->find_input( 'hide-/Ticket/Display.html' )->check;
$m->current_form->find_input( 'hide-/Ticket/ModifyPeople.html' )->check;
$m->current_form->find_input( 'hide-/Ticket/ModifyAll.html' )->check;
$m->click_ok( 'Update', 'Set visibility to hide for all pages' );
$m->content_contains( 'Updated visibility' );
ok( $m->form_name( 'Visibility' )->value( 'hide-/Ticket/Create.html' ), 'Ticket create is set hidden' );
ok( $m->form_name( 'Visibility' )->value( 'hide-/Ticket/Display.html' ), 'Ticket display is set hidden' );
ok( $m->form_name( 'Visibility' )->value( 'hide-/Ticket/ModifyPeople.html' ), 'Ticket modify people is set hidden' );
ok( $m->form_name( 'Visibility' )->value( 'hide-/Ticket/ModifyAll.html' ), 'Ticket jumbo is set hidden' );

diag( 'Verify visibility is hidden' );

# confirm hidden on each page
$m->get_ok( '/Ticket/Create.html?Queue=1' );
$m->content_lacks( "$customrole_name" );

$m->submit_form(
    form_name => 'TicketCreate',
    fields => {
        Subject => 'test ticket 2',
    },
    button => 'SubmitTicket',
);
$m->content_contains( 'Ticket 2 created in queue', 'Created ticket' );

$m->get_ok( '/Ticket/Display.html?id=2' );
$m->content_lacks( "$customrole_name" );
$m->get_ok( '/Ticket/ModifyPeople.html?id=2' );
$m->content_lacks( "$customrole_name" );
$m->get_ok( '/Ticket/ModifyAll.html?id=2' );
$m->content_lacks( "$customrole_name" );

# TODO:
# create customrole not for multiple users
# verify additional pages customrole is visible for a single user
# - Ticket modify basics
# - Ticket reply/comment

done_testing();

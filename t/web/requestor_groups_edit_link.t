
use strict;
use warnings;

use RT::Test tests => 11;

RT->Config->Set( ShowMoreAboutPrivilegedUsers    => 1 );

my ( $url, $m ) = RT::Test->started_ok;
my $user_a = RT::Test->load_or_create_user(
    Name     => 'user_a',
    Password => 'password',
);
ok( $user_a, 'created user user_a' );
ok(
    RT::Test->set_rights(
        {
            Principal => $user_a,
            Right     => [ qw/SeeQueue ShowTicket CreateTicket/ ]
        },
    ),
    'set rights for user_a'
);

my $ticket = RT::Ticket->new(RT->SystemUser);
my ($id) = $ticket->Create(
    Subject   => 'groups limit',
    Queue     => 'General',
    Requestor => $user_a->id,
);
ok( $id, 'created ticket' );


ok( $m->login( user_a => 'password' ), 'logged in as user_a' );

$m->goto_ticket($id);

ok(
    !$m->find_link( text => 'Edit' ), 'no Edit link without AdminUsers permission'
);

ok(
    RT::Test->add_rights(
        {
            Principal => $user_a,
            Right     => [ qw/AdminUsers ShowConfigTab/ ]
        },
    ),
    'add AdminUsers and ShowConfigTab rights for user_a'
);

$m->goto_ticket($id);
$m->follow_link_ok( { text => 'Edit' }, 'follow the Edit link' );
is( $m->uri, $url . "/Admin/Users/Memberships.html?id=" . $user_a->id, 'url is right' );


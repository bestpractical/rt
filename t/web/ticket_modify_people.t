use strict;
use warnings;

use RT::Test tests => 23;

my $root = RT::Test->load_or_create_user( Name => 'root' );
my $group_foo = RT::Group->new($RT::SystemUser);
my ( $ret, $msg ) = $group_foo->CreateUserDefinedGroup(
    Name        => 'group_foo',
    Description => 'group_foo',
);
ok( $ret, 'created group_foo' );

my $ticket = RT::Test->create_ticket(
    Subject   => 'test modify people',
    Queue     => 'General',
    Requestor => $root->id,
    Cc        => $group_foo->id,
);

my $user = RT::Test->load_or_create_user(
    Name     => 'user',
    Password => 'password',
);
ok $user && $user->id, 'loaded or created user';

ok(
    RT::Test->set_rights(
        { Principal => $user, Right => [qw(SeeQueue ShowTicket ModifyTicket)] },
    ),
    'set rights'
);

my ( $url, $m ) = RT::Test->started_ok;
ok( $m->login( 'user', 'password' ), 'logged in' );
$m->get_ok( $url . "/Ticket/ModifyPeople.html?id=" . $ticket->id );

ok(
    !$m->find_link(
        text      => 'Enoch Root',
        url_regex => qr!/Admin/Users/Modify\.html!,
    ),
    'no link to modify user'
);
$m->content_contains('Enoch Root', 'still has the user name' );

ok(
    !$m->find_link(
        text      => 'group_foo',
        url_regex => qr!/Admin/Groups/Modify\.html!,
    ),
    'no link to modify group'
);

$m->content_contains('group_foo', 'still has the group name' );

ok( RT::Test->add_rights( { Principal => $user, Right => ['AdminUsers'] }, ),
    'added AdminUsers right' );
$m->reload;
ok(
    !$m->find_link(
        text      => 'Enoch Root',
        url_regex => qr!/Admin/Users/Modify\.html!,
    ),
    'still no link to modify user'
);
ok(
    !$m->find_link(
        text      => 'group_foo',
        url_regex => qr!/Admin/Groups/Modify\.html!,
    ),
    'still no link to modify group'
);

ok(
    RT::Test->add_rights( { Principal => $user, Right => ['ShowConfigTab'] }, ),
    'added ShowConfigTab right',
);

$m->reload;
ok(
    $m->find_link(
        text      => 'Enoch Root',
        url_regex => qr!/Admin/Users/Modify\.html!,
    ),
    'got link to modify user'
);

ok(
    !$m->find_link(
        text      => 'group_foo',
        url_regex => qr!/Admin/Groups/Modify\.html!,
    ),
    'still no link to modify group'
);

ok(
    RT::Test->add_rights( { Principal => $user, Right => ['AdminGroup'] }, ),
    'added AdminGroup right'
);

$m->reload;
ok(
    $m->find_link(
        text      => 'group_foo',
        url_regex => qr!/Admin/Groups/Modify\.html!,
    ),
    'got link to modify group'
);


# TODO test Add|Delete people


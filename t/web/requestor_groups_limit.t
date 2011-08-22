
use strict;
use warnings;

use RT::Test tests => 11;

diag "set groups limit to 1";
RT->Config->Set( ShowMoreAboutPrivilegedUsers    => 1 );
RT->Config->Set( MoreAboutRequestorGroupsLimit => 1 );

my $ticket = RT::Ticket->new(RT->SystemUser);
my ($id) = $ticket->Create(
    Subject   => 'groups limit',
    Queue     => 'General',
    Requestor => 'root@localhost',
);
ok( $id, 'created ticket' );

my ( $url, $m ) = RT::Test->started_ok;
ok( $m->login(), 'logged in as root' );
$m->goto_ticket($id);
$m->content_like( qr/Everyone|Privileged/, 'got one group' );
$m->content_unlike( qr/Everyone.*?Privileged/, 'not 2 groups' );

RT::Test->stop_server;

diag "set groups limit to 2";

RT->Config->Set( MoreAboutRequestorGroupsLimit => 2 );
( $url, $m ) = RT::Test->started_ok;
ok( $m->login(), 'logged in as root' );
$m->goto_ticket($id);
$m->content_contains( 'Everyone', 'got the first group' );
$m->content_contains( 'Privileged', 'got the second group' );


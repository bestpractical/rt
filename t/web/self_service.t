use strict;
use warnings;

use RT::Test
  tests  => 17,
  config => 'Set( $ShowUnreadMessageNotifications, 1 );'
;

my ($url, $m) = RT::Test->started_ok;

my $user_a = RT::Test->load_or_create_user(
    Name         => 'user_a',
    Password     => 'password',
    EmailAddress => 'user_a@example.com',
    Privileged   => 0,
);
ok( $user_a && $user_a->id, 'loaded or created user' );
ok( ! $user_a->Privileged, 'user is not privileged' );

# Load Cc group
my $Cc = RT::System->RoleGroup( 'Cc' );
ok($Cc->id);
RT::Test->add_rights( { Principal => $Cc, Right => ['ShowTicket'] } );

my ($ticket) = RT::Test->create_ticket(
    Queue   => 'General',
    Subject => 'test subject',
    Cc      => 'user_a@example.com',
);

my @results = $ticket->Correspond( Content => 'sample correspondence' );

ok( $m->login('user_a' => 'password'), 'unprivileged user logged in' );

$m->get_ok( '/SelfService/Display.html?id=' . $ticket->id,
    'got selfservice display page' );

my $title = '#' . $ticket->id . ': test subject';
$m->title_is( $title );
$m->content_contains( "<h1>$title</h1>", "contains <h1>$title</h1>" );

# $ShowUnreadMessageNotifications tests:
$m->content_contains( "There are unread messages on this ticket." );

# mark the message as read
$m->follow_link_ok(
    { text => 'jump to the first unread message and mark all messages as seen' },
    'followed mark as seen link'
);

$m->content_contains( "<h1>$title</h1>", "contains <h1>$title</h1>" );
$m->content_lacks( "There are unread messages on this ticket." );

# TODO need more SelfService tests

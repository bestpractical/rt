#!/usr/bin/env perl
use strict;
use warnings;
use RT::Test tests => 19;

my $user_a = RT::Test->load_or_create_user(
    Name     => 'user_a',
    Password => 'password',
);

ok( $user_a && $user_a->id, 'created user_a' );
ok(
    RT::Test->add_rights(
        {
            Principal => $user_a,
            Right     => [
                qw/SeeQueue CreateTicket ShowTicket/
            ]
        },
    ),
    'add basic rights for user_a'
);

my $ticket = RT::Test->create_ticket(
    Subject => 'test reminder permission',
    Queue   => 'General',
);

ok( $ticket->id, 'created a ticket' );

my ($baseurl, $m) = RT::Test->started_ok;
ok($m->login( user_a => 'password'), 'logged in as user_a');

$m->goto_ticket($ticket->id);
$m->content_lacks('New reminder:', 'can not create a new reminder');
$m->follow_link_ok({id => 'page-reminders'});
$m->get_ok( $baseurl . '/Ticket/Reminders.html?id=' . $ticket->id );
$m->title_is("Reminders for ticket #" . $ticket->id);
$m->content_lacks('New reminder:', 'can not create a new reminder');

ok(
    RT::Test->add_rights(
        {
            Principal => $user_a,
            Right     => [
                qw/ModifyTicket/
            ]
        },
    ),
    'add basic rights for user_a'
);
$m->goto_ticket($ticket->id);
$m->content_contains('New reminder:', 'can create a new reminder');
$m->follow_link_ok({id => 'page-reminders'});
$m->title_is("Reminders for ticket #" . $ticket->id);
$m->content_contains('New reminder:', 'can create a new reminder');

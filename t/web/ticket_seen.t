#!/usr/bin/perl

use strict;
use warnings;

use RT::Test; use Test::More tests => 16;


my $queue = RT::Test->load_or_create_queue( name => 'Regression' );
ok $queue && $queue->id, 'loaded or created queue';

my $user_a = RT::Test->load_or_create_user(
    name => 'user_a', password => 'password',
);
ok $user_a && $user_a->id, 'loaded or created user';

my $user_b = RT::Test->load_or_create_user(
    name => 'user_b', password => 'password',
);
ok $user_b && $user_b->id, 'loaded or created user';

ok( RT::Test->set_rights(
    { Principal => $user_a, Right => [qw(SeeQueue ShowTicket create_ticket OwnTicket ModifyTicket)] },
    { Principal => $user_b, Right => [qw(SeeQueue ShowTicket ReplyToTicket)] },
), 'set rights');
RT::Test->started_ok;

my $agent_a = RT::Test::Web->new;
ok $agent_a->login('user_a', 'password'), 'logged in as user A';

my $agent_b = RT::Test::Web->new;
ok $agent_b->login('user_b', 'password'), 'logged in as user B';

diag "create a ticket for testing";
my $tid;
{
    my $ticket = RT::Model::Ticket->new(current_user => RT::CurrentUser->new(id =>$user_a->id) );
    my ($txn, $msg);
    ($tid, $txn, $msg) = $ticket->create(
        Queue => $queue->id,
        Owner => $user_a->id,
        subject => 'test',
    );
    ok $tid, 'created a ticket #'. $tid or diag "error: $msg";
    is $ticket->Owner, $user_a->id, 'correct owner';
}

diag "user B adds a message, we check that user A see notification and can clear it";
{
    my $ticket = RT::Model::Ticket->new( current_user => RT::CurrentUser->new(id =>$user_b) );
    $ticket->load( $tid );
    ok $ticket->id, 'loaded the ticket';

    my ($status, $msg) = $ticket->correspond( Content => 'bla-bla' );
    ok $status, 'added reply' or diag "error: $msg";

    $agent_a->goto_ticket($tid);
    $agent_a->content_like(qr/bla-bla/ims, 'the message on the page');

    $agent_a->content_like(
        qr/There are unread/ims,
        'we have not seen something'
    );

    $agent_a->follow_link_ok(text => 'mark them all as seen');
    $agent_a->content_like(
        qr/Marked all messages as seen/ims,
        'see success message'
    );

    $agent_a->goto_ticket($tid);
    $agent_a->content_unlike(
        qr/There are unread/ims,
        'we have seen everything, so no messages'
    );
}






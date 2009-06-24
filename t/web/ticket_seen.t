#!/usr/bin/perl

use strict;
use warnings;

use RT::Test tests => 16;

my $queue = RT::Test->load_or_create_queue( Name => 'Regression' );
ok $queue && $queue->id, 'loaded or created queue';

my $user_a = RT::Test->load_or_create_user(
    Name => 'user_a', Password => 'password',
);
ok $user_a && $user_a->id, 'loaded or created user';

my $user_b = RT::Test->load_or_create_user(
    Name => 'user_b', Password => 'password',
);
ok $user_b && $user_b->id, 'loaded or created user';

ok( RT::Test->set_rights(
    { Principal => $user_a, Right => [qw(SeeQueue ShowTicket CreateTicket OwnTicket ModifyTicket)] },
    { Principal => $user_b, Right => [qw(SeeQueue ShowTicket ReplyToTicket)] },
), 'set rights');
RT::Test->started_ok;

my $agent_a = RT::Test::Web->new;
ok $agent_a->login('user_a', 'password'), 'logged in as user A';

my $agent_b = RT::Test::Web->new;
ok $agent_b->login('user_b', 'password'), 'logged in as user B';

diag "create a ticket for testing" if $ENV{TEST_VERBOSE};
my $tid;
{
    my $ticket = RT::Ticket->new( $user_a );
    my ($txn, $msg);
    ($tid, $txn, $msg) = $ticket->Create(
        Queue => $queue->id,
        Owner => $user_a->id,
        Subject => 'test',
    );
    ok $tid, 'created a ticket #'. $tid or diag "error: $msg";
    is $ticket->Owner, $user_a->id, 'correct owner';
}

diag "user B adds a message, we check that user A see notification and can clear it" if $ENV{TEST_VERBOSE};
{
    my $ticket = RT::Ticket->new( $user_b );
    $ticket->Load( $tid );
    ok $ticket->id, 'loaded the ticket';

    my ($status, $msg) = $ticket->Correspond( Content => 'bla-bla' );
    ok $status, 'added reply' or diag "error: $msg";

    $agent_a->goto_ticket($tid);
    $agent_a->content_like(qr/bla-bla/ims, 'the message on the page');

    $agent_a->content_like(
        qr/unread message/ims,
        'we have not seen something'
    );

    $agent_a->follow_link_ok({text => 'jump to the first unread message and mark all messages as seen'}, 'try to mark all as seen');
    $agent_a->content_like(
        qr/Marked all messages as seen/ims,
        'see success message'
    );

    $agent_a->goto_ticket($tid);
    $agent_a->content_unlike(
        qr/unread message/ims,
        'we have seen everything, so no messages'
    );
}






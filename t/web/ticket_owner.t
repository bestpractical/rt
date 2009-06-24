#!/usr/bin/perl

use strict;
use warnings;

use RT::Test tests => 91;

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

RT::Test->started_ok;

ok( RT::Test->set_rights(
    { Principal => $user_a, Right => [qw(SeeQueue ShowTicket CreateTicket ReplyToTicket)] },
    { Principal => $user_b, Right => [qw(SeeQueue ShowTicket OwnTicket)] },
), 'set rights');

my $agent_a = RT::Test::Web->new;
ok $agent_a->login('user_a', 'password'), 'logged in as user A';

diag "current user has no right to own, nobody selected as owner on create" if $ENV{TEST_VERBOSE};
{
    $agent_a->get_ok('/', 'open home page');
    $agent_a->form_name('CreateTicketInQueue');
    $agent_a->select( 'Queue', $queue->id );
    $agent_a->submit;

    $agent_a->content_like(qr/Create a new ticket/i, 'opened create ticket page');
    my $form = $agent_a->form_name('TicketCreate');
    is $form->value('Owner'), $RT::Nobody->id, 'correct owner selected';
    ok !grep($_ == $user_a->id, $form->find_input('Owner')->possible_values),
        'user A can not own tickets';
    $agent_a->submit;

    $agent_a->content_like(qr/Ticket \d+ created in queue/i, 'created ticket');
    my ($id) = ($agent_a->content =~ /Ticket (\d+) created in queue/);
    ok $id, 'found id of the ticket';

    my $ticket = RT::Ticket->new( $RT::SystemUser );
    $ticket->Load( $id );
    ok $ticket->id, 'loaded the ticket';
    is $ticket->Owner, $RT::Nobody->id, 'correct owner';
}

diag "user can chose owner of a new ticket" if $ENV{TEST_VERBOSE};
{
    $agent_a->get_ok('/', 'open home page');
    $agent_a->form_name('CreateTicketInQueue');
    $agent_a->select( 'Queue', $queue->id );
    $agent_a->submit;

    $agent_a->content_like(qr/Create a new ticket/i, 'opened create ticket page');
    my $form = $agent_a->form_name('TicketCreate');
    is $form->value('Owner'), $RT::Nobody->id, 'correct owner selected';

    ok grep($_ == $user_b->id,  $form->find_input('Owner')->possible_values),
        'user B is listed as potential owner';
    $agent_a->select('Owner', $user_b->id);
    $agent_a->submit;

    $agent_a->content_like(qr/Ticket \d+ created in queue/i, 'created ticket');
    my ($id) = ($agent_a->content =~ /Ticket (\d+) created in queue/);
    ok $id, 'found id of the ticket';

    my $ticket = RT::Ticket->new( $RT::SystemUser );
    $ticket->Load( $id );
    ok $ticket->id, 'loaded the ticket';
    is $ticket->Owner, $user_b->id, 'correct owner';
}

my $agent_b = RT::Test::Web->new;
ok $agent_b->login('user_b', 'password'), 'logged in as user B';

diag "user A can not change owner after create" if $ENV{TEST_VERBOSE};
{
    my $ticket = RT::Ticket->new( $user_a );
    my ($id, $txn, $msg) = $ticket->Create(
        Queue => $queue->id,
        Owner => $user_b->id,
        Subject => 'test',
    );
    ok $id, 'created a ticket #'. $id or diag "error: $msg";
    is $ticket->Owner, $user_b->id, 'correct owner';

    # try the following group of tests twice with different agents(logins)
    my $test_cb = sub {
        my $agent = shift;
        $agent->goto_ticket( $id );
        $agent->follow_link_ok({text => 'Basics'}, 'Ticket -> Basics');
        my $form = $agent->form_number(3);
        is $form->value('Owner'), $user_b->id, 'correct owner selected';
        $agent->select('Owner', $RT::Nobody->id);
        $agent->submit;

        $agent->content_like(
            qr/Permission denied/i,
            'no way to change owner after create if you have no rights'
        );

        my $ticket = RT::Ticket->new( $RT::SystemUser );
        $ticket->Load( $id );
        ok $ticket->id, 'loaded the ticket';
        is $ticket->Owner, $user_b->id, 'correct owner';
    };

    $test_cb->($agent_a);
    diag "even owner(user B) can not change owner" if $ENV{TEST_VERBOSE};
    $test_cb->($agent_b);
}

diag "on reply correct owner is selected" if $ENV{TEST_VERBOSE};
{
    my $ticket = RT::Ticket->new( $user_a );
    my ($id, $txn, $msg) = $ticket->Create(
        Queue => $queue->id,
        Owner => $user_b->id,
        Subject => 'test',
    );
    ok $id, 'created a ticket #'. $id or diag "error: $msg";
    is $ticket->Owner, $user_b->id, 'correct owner';

    $agent_a->goto_ticket( $id );
    $agent_a->follow_link_ok({text => 'Reply'}, 'Ticket -> Basics');

    my $form = $agent_a->form_number(3);
    is $form->value('Owner'), '', 'empty value selected';
    $agent_a->submit;

    $ticket = RT::Ticket->new( $RT::SystemUser );
    $ticket->Load( $id );
    ok $ticket->id, 'loaded the ticket';
    is $ticket->Owner, $user_b->id, 'correct owner';
}

ok( RT::Test->set_rights(
    { Principal => $user_a, Right => [qw(SeeQueue ShowTicket CreateTicket OwnTicket)] },
    { Principal => $user_b, Right => [qw(SeeQueue ShowTicket OwnTicket)] },
), 'set rights');

diag "Couldn't take without coresponding right" if $ENV{TEST_VERBOSE};
{
    my $ticket = RT::Ticket->new( $user_a );
    my ($id, $txn, $msg) = $ticket->Create(
        Queue => $queue->id,
        Subject => 'test',
    );
    ok $id, 'created a ticket #'. $id or diag "error: $msg";
    is $ticket->Owner, $RT::Nobody->id, 'correct owner';

    $agent_a->goto_ticket( $id );
    ok !($agent_a->find_all_links( text => 'Take' ))[0],
        'no Take link';
    ok !($agent_a->find_all_links( text => 'Steal' ))[0],
        'no Steal link as well';
}

diag "Couldn't steal without coresponding right" if $ENV{TEST_VERBOSE};
{
    my $ticket = RT::Ticket->new( $user_a );
    my ($id, $txn, $msg) = $ticket->Create(
        Queue => $queue->id,
        Owner => $user_b->id,
        Subject => 'test',
    );
    ok $id, 'created a ticket #'. $id or diag "error: $msg";
    is $ticket->Owner, $user_b->id, 'correct owner';

    $agent_a->goto_ticket( $id );
    ok !($agent_a->find_all_links( text => 'Steal' ))[0],
        'no Steal link';
    ok !($agent_a->find_all_links( text => 'Take' ))[0],
        'no Take link as well';
}

ok( RT::Test->set_rights(
    { Principal => $user_a, Right => [qw(SeeQueue ShowTicket CreateTicket TakeTicket)] },
), 'set rights');

diag "TakeTicket require OwnTicket to work" if $ENV{TEST_VERBOSE};
{
    my $ticket = RT::Ticket->new( $user_a );
    my ($id, $txn, $msg) = $ticket->Create(
        Queue => $queue->id,
        Subject => 'test',
    );
    ok $id, 'created a ticket #'. $id or diag "error: $msg";
    is $ticket->Owner, $RT::Nobody->id, 'correct owner';

    $agent_a->goto_ticket( $id );
    ok !($agent_a->find_all_links( text => 'Take' ))[0],
        'no Take link';
    ok !($agent_a->find_all_links( text => 'Steal' ))[0],
        'no Steal link as well';
}

ok( RT::Test->set_rights(
    { Principal => $user_a, Right => [qw(SeeQueue ShowTicket CreateTicket OwnTicket TakeTicket)] },
    { Principal => $user_b, Right => [qw(SeeQueue ShowTicket OwnTicket)] },
), 'set rights');

diag "TakeTicket+OwnTicket work" if $ENV{TEST_VERBOSE};
{
    my $ticket = RT::Ticket->new( $user_a );
    my ($id, $txn, $msg) = $ticket->Create(
        Queue => $queue->id,
        Subject => 'test',
    );
    ok $id, 'created a ticket #'. $id or diag "error: $msg";
    is $ticket->Owner, $RT::Nobody->id, 'correct owner';

    $agent_a->goto_ticket( $id );
    ok !($agent_a->find_all_links( text => 'Steal' ))[0],
        'no Steal link';
    $agent_a->follow_link_ok({text => 'Take'}, 'Ticket -> Take');

    $ticket = RT::Ticket->new( $RT::SystemUser );
    $ticket->Load( $id );
    ok $ticket->id, 'loaded the ticket';
    is $ticket->Owner, $user_a->id, 'correct owner';
}

diag "TakeTicket+OwnTicket don't work when owner is not nobody" if $ENV{TEST_VERBOSE};
{
    my $ticket = RT::Ticket->new( $user_a );
    my ($id, $txn, $msg) = $ticket->Create(
        Queue => $queue->id,
        Owner => $user_b->id,
        Subject => 'test',
    );
    ok $id, 'created a ticket #'. $id or diag "error: $msg";
    is $ticket->Owner, $user_b->id, 'correct owner';

    $agent_a->goto_ticket( $id );
    ok !($agent_a->find_all_links( text => 'Take' ))[0],
        'no Take link';
    ok !($agent_a->find_all_links( text => 'Steal' ))[0],
        'no Steal link too';
}

ok( RT::Test->set_rights(
    { Principal => $user_a, Right => [qw(SeeQueue ShowTicket CreateTicket StealTicket)] },
    { Principal => $user_b, Right => [qw(SeeQueue ShowTicket OwnTicket)] },
), 'set rights');

diag "StealTicket require OwnTicket to work" if $ENV{TEST_VERBOSE};
{
    my $ticket = RT::Ticket->new( $user_a );
    my ($id, $txn, $msg) = $ticket->Create(
        Queue => $queue->id,
        Owner => $user_b->id,
        Subject => 'test',
    );
    ok $id, 'created a ticket #'. $id or diag "error: $msg";
    is $ticket->Owner, $user_b->id, 'correct owner';

    $agent_a->goto_ticket( $id );
    ok !($agent_a->find_all_links( text => 'Steal' ))[0],
        'no Steal link';
    ok !($agent_a->find_all_links( text => 'Take' ))[0],
        'no Take link too';
}

ok( RT::Test->set_rights(
    { Principal => $user_a, Right => [qw(SeeQueue ShowTicket CreateTicket OwnTicket StealTicket)] },
    { Principal => $user_b, Right => [qw(SeeQueue ShowTicket OwnTicket)] },
), 'set rights');

diag "StealTicket+OwnTicket work" if $ENV{TEST_VERBOSE};
{
    my $ticket = RT::Ticket->new( $user_a );
    my ($id, $txn, $msg) = $ticket->Create(
        Queue => $queue->id,
        Owner => $user_b->id,
        Subject => 'test',
    );
    ok $id, 'created a ticket #'. $id or diag "error: $msg";
    is $ticket->Owner, $user_b->id, 'correct owner';

    $agent_a->goto_ticket( $id );
    ok !($agent_a->find_all_links( text => 'Take' ))[0],
        'but no Take link';
    $agent_a->follow_link_ok({text => 'Steal'}, 'Ticket -> Steal');

    $ticket = RT::Ticket->new( $RT::SystemUser );
    $ticket->Load( $id );
    ok $ticket->id, 'loaded the ticket';
    is $ticket->Owner, $user_a->id, 'correct owner';
}

diag "StealTicket+OwnTicket don't work when owner is nobody" if $ENV{TEST_VERBOSE};
{
    my $ticket = RT::Ticket->new( $user_a );
    my ($id, $txn, $msg) = $ticket->Create(
        Queue => $queue->id,
        Subject => 'test',
    );
    ok $id, 'created a ticket #'. $id or diag "error: $msg";
    is $ticket->Owner, $RT::Nobody->id, 'correct owner';

    $agent_a->goto_ticket( $id );
    ok !($agent_a->find_all_links( text => 'Steal' ))[0],
        'no Steal link';
    ok !($agent_a->find_all_links( text => 'Take' ))[0],
        'no Take link as well (no right)';
}

ok( RT::Test->set_rights(
    { Principal => $user_a, Right => [qw(SeeQueue ShowTicket CreateTicket OwnTicket TakeTicket StealTicket)] },
    { Principal => $user_b, Right => [qw(SeeQueue ShowTicket OwnTicket)] },
), 'set rights');

diag "no Steal link when owner nobody" if $ENV{TEST_VERBOSE};
{
    my $ticket = RT::Ticket->new( $user_a );
    my ($id, $txn, $msg) = $ticket->Create(
        Queue => $queue->id,
        Subject => 'test',
    );
    ok $id, 'created a ticket #'. $id or diag "error: $msg";
    is $ticket->Owner, $RT::Nobody->id, 'correct owner';

    $agent_a->goto_ticket( $id );
    ok !($agent_a->find_all_links( text => 'Steal' ))[0],
        'no Steal link';
    ok( ($agent_a->find_all_links( text => 'Take' ))[0],
        'but have Take link');
}

diag "no Take link when owner is not nobody" if $ENV{TEST_VERBOSE};
{
    my $ticket = RT::Ticket->new( $user_a );
    my ($id, $txn, $msg) = $ticket->Create(
        Queue => $queue->id,
        Owner => $user_b->id,
        Subject => 'test',
    );
    ok $id, 'created a ticket #'. $id or diag "error: $msg";
    is $ticket->Owner, $user_b->id, 'correct owner';

    $agent_a->goto_ticket( $id );
    ok !($agent_a->find_all_links( text => 'Take' ))[0],
        'no Take link';
    ok( ($agent_a->find_all_links( text => 'Steal' ))[0],
        'but have Steal link');
}


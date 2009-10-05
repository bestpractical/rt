#!/usr/bin/perl

use strict;
use warnings;

use RT::Test tests => 14;

$RT::Test::SKIP_REQUEST_WORK_AROUND = 1;

use Encode;

my $ru_test = "\x{442}\x{435}\x{441}\x{442}";
my $ru_autoreply = "\x{410}\x{432}\x{442}\x{43e}\x{43e}\x{442}\x{432}\x{435}\x{442}";
my $ru_support = "\x{43f}\x{43e}\x{434}\x{434}\x{435}\x{440}\x{436}\x{43a}\x{430}";

my $q = RT::Test->load_or_create_queue( Name => 'Regression' );
ok $q && $q->id, 'loaded or created queue';

RT::Test->set_rights(
    Principal => 'Everyone',
    Right => ['CreateTicket', 'ShowTicket', 'SeeQueue', 'ReplyToTicket', 'ModifyTicket'],
);

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in';

# create a ticket with a subject only
{
    ok $m->goto_create_ticket( $q ), "go to create ticket";
    $m->form_number(3);
    $m->field( Subject => $ru_test );
    $m->submit;

    $m->content_like( 
        qr{<td\s+class="message-header-value"[^>]*>\s*\Q$ru_test\E\s*</td>}i,
        'header on the page'
    );

    my $ticket = RT::Test->last_ticket;
    is $ticket->Subject, $ru_test, "correct subject";
}

# create a ticket with a subject and content
{
    ok $m->goto_create_ticket( $q ), "go to create ticket";
    $m->form_number(3);
    $m->field( Subject => $ru_test );
    $m->field( Content => $ru_support );
    $m->submit;

    $m->content_like( 
        qr{<td\s+class="message-header-value"[^>]*>\s*\Q$ru_test\E\s*</td>}i,
        'header on the page'
    );
    $m->content_like( 
        qr{\Q$ru_support\E}i,
        'content on the page'
    );

    my $ticket = RT::Test->last_ticket;
    is $ticket->Subject, $ru_test, "correct subject";
}

# create a ticket with a subject and content
{
    ok $m->goto_create_ticket( $q ), "go to create ticket";
    $m->form_number(3);
    $m->field( Subject => $ru_test );
    $m->field( Content => $ru_support );
    $m->submit;

    $m->content_like( 
        qr{<td\s+class="message-header-value"[^>]*>\s*\Q$ru_test\E\s*</td>}i,
        'header on the page'
    );
    $m->content_like( 
        qr{\Q$ru_support\E}i,
        'content on the page'
    );

    my $ticket = RT::Test->last_ticket;
    is $ticket->Subject, $ru_test, "correct subject";
}

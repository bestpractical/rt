use strict;
use warnings;
use utf8;

use RT::Test tests => undef;

my ($base, $m) = RT::Test->started_ok;
ok $m->login, 'logged in';

my @tickets;

diag "create a ticket via the API";
{
    my $ticket = RT::Ticket->new( RT->SystemUser );
    my ($id, $txn, $msg) = $ticket->Create(
        Queue => 'General',
        Subject => 'bad subject‽',
    );
    ok $id, 'created a ticket #'. $id or diag "error: $msg";
    is $ticket->Subject, 'bad subject‽', 'correct subject';
    push @tickets, $id;
}

diag "create a ticket via the web";
{
    $m->submit_form_ok({
        form_name => "CreateTicketInQueue",
        fields    => { Queue => 1 },
    }, 'create ticket in Queue');
    $m->submit_form_ok({
        with_fields => {
            Subject => 'bad subject #2‽',
        },
    }, 'create ticket');
    $m->content_contains('bad subject #2‽', 'correct subject');
    push @tickets, 2;
}

diag "create a ticket via the web without a unicode subject";
{
    $m->submit_form_ok({
        with_fields => { Queue => 1 },
    }, 'create ticket in Queue');
    $m->submit_form_ok({
        with_fields => {
            Subject => 'a fine subject #3',
        },
    }, 'create ticket');
    $m->content_contains('a fine subject #3', 'correct subject');
    push @tickets, 3;
}

for my $tid (@tickets) {
    diag "ticket #$tid";
    diag "add a reply which adds to the subject, but without an attachment";
    {
        $m->goto_ticket($tid);
        $m->follow_link_ok({ id => 'page-actions-reply' }, "Actions -> Reply");
        $m->submit_form_ok({
            with_fields => {
                UpdateSubject => 'bad subject‽ without attachment',
                UpdateContent => 'testing unicode txn subjects',
            },
            button => 'SubmitTicket',
        }, 'submit reply');
        $m->content_contains('bad subject‽ without attachment', "found txn subject");
    }

    diag "add a reply which adds to the subject with an attachment";
    {
        $m->goto_ticket($tid);
        $m->follow_link_ok({ id => 'page-actions-reply' }, "Actions -> Reply");
        $m->submit_form_ok({
            with_fields => {
                UpdateSubject => 'bad subject‽ with attachment',
                UpdateContent => 'testing unicode txn subjects',
                Attach => RT::Test::get_relocatable_file('bpslogo.png', '..', 'data'),
            },
            button => 'SubmitTicket',
        }, 'submit reply');
        $m->content_contains('bad subject‽ with attachment', "found txn subject");
    }
}

undef $m;
done_testing;

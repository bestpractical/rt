use strict;
use warnings;

use RT::Test tests => undef;

my ($base, $m) = RT::Test->started_ok;
ok $m->login, 'logged in';

my @tickets;

diag "create a ticket via the API";
{
    my $ticket = RT::Ticket->new( RT->SystemUser );
    my ($id, $txn, $msg) = $ticket->Create(
        Queue => 'General',
        Subject => Encode::decode("UTF-8",'bad subject‽'),
    );
    ok $id, 'created a ticket #'. $id or diag "error: $msg";
    is $ticket->Subject, Encode::decode("UTF-8",'bad subject‽'), 'correct subject';
    push @tickets, $id;
}

diag "create a ticket via the web";
{
    $m->get_ok('/Ticket/Create.html?Queue=1', 'open ticket create page');
    $m->submit_form_ok({
        with_fields => {
            Subject => Encode::decode("UTF-8",'bad subject #2‽'),
        },
        button => 'SubmitTicket'
    }, 'create ticket');
    $m->content_contains(Encode::decode("UTF-8",'bad subject #2‽'), 'correct subject');
    push @tickets, 2;
}

diag "create a ticket via the web without a unicode subject";
{
    $m->get_ok('/Ticket/Create.html?Queue=1', 'open ticket create page');
    $m->submit_form_ok({
        with_fields => {
            Subject => 'a fine subject #3',
        },
        button => 'SubmitTicket'
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
                UpdateSubject => Encode::decode("UTF-8",'bad subject‽ without attachment'),
                UpdateContent => 'testing unicode txn subjects',
            },
            button => 'SubmitTicket',
        }, 'submit reply');
        $m->content_contains(Encode::decode("UTF-8",'bad subject‽ without attachment'), "found txn subject");
    }

    diag "add a reply which adds to the subject with an attachment";
    {
        $m->goto_ticket($tid);
        $m->follow_link_ok({ id => 'page-actions-reply' }, "Actions -> Reply");
        $m->submit_form_ok({
            with_fields => {
                UpdateSubject => Encode::decode("UTF-8",'bad subject‽ with attachment'),
                UpdateContent => 'testing unicode txn subjects',
                Attach => RT::Test::get_relocatable_file('bpslogo.png', '..', 'data'),
            },
            button => 'SubmitTicket',
        }, 'submit reply');
        $m->content_contains(Encode::decode("UTF-8",'bad subject‽ with attachment'), "found txn subject");
    }
}

done_testing;

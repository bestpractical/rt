
use strict;
use warnings;

use RT::Test tests => 43;

my $ru_test = "\x{442}\x{435}\x{441}\x{442}";
my $ru_support = "\x{43f}\x{43e}\x{434}\x{434}\x{435}\x{440}\x{436}\x{43a}\x{430}";

# latin-1 is very special in perl, we should test everything with latin-1 umlauts
# and not-ascii+not-latin1, for example cyrillic
my $l1_test = Encode::decode('latin-1', "t\xE9st");
my $l1_support = Encode::decode('latin-1', "supp\xF6rt");


my $q = RT::Test->load_or_create_queue( Name => 'Regression' );
ok $q && $q->id, 'loaded or created queue';

RT::Test->set_rights(
    Principal => 'Everyone',
    Right => ['CreateTicket', 'ShowTicket', 'SeeQueue', 'ReplyToTicket', 'ModifyTicket'],
);

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in';

# create a ticket with a subject only
foreach my $test_str ( $ru_test, $l1_test ) {
    ok $m->goto_create_ticket( $q ), "go to create ticket";
    $m->form_name('TicketCreate');
    $m->field( Subject => $test_str );
    $m->submit;

    $m->content_like( 
        qr{<td\s+class="message-header-value\s*"[^>]*>\s*\Q$test_str\E\s*</td>}i,
        'header on the page'
    );

    my $ticket = RT::Test->last_ticket;
    is $ticket->Subject, $test_str, "correct subject";
}

# create a ticket with a subject and content
foreach my $test_str ( $ru_test, $l1_test ) {
    foreach my $support_str ( $ru_support, $l1_support ) {
        ok $m->goto_create_ticket( $q ), "go to create ticket";
        $m->form_name('TicketCreate');
        $m->field( Subject => $test_str );
        $m->field( Content => $support_str );
        $m->submit;

        $m->content_like( 
            qr{<td\s+class="message-header-value\s*"[^>]*>\s*\Q$test_str\E\s*</td>}i,
            'header on the page'
        );
        $m->content_contains(
            $support_str,
            'content on the page'
        );

        my $ticket = RT::Test->last_ticket;
        is $ticket->Subject, $test_str, "correct subject";
    }
}

# create a ticket with a subject and content
foreach my $test_str ( $ru_test, $l1_test ) {
    foreach my $support_str ( $ru_support, $l1_support ) {
        ok $m->goto_create_ticket( $q ), "go to create ticket";
        $m->form_name('TicketCreate');
        $m->field( Subject => $test_str );
        $m->field( Content => $support_str );
        $m->submit;

        $m->content_like( 
            qr{<td\s+class="message-header-value\s*"[^>]*>\s*\Q$test_str\E\s*</td>}i,
            'header on the page'
        );
        $m->content_contains(
            $support_str,
            'content on the page'
        );

        my $ticket = RT::Test->last_ticket;
        is $ticket->Subject, $test_str, "correct subject";
    }
}


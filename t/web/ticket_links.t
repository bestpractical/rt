use strict;
use warnings;
use RT::Test tests => 152;

my ( $baseurl, $m ) = RT::Test->started_ok;
ok( $m->login, "Logged in" );

my $queue = RT::Test->load_or_create_queue( Name => 'General' );
ok( $queue->id, "loaded the General queue" );

# Create a new queue
my $queue_2 = RT::Test->load_or_create_queue( Name => 'NewQueue');
ok( $queue_2->id, "New queue created, 'NewQueue'");

# Create a new ticket
$m->get_ok($baseurl . '/Ticket/Create.html?Queue=1');
$m->form_name('TicketCreate');
$m->field(Subject => 'testing new ticket');
$m->click_button(value => 'Create');

# Set NewQueue as default queue
$m->get_ok($baseurl . '/Prefs/Other.html');
$m->submit_form_ok({
  form_name => 'ModifyPreferences',
  fields => {
    DefaultQueue => 'NewQueue',
  },
  button => 'Update'
}, 'NewQueue set as default queue');

# Verify NewQueue is the default queue on ticket page
$m->get_ok($baseurl . '/Ticket/Display.html?id=1');
my $selected_queue_node = $m->dom->at('select[name=CloneQueue] option:checked');
if ($selected_queue_node) {
    is($selected_queue_node->all_text, 'NewQueue');
}
else {
    fail("no selected queue for clone queue");
}

my ( $deleted, $active, $inactive ) = RT::Test->create_tickets(
    { Queue   => 'General' },
    { Subject => 'deleted ticket', },
    { Subject => 'active ticket', },
    { Subject => 'inactive ticket', }
);

my ( $deleted_id, $active_id, $inactive_id ) =
  ( $deleted->id, $active->id, $inactive->id );

$deleted->SetStatus('deleted');
is( $deleted->Status, 'deleted', "deleted $deleted_id" );

$inactive->SetStatus('resolved');
is( $inactive->Status, 'resolved', 'resolved $inactive_id' );

# Create an article for linking
require RT::Class;
my $class = RT::Class->new($RT::SystemUser);
$class->Create(Name => 'test class');

require RT::Article;
my $article = RT::Article->new($RT::SystemUser);

$article->Create(Class => $class->Id, Name => 'test article');

for my $type ( "DependsOn", "MemberOf", "RefersTo" ) {
    for my $c (qw/base target/) {
        my $id;

        diag "create ticket with links of type $type $c";
        {
            ok( $m->goto_create_ticket($queue), "go to create ticket" );
            $m->form_name('TicketCreate');
            $m->field( Subject => "test ticket creation with $type $c" );
            if ( $c eq 'base' ) {
                $m->field( "new-$type", "$deleted_id $active_id $inactive_id" );
            }
            else {
                $m->field( "$type-new", "$deleted_id $active_id $inactive_id" );
            }

            $m->submit;
            $m->content_like(qr/Ticket \d+ created/, 'created ticket');
            $m->content_contains("Linking to a deleted ticket is not allowed");
            $id = RT::Test->last_ticket->id;
        }

        diag "add ticket links of type $type $c";
        {
            my $ticket = RT::Test->create_ticket(
                Queue   => 'General',
                Subject => "test $type $c",
            );
            $id = $ticket->id;

            $m->goto_ticket($id);
            $m->follow_link_ok( { text => 'Links' }, "Followed link to Links" );

            ok( $m->form_with_fields("$id-DependsOn"), "found the form" );
            if ( $c eq 'base' ) {
                $m->field( "$id-$type", "$deleted_id $active_id $inactive_id" );
            }
            else {
                $m->field( "$type-$id", "$deleted_id $active_id $inactive_id" );
            }
            $m->submit;
            $m->content_contains("Linking to a deleted ticket is not allowed");

            if ( $c eq 'base' ) {
                $m->content_like(
                    qr{"DeleteLink--$type-.*?ticket/$active_id"},
                    "$c for $type: has active ticket",
                );
                $m->content_like(
                    qr{"DeleteLink--$type-.*?ticket/$inactive_id"},
                    "base for $type: has inactive ticket",
                );
                $m->content_unlike(
                    qr{"DeleteLink--$type-.*?ticket/$deleted_id"},
                    "base for $type: no deleted ticket",
                );
            }
            else {
                $m->content_like(
                    qr{"DeleteLink-.*?ticket/$active_id-$type-"},
                    "$c for $type: has active ticket",
                );
                $m->content_like(
                    qr{"DeleteLink-.*?ticket/$inactive_id-$type-"},
                    "base for $type: has inactive ticket",
                );
                $m->content_unlike(
                    qr{"DeleteLink-.*?ticket/$deleted_id-$type-"},
                    "base for $type: no deleted ticket",
                );
            }
        }

        $m->goto_ticket($id);
        $m->content_like( qr{$active_id:.*?\[new\]}, "has active ticket", );
        $m->content_like(
            qr{$inactive_id:.*?\[resolved\]},
            "has inactive ticket",
        );
        $m->content_unlike( qr{$deleted_id.*?\[deleted\]}, "no deleted ticket",
        );

        diag "[$type]: Testing that reminders don't get copied for $c tickets";
        {
            my $ticket = RT::Test->create_ticket(
                Subject => 'test ticket',
                Queue   => 1,
            );

            $m->goto_ticket($ticket->Id);
            $m->form_name('UpdateReminders');
            $m->field('NewReminder-Subject' => 'hello test reminder subject');
            $m->click_button(value => 'Save');
            $m->text_contains('hello test reminder subject');

            my $id = $ticket->Id;
            my $type_value = my $link_field = $type;
            if ($c eq 'base') {
                $type_value = "new-$type_value";
                $link_field    = "$link_field-$id";
            }
            else {
                $type_value = "$type_value-new";
                $link_field = "$id-$link_field";
            }

            if ($type eq 'RefersTo') {
                $m->goto_ticket($ticket->Id);
                $m->follow_link(id => 'page-links');

                # add $baseurl as a link
                $m->form_name('ModifyLinks');
                $m->field($link_field => "$baseurl/test_ticket_reference");
                $m->click('SubmitTicket');

                # add an article as a link
                $m->form_name('ModifyLinks');
                $m->field($link_field => 'a:' . $article->Id);
                $m->click('SubmitTicket');
            }

            my $depends_on_url = sprintf(
                '%s/Ticket/Create.html?Queue=%s&CloneTicket=%s&%s=%s',
                $baseurl, '1', $id, $type_value, $id,
            );
            $m->get_ok($depends_on_url);
            $m->form_name('TicketCreate');
            $m->click_button(value => 'Create');
            $m->content_lacks('hello test reminder subject');
            if ($type eq 'RefersTo') {
                $m->text_contains("$baseurl/test_ticket_reference");
                $m->text_contains("Article #" . $article->Id . ': test article');
            }
        }
    }
}


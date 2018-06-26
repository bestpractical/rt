use strict;
use warnings;
use RT::Test tests => 45;

my ($baseurl, $m) = RT::Test->started_ok;

ok($m->login, 'logged in');
my $user = RT::CurrentUser->new('root');

my $ticket = RT::Ticket->new($user);
$ticket->Create(Subject => 'testing reminders!', Queue => 'General');
ok($ticket->id, 'created a ticket');

$m->goto_ticket($ticket->id);
$m->text_contains('New reminder:', 'can create a new reminder');
$m->content_unlike(qr{Check box to complete}, "we don't display this text when there are no reminders");
$m->content_unlike(qr{<th[^>]*>Reminders?</th>}, "no reminder titlebar");

$m->follow_link_ok({id => 'page-reminders'});
$m->title_is("Reminders for ticket #" . $ticket->id . ": " . $ticket->Subject);
$m->text_contains('New reminder:', 'can create a new reminder');
$m->content_unlike(qr{Check box to complete}, "we don't display this text when there are no reminders");
$m->content_unlike(qr{<th[^>]*>Reminders?</th>}, "no reminder titlebar");

$m->goto_ticket($ticket->id);
$m->form_name('UpdateReminders');
$m->field( 'NewReminder-Subject' => "baby's first reminder" );
$m->submit;
$m->content_contains("Reminder &#39;baby&#39;s first reminder&#39;: Created");

$ticket->SetStatus('deleted');
is( $ticket->Status, 'deleted', 'deleted ticket' );
$m->form_name('UpdateReminders');
$m->field( 'NewReminder-Subject' => "link to a deleted ticket" );
$m->submit;
$m->content_contains("Can&#39;t link to a deleted ticket");
$m->get_ok('/Tools/MyReminders.html');
$m->content_contains( "baby&#39;s first reminder",
    'got the reminder even the ticket is deleted' );

$m->goto_ticket( $ticket->id );
$m->content_lacks('New reminder:', "can't create a new reminder");
$m->text_contains('Check box to complete', "we DO display this text when there are reminders");
$m->content_like(qr{<th[^>]*>Reminders?</th>}, "now we have a reminder titlebar");
$m->text_contains("baby's first reminder", "display the reminder's subject");

my $reminders = RT::Reminders->new($user);
$reminders->Ticket($ticket->id);
my $col = $reminders->Collection;
is($col->Count, 1, 'got a reminder');
my $reminder = $col->First;
is($reminder->Subject, "baby's first reminder");
my $reminder_id = $reminder->id;
is($reminder->Status, 'open');

$ticket->SetStatus('open');
is( $ticket->Status, 'open', 'changed back to new' );

$m->goto_ticket($ticket->id);
$m->text_contains('New reminder:', "can create a new reminder");
$m->text_contains('Check box to complete', "we DO display this text when there are reminders");
$m->content_like(qr{<th[^>]*>Reminders?</th>}, "now we have a reminder titlebar");
$m->text_contains("baby's first reminder", "display the reminder's subject");

$m->follow_link_ok({id => 'page-reminders'});
$m->title_is("Reminders for ticket #" . $ticket->id . ": " . $ticket->Subject);
$m->form_name('UpdateReminders');
$m->field("Reminder-Subject-$reminder_id" => "changed the subject");
$m->submit;

$reminder = RT::Ticket->new($user);
$reminder->Load($reminder_id);
is($reminder->Subject, 'changed the subject');
is($reminder->Status, 'open');

$m->goto_ticket($ticket->id);
$m->form_name('UpdateReminders');
$m->tick("Complete-Reminder-$reminder_id" => 1);
$m->submit;

$reminder = RT::Ticket->new($user);
$reminder->Load($reminder_id);
is($reminder->Status, 'resolved');

$m->text_contains('New reminder:', 'can create a new reminder');
$m->content_unlike(qr{Check box to complete}, "we don't display this text when there are open reminders");
$m->content_unlike(qr{<th[^>]*>Reminders?</th>}, "no reminder titlebar");
$m->content_unlike(qr{baby's first reminder}, "we don't display resolved reminders");

$m->follow_link_ok({id => 'page-reminders'});
$m->title_is("Reminders for ticket #" . $ticket->id . ": " . $ticket->Subject);
$m->text_contains('New reminder:', 'can create a new reminder');
$m->text_contains('Check box to complete', "we DO display this text when there are reminders");
$m->content_contains("changed the subject", "display the resolved reminder's subject");

# make sure that when we submit the form, it doesn't accidentally reopen
# resolved reminders
$m->goto_ticket($ticket->id);
$m->form_name('UpdateReminders');
$m->submit;

$reminder = RT::Ticket->new($user);
$reminder->Load($reminder_id);
is($reminder->Status, 'resolved');


#!/usr/bin/env perl
use strict;
use warnings;
use RT::Test tests => 24;

my ($baseurl, $m) = RT::Test->started_ok;

ok($m->login, 'logged in');
my $user = RT::CurrentUser->new('root');

my $ticket = RT::Ticket->new($user);
$ticket->Create(Subject => 'testing reminders!', Queue => 'General');
ok($ticket->id, 'created a ticket');

$m->goto_ticket($ticket->id);
$m->text_contains('New reminder:', 'can create a new reminder');
$m->content_unlike(qr{Check box to complete}, "we don't display this text when there are no reminders");
TODO: {
    local $TODO = "we display the reminder titlebar even though we have no reminders";
    $m->content_unlike(qr{<th[^>]*>Reminder</th>}, "no reminder titlebar");
}

$m->form_name('UpdateReminders');
$m->field( 'NewReminder-Subject' => "baby's first reminder" );
$m->submit;

my $reminders = RT::Reminders->new($user);
$reminders->Ticket($ticket->id);
my $col = $reminders->Collection;
is($col->Count, 1, 'got a reminder');
my $reminder = $col->First;
is($reminder->Subject, "baby's first reminder");
my $reminder_id = $reminder->id;
is($reminder->Status, 'new');

$m->text_contains('New reminder:', 'can create a new reminder');
$m->text_contains('Check box to complete', "we DO display this text when there are reminders");
$m->content_like(qr{<th[^>]*>Reminder</th>}, "now we have a reminder titlebar");
$m->text_contains("baby's first reminder", "display the reminder's subject");

$m->follow_link_ok({id => 'page-reminders'});
$m->title_is("Reminders for ticket #" . $ticket->id);
$m->form_name('UpdateReminders');
$m->field("Reminder-Subject-$reminder_id" => "changed the subject");
$m->submit;

DBIx::SearchBuilder::Record::Cachable->FlushCache;
$reminder = RT::Ticket->new($user);
$reminder->Load($reminder_id);
is($reminder->Subject, 'changed the subject');
is($reminder->Status, 'new');

$m->goto_ticket($ticket->id);

$m->form_name('UpdateReminders');
$m->tick("Complete-Reminder-$reminder_id" => 1);
$m->submit;

DBIx::SearchBuilder::Record::Cachable->FlushCache;
$reminder = RT::Ticket->new($user);
$reminder->Load($reminder_id);
is($reminder->Status, 'resolved');

$m->text_contains('New reminder:', 'can create a new reminder');
$m->content_unlike(qr{Check box to complete}, "we don't display this text when there are open reminders");
TODO: {
    local $TODO = "we display the reminder titlebar even though we have no open reminders";
    $m->content_unlike(qr{<th[^>]*>Reminder</th>}, "no reminder titlebar");
}
$m->content_unlike(qr{baby's first reminder}, "we don't display resolved reminders");


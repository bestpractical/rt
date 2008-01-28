#!/usr/bin/perl -w

use strict;
use RT::Test; use Test::More; 
plan tests => 22;

use RT;


### Set up some testing data.  Test the testing data because why not?

# Create a user with rights, a queue, and some tickets.
my $user_obj = RT::Model::User->new(current_user => RT->system_user);
my ($ret, $msg) = $user_obj->load_or_create_by_email('tara@example.com');
ok($ret, 'record test user creation');
($ret,$msg) =$user_obj->set_name('tara');
ok($ret,$msg);
($ret,$msg) =$user_obj->principal_object->grant_right(Right => 'SuperUser');
ok($ret,$msg);
my $CurrentUser = RT::CurrentUser->new(name => 'tara');
is($user_obj->name,'tara');
is ($user_obj->id, $CurrentUser->id);

# Create our template, which will be used for tests of RT::ScripAction::Record*.

my $template_content = 'RT-Send-Cc: tla@example.com
RT-Send-Bcc: jesse@example.com

This is a content string with no content.';

my $template_obj = RT::Model::Template->new(current_user => RT->system_user);
$template_obj->create(Queue       => '0',
		      name        => 'recordtest',
		      Description => 'testing Record actions',
		      Content     => $template_content,
		     );

# Create a queue and some tickets.

my $queue_obj = RT::Model::Queue->new(current_user => RT->system_user);
($ret, $msg) = $queue_obj->create(name => 'recordtest', Description => 'queue for Action::Record testing');
ok($ret, 'record test queue creation');

my $ticket1 = RT::Model::Ticket->new(current_user => RT->system_user);
my ($id, $tobj, $msg2) = $ticket1->create(Queue    => $queue_obj,
					 Requestor => ['tara@example.com'],
					 Subject   => 'bork bork bork',
					 Priority  => 22,
					);
ok($id, 'record test ticket creation 1');
my $ticket2 = RT::Model::Ticket->new(current_user => RT->system_user);
($id, $tobj, $msg2) = $ticket2->create(Queue     => $queue_obj,
				      Requestor => ['root@localhost'],
				      Subject   => 'hurdy gurdy'
				      );
ok($id, 'record test ticket creation 2');


### OK.  Have data, will travel.

# First test the search.

ok( require RT::Search::FromSQL, "Search::FromSQL loaded" );
my $ticketsqlstr
    = "Requestor.email = '" . $CurrentUser->email . "' AND Priority > '20'";
my $search = RT::Search::FromSQL->new(
    Argument => $ticketsqlstr,
    TicketsObj => RT::Model::TicketCollection->new( current_user => RT->system_user ),
);
is(ref($search), 'RT::Search::FromSQL', "search Created");
ok($search->prepare(), "from_sql search run");
my $counter = 0;
while(my $t = $search->TicketsObj->next() ) {
    is($t->id(), $ticket1->id(), "from_sql search results 1");
    $counter++;
}
is ($counter, 1, "from_sql search results 2");

# Right.  Now test the actions.

ok(require RT::ScripAction::RecordComment);
ok(require RT::ScripAction::RecordCorrespondence);

my ($comment_act, $correspond_act);
ok($comment_act = RT::ScripAction::RecordComment->new(ticket_obj => $ticket1, template_obj => $template_obj, CurrentUser => $CurrentUser), "RecordComment Created");
ok($correspond_act = RT::ScripAction::RecordCorrespondence->new(ticket_obj => $ticket2, template_obj => $template_obj, CurrentUser => $CurrentUser), "RecordCorrespondence Created");
ok($comment_act->prepare(), "comment prepared");
ok($correspond_act->prepare(), "Correspond prepared");
ok($comment_act->commit(), "comment committed");
ok($correspond_act->commit(), "Correspondence committed");

# Now test for loop suppression.
my ($trans, $desc, $transaction) = $ticket2->comment(MIMEObj => $template_obj->MIMEObj);
my $bogus_action = RT::ScripAction::RecordComment->new(ticket_obj => $ticket1, template_obj => $template_obj, transaction_obj => $transaction, CurrentUser => $CurrentUser);
ok(!$bogus_action->prepare(), "comment aborted to prevent loop");

1;

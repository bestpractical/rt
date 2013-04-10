use strict;
use warnings;

use RT;
use RT::Test nodata => 1, tests => 18;


### Set up some testing data.  Test the testing data because why not?

# Create a user with rights, a queue, and some tickets.
my $user_obj = RT::User->new(RT->SystemUser);
my ($ret, $msg) = $user_obj->LoadOrCreateByEmail('tara@example.com');
ok($ret, 'record test user creation');
$user_obj->SetName('tara');
$user_obj->PrincipalObj->GrantRight(Right => 'SuperUser');
my $CurrentUser = RT::CurrentUser->new('tara');

# Create our template, which will be used for tests of RT::Action::Record*.

my $template_content = 'RT-Send-Cc: tla@example.com
RT-Send-Bcc: jesse@example.com

This is a content string with no content.';

my $template_obj = RT::Template->new($CurrentUser);
$template_obj->Create(Queue       => '0',
                      Name        => 'recordtest',
                      Description => 'testing Record actions',
                      Content     => $template_content,
                     );

# Create a queue and some tickets.

my $queue_obj = RT::Queue->new($CurrentUser);
($ret, $msg) = $queue_obj->Create(Name => 'recordtest', Description => 'queue for Action::Record testing');
ok($ret, 'record test queue creation');

my $ticket1 = RT::Ticket->new($CurrentUser);
my ($id, $tobj, $msg2) = $ticket1->Create(Queue     => $queue_obj,
                                          Requestor => ['tara@example.com'],
                                          Subject   => 'bork bork bork',
                                          Priority  => 22,
                                        );
ok($id, 'record test ticket creation 1');
my $ticket2 = RT::Ticket->new($CurrentUser);
($id, $tobj, $msg2) = $ticket2->Create(Queue     => $queue_obj,
                                       Requestor => ['root@localhost'],
                                       Subject   => 'hurdy gurdy'
                                      );
ok($id, 'record test ticket creation 2');


### OK.  Have data, will travel.

# First test the search.

ok(require RT::Search::FromSQL, "Search::FromSQL loaded");
my $ticketsqlstr = "Requestor.EmailAddress = '" . $CurrentUser->EmailAddress .
    "' AND Priority > '20'";
my $search = RT::Search::FromSQL->new(Argument => $ticketsqlstr, TicketsObj => RT::Tickets->new($CurrentUser),
                                  );
is(ref($search), 'RT::Search::FromSQL', "search created");
ok($search->Prepare(), "fromsql search run");
my $counter = 0;
while(my $t = $search->TicketsObj->Next() ) {
    is($t->Id(), $ticket1->Id(), "fromsql search results 1");
    $counter++;
}
is ($counter, 1, "fromsql search results 2");

# Right.  Now test the actions.

ok(require RT::Action::RecordComment);
ok(require RT::Action::RecordCorrespondence);

my ($comment_act, $correspond_act);
ok($comment_act = RT::Action::RecordComment->new(TicketObj => $ticket1, TemplateObj => $template_obj, CurrentUser => $CurrentUser), "RecordComment created");
ok($correspond_act = RT::Action::RecordCorrespondence->new(TicketObj => $ticket2, TemplateObj => $template_obj, CurrentUser => $CurrentUser), "RecordCorrespondence created");
ok($comment_act->Prepare(), "Comment prepared");
ok($correspond_act->Prepare(), "Correspond prepared");
ok($comment_act->Commit(), "Comment committed");
ok($correspond_act->Commit(), "Correspondence committed");

# Now test for loop suppression.
my ($trans, $desc, $transaction) = $ticket2->Comment(MIMEObj => $template_obj->MIMEObj);
my $bogus_action = RT::Action::RecordComment->new(TicketObj => $ticket1, TemplateObj => $template_obj, TransactionObj => $transaction, CurrentUser => $CurrentUser);
ok(!$bogus_action->Prepare(), "Comment aborted to prevent loop");


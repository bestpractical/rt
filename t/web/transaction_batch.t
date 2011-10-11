use strict;
use warnings;
use RT;
use RT::Test tests => 9;

my $q = RT::Test->load_or_create_queue ( Name => 'General' );

my $s1 = RT::Scrip->new(RT->SystemUser);
my ($val, $msg) =$s1->Create( Queue => $q->Id,
             ScripCondition    => 'User Defined',
             ScripAction       => 'User Defined',
             CustomIsApplicableCode => 'return $self->TransactionObj->Field eq "TimeEstimated"',
             CustomPrepareCode => 'return 1',
             CustomCommitCode  => '$self->TicketObj->SetPriority($self->TicketObj->Priority + 2); return 1;',
             Template          => 'Blank',
             Stage             => 'TransactionBatch',
    );
ok($val,$msg);

my $ticket = RT::Ticket->new(RT->SystemUser);
my ($tv,$ttv,$tm) = $ticket->Create(Queue => $q->Id,
                                    Subject => "hair on fire",
                                    );
ok($tv, $tm);

my $testuser = RT::Test->load_or_create_user( Name => 'bob', EmailAddress => 'bob@example.com', Password => 'password' );
ok($testuser->Id, "Created test user bob");

ok( RT::Test->add_rights({ Principal => 'Privileged', Right => [qw(ShowTicket ModifyTicket SeeQueue)]}), 'Granted ticket management rights');

my $test_current_user = RT::CurrentUser->new();
$test_current_user->LoadByName($testuser->Name);
my $api_test = RT::Ticket->new($test_current_user);
$api_test->Load($ticket->Id);
$api_test->SetTimeEstimated(12);
$api_test->ApplyTransactionBatch;
is($api_test->CurrentUser->UserObj->Name, $testuser->Name,"User didn't change running Transaction Batch scrips");
$api_test->Load($api_test->Id);
is($api_test->Priority,2,"Ticket priority updated");

my ($baseurl, $m) = RT::Test->started_ok;
$m->login('bob','password');
$m->get_ok("$baseurl/Ticket/Modify.html?id=".$ticket->Id);
    $m->submit_form( form_number => 3,
        fields => { TimeEstimated => 5 }
    );

$ticket->FlushCache;
$ticket->Load($ticket->Id);
is ($ticket->Priority , 4, "Ticket priority is set right");

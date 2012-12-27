use strict;
use warnings;
use RT;
use RT::Test tests => 12;


my $q = RT::Test->load_or_create_queue ( Name => 'General' );

my $s1 = RT::Scrip->new(RT->SystemUser);
my ($val, $msg) =$s1->Create( Queue => $q->Id,
             ScripCondition    => 'User Defined',
             ScripAction       => 'User Defined',
             CustomIsApplicableCode => 'return ($self->TransactionObj->Field||"") eq "TimeEstimated"',
             CustomPrepareCode => 'return 1',
             CustomCommitCode  => '
if ( $self->TicketObj->CurrentUser->Name ne "RT_System" ) { 
    warn "Ticket obj has incorrect CurrentUser (should be RT_System) ".$self->TicketObj->CurrentUser->Name
}
if ( $self->TicketObj->QueueObj->CurrentUser->Name ne "RT_System" ) { 
    warn "Queue obj has incorrect CurrentUser (should be RT_System) ".$self->TicketObj->QueueObj->CurrentUser->Name
}
$self->TicketObj->SetPriority($self->TicketObj->Priority + 2); return 1;',
             Template          => 'Blank',
             Stage             => 'TransactionBatch',
    );
ok($val,$msg);

my $ticket = RT::Ticket->new(RT->SystemUser);
my ($tv,$ttv,$tm) = $ticket->Create(Queue => $q->Id,
                                    Subject => "hair on fire",
                                    );
ok($tv, $tm);

# Flush the Create transaction off of the ticket
$ticket->ApplyTransactionBatch;

my $testuser = RT::Test->load_or_create_user( Name => 'bob', EmailAddress => 'bob@example.com', Password => 'password' );
ok($testuser->Id, "Created test user bob");

ok( RT::Test->add_rights({ Principal => 'Privileged', Right => [qw(ShowTicket ModifyTicket SeeQueue)]}), 'Granted ticket management rights');

my $test_current_user = RT::CurrentUser->new();
$test_current_user->LoadByName($testuser->Name);
my $api_test = RT::Ticket->new($test_current_user);
$api_test->Load($ticket->Id);
is($api_test->Priority,0,"Ticket priority starts at 0");
$api_test->SetTimeEstimated(12);
$api_test->ApplyTransactionBatch;
is($api_test->CurrentUser->UserObj->Name, $testuser->Name,"User didn't change running Transaction Batch scrips");
$api_test->Load($api_test->Id);
is($api_test->Priority,2,"Ticket priority updated");

my ($baseurl, $m) = RT::Test->started_ok;
$m->login('bob','password');
$m->get_ok("$baseurl/Ticket/Modify.html?id=".$ticket->Id);
    $m->submit_form( form_name => 'TicketModify',
        fields => { TimeEstimated => 5 }
    );


$ticket->Load($ticket->Id);
is ($ticket->Priority , 4, "Ticket priority is set right");

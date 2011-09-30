use strict;
use warnings;
use RT;
use RT::Test tests => 7;


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

my ($baseurl, $m) = RT::Test->started_ok;
$m->login;
$m->get_ok("$baseurl/Ticket/Modify.html?id=".$ticket->Id);
    $m->submit_form( form_name => 'TicketModify',
        fields => { TimeEstimated => 5 }
    );


$ticket->Load($ticket->Id);
is ($ticket->Priority , '2', "Ticket priority is set right");

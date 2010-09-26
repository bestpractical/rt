#
# Check that the "On Reject" scrip condition exists and is working
#

use strict;
use warnings;
use RT;
use RT::Test tests => 7;


{

my $q = RT::Queue->new(RT->SystemUser);
$q->Create(Name =>'rejectTest');

ok($q->Id, "Created a scriptest queue");

my $s1 = RT::Scrip->new(RT->SystemUser);
my ($val, $msg) =$s1->Create( Queue => $q->Id,
             ScripAction => 'User Defined',
             ScripCondition => 'On reject',
             CustomIsApplicableCode => '',
             CustomPrepareCode => 'return 1',
             CustomCommitCode => '
                    $self->TicketObj->SetPriority($self->TicketObj->Priority+1);
                return(1);
            ',
             Template => 'Blank'
    );
ok($val,$msg);

my $ticket = RT::Ticket->new(RT->SystemUser);
my ($tv,$ttv,$tm) = $ticket->Create(Queue => $q->Id,
                                    Subject => "hair on fire",
                                    InitialPriority => '20'
                                    );
ok($tv, $tm);
ok($ticket->SetStatus('rejected'), "Status set to \"rejected\"");
is ($ticket->Priority , '21', "Condition is true, scrip triggered");
ok($ticket->SetStatus('open'), "Status set to \"open\"");
is ($ticket->Priority , '21', "Condition is false, scrip skipped");

}


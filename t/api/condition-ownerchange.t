
use strict;
use warnings;
use RT;
use RT::Test tests => 11;


{

my $q = RT::Queue->new(RT->SystemUser);
$q->Create(Name =>'ownerChangeTest');

ok($q->Id, "Created a scriptest queue");

my $s1 = RT::Scrip->new(RT->SystemUser);
my ($val, $msg) =$s1->Create( Queue => $q->Id,
             ScripAction => 'User Defined',
             ScripCondition => 'On Owner Change',
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
ok($ticket->SetOwner('root'));
is ($ticket->Priority , '21', "Ticket priority is set right");
ok($ticket->Steal);
is ($ticket->Priority , '22', "Ticket priority is set right");
ok($ticket->Untake);
is ($ticket->Priority , '23', "Ticket priority is set right");
ok($ticket->Take);
is ($ticket->Priority , '24', "Ticket priority is set right");






}


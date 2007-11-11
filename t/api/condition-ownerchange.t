
use strict;
use warnings;
use RT::Test; use Test::More; 
plan tests => 11;
use RT;



{

my $q = RT::Model::Queue->new(RT->SystemUser);
$q->create(Name =>'ownerChangeTest');

ok($q->id, "Created a scriptest queue");

my $s1 = RT::Model::Scrip->new(RT->SystemUser);
my ($val, $msg) =$s1->create( Queue => $q->id,
             ScripAction => 'User Defined',
             ScripCondition => 'On Owner Change',
             CustomIsApplicableCode => '',
             CustomPrepareCode => 'return 1',
             CustomCommitCode => '
                    $self->TicketObj->set_Priority($self->TicketObj->Priority+1);
                return(1);
            ',
             Template => 'Blank'
    );
ok($val,$msg);

my $ticket = RT::Model::Ticket->new(RT->SystemUser);
my ($tv,$ttv,$tm) = $ticket->create(Queue => $q->id,
                                    Subject => "hair on fire",
                                    InitialPriority => '20'
                                    );
ok($tv, $tm);
ok($ticket->set_Owner('root'));
is ($ticket->Priority , '21', "Ticket priority is set right");
ok($ticket->Steal);
is ($ticket->Priority , '22', "Ticket priority is set right");
ok($ticket->Untake);
is ($ticket->Priority , '23', "Ticket priority is set right");
ok($ticket->Take);
is ($ticket->Priority , '24', "Ticket priority is set right");






}

1;

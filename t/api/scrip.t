
use strict;
use warnings;
use RT;
use RT::Test tests => 7;


{

ok (require RT::Scrip);


my $q = RT::Queue->new($RT::SystemUser);
$q->Create(Name => 'ScripTest');
ok($q->Id, "Created a scriptest queue");

my $s1 = RT::Scrip->new($RT::SystemUser);
my ($val, $msg) =$s1->Create( Queue => $q->Id,
             ScripAction => 'User Defined',
             ScripCondition => 'User Defined',
             CustomIsApplicableCode => 'if ($self->TicketObj->Subject =~ /fire/) { return (1);} else { return(0)}',
             CustomPrepareCode => 'return 1',
             CustomCommitCode => '$self->TicketObj->SetPriority("87");',
             Template => 'Blank'
    );
ok($val,$msg);

my $ticket = RT::Ticket->new($RT::SystemUser);
my ($tv,$ttv,$tm) = $ticket->Create(Queue => $q->Id,
                                    Subject => "hair on fire",
                                    );
ok($tv, $tm);

is ($ticket->Priority , '87', "Ticket priority is set right");


my $ticket2 = RT::Ticket->new($RT::SystemUser);
my ($t2v,$t2tv,$t2m) = $ticket2->Create(Queue => $q->Id,
                                    Subject => "hair in water",
                                    );
ok($t2v, $t2m);

isnt ($ticket2->Priority , '87', "Ticket priority is set right");



}

1;


use strict;
use warnings;
use Test::More; 
plan tests => 7;
use RT;
use RT::Test;


ok (require RT::Model::Scrip);


my $q = RT::Model::Queue->new($RT::SystemUser);
$q->create(Name => 'ScripTest');
ok($q->id, "Created a scriptest queue");

my $s1 = RT::Model::Scrip->new($RT::SystemUser);
my ($val, $msg) =$s1->create( Queue => $q->id,
             ScripAction => 'User Defined',
             ScripCondition => 'User Defined',
             CustomIsApplicableCode => 'if ($self->TicketObj->Subject =~ /fire/) { return (1);} else { return(0)}',
             CustomPrepareCode => 'return 1',
             CustomCommitCode => '$self->TicketObj->__set(column =>"Priority", value => "87");',
             Template => 'Blank'
    );
ok($val,$msg);

my $ticket = RT::Model::Ticket->new($RT::SystemUser);
my ($tv,$ttv,$tm) = $ticket->create(Queue => $q->id,
                                    Subject => "hair on fire",
                                    );
ok($tv, $tm);

is ($ticket->Priority , '87', "Ticket priority is set right");


my $ticket2 = RT::Model::Ticket->new($RT::SystemUser);
my ($t2v,$t2tv,$t2m) = $ticket2->create(Queue => $q->id,
                                    Subject => "hair in water",
                                    );
ok($t2v, $t2m);

isnt ($ticket2->Priority , '87', "Ticket priority is set right");




1;

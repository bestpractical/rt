
use strict;
use warnings;
use RT::Test; use Test::More; 
plan tests => 7;
use RT;



ok (require RT::Model::Scrip);


my $q = RT::Model::Queue->new(current_user => RT->system_user);
$q->create(name => 'ScripTest');
ok($q->id, "Created a scriptest queue");

my $s1 = RT::Model::Scrip->new(current_user => RT->system_user);
my ($val, $msg) =$s1->create( queue => $q->id,
             scrip_action => 'User Defined',
             scrip_condition => 'User Defined',
             custom_is_applicable_code => ' if ($self->ticket_obj->subject =~ /fire/) { return (1);} else { return(0)}',
             custom_prepare_code => ' return 1',
             custom_commit_code => ' $self->ticket_obj->__set(column =>"priority", value => "87");',
             template => 'Blank'
    );
ok($val,$msg);

my $ticket = RT::Model::Ticket->new(current_user => RT->system_user);
my ($tv,$ttv,$tm) = $ticket->create(queue => $q->id,
                                    subject => "hair on fire",
                                    );
ok($tv, $tm);

is ($ticket->priority , '87', "Ticket priority is set right");
my $ticket2 = RT::Model::Ticket->new(current_user => RT->system_user);
my ($t2v,$t2tv,$t2m) = $ticket2->create(queue => $q->id,
                                    subject => "hair in water",
                                    );
ok($t2v, $t2m);

isnt ($ticket2->priority , '87', "Ticket priority is set right");




1;

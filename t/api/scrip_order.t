#!/usr/bin/perl -w

use strict;
use RT::Test; use Test::More tests => 7;

use RT;



# {{{ test scrip ordering based on description

my $scrip_queue = RT::Model::Queue->new(current_user => RT->system_user);
my ($queue_id, $msg) = $scrip_queue->create( name => "ScripOrdering-$$", 
    Description => 'Test scrip ordering by description' );
ok($queue_id, "Created scrip-ordering test queue? ".$msg);

my $priority_ten_scrip = RT::Model::Scrip->new(current_user => RT->system_user);
(my $id, $msg) = $priority_ten_scrip->create( 
    Description => "10 set priority $$",
    Queue => $queue_id, 
    ScripCondition => 'On Create',
    ScripAction => 'User Defined', 
    CustomPrepareCode => 'Jifty->log->debug("Setting priority to 10..."); return 1;',
    CustomCommitCode => '$self->ticket_obj->set_Priority(10);',
    Template => 'Blank',
    Stage => 'TransactionCreate',
);
ok($id, "Created priority-10 scrip? ".$msg);

my $priority_five_scrip = RT::Model::Scrip->new(current_user => RT->system_user);
($id, $msg) = $priority_ten_scrip->create( 
    Description => "05 set priority $$",
    Queue => $queue_id, 
    ScripCondition => 'On Create',
    ScripAction => 'User Defined', 
    CustomPrepareCode => 'Jifty->log->debug("Setting priority to 5..."); return 1;',
    CustomCommitCode => '$self->ticket_obj->set_Priority(5);', 
    Template => 'Blank',
    Stage => 'TransactionCreate',
);
ok($id, "Created priority-5 scrip? ".$msg);

my $ticket = RT::Model::Ticket->new(current_user => RT->system_user);
($id, $msg) = $ticket->create( 
    Queue => $queue_id, 
    Requestor => 'order@example.com',
    Subject => "Scrip order test $$",
);
ok($ticket->id, "Created ticket? id=$id");

isnt($ticket->Priority , 0, "Ticket shouldn't be priority 0");
isnt($ticket->Priority , 5, "Ticket shouldn't be priority 5");
is  ($ticket->Priority , 10, "Ticket should be priority 10");

# }}}

1;

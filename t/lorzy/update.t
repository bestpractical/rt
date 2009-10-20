use Test::More tests => 7;
use RT::Test;

use strict;
use warnings;

use RT::Model::Queue;
use RT::Model::User;
use RT::Model::Group;
use RT::Model::Ticket;
use RT::Model::ACE;
use RT::CurrentUser;
use Test::Exception;
use RT::Test::Email;

use_ok('RT::Lorzy');
use_ok('LCore');
use_ok('LCore::Level2');
my $l = $RT::Lorzy::LCORE;

my $on_created_lcore = q{
(lambda (ticket transaction)
  (Str.Eq (Native.Invoke transaction "type") "create"))
};

my $update_ticket_lcore = q{
(lambda (ticket transaction context)
  (RT::Model::Ticket.Update ticket
        (RT::Model::TicketParam.subject "moose")
        (RT::Model::TicketParam.priority 10)))
};

RT::Lorzy::Dispatcher->reset_rules;

my $rule = RT::Model::Rule->new( current_user => RT->system_user );
$rule->create( condition_code => $on_created_lcore,
               action_code    => $update_ticket_lcore );

my $queue = RT::Model::Queue->new(current_user => RT->system_user);
my ($queue_id) = $queue->create( name =>  'lorzy');
ok( $queue_id, 'queue created' );

my $ticket = RT::Model::Ticket->new(current_user => RT->system_user );

my ($rv, $msg) = $ticket->create( subject => 'lorzy test', queue => $queue->name, requestor => 'foo@localhost' );

ok($ticket->id);
is($ticket->subject, 'moose');
is($ticket->priority, 10);



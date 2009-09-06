use Test::More tests => 4;
use RT::Test;

use strict;
use warnings;

use_ok('RT::Lorzy');
my $l = $RT::Lorzy::LCORE;

my $ticket_subject = $l->analyze_it(q{
(lambda (ticket)
  (RT::Model::Ticket.subject ticket))
})->($l->env);

my $queue = RT::Model::Queue->new(current_user => RT->system_user);
my ($queue_id) = $queue->create( name =>  'lorzy');
ok( $queue_id, 'queue created' );

my $ticket = RT::Model::Ticket->new(current_user => RT->system_user );
my ($rv, $msg) = $ticket->create( subject => 'lorzy test', queue => $queue->name, requestor => 'foo@localhost' );

is( $ticket_subject->apply($ticket), 'lorzy test' );

my $x = $l->env->find_functions_by_type(['RT::Model::Ticket']);

is_deeply [sort map { s/^RT::Model::Ticket\.// ? $_ : () } keys %$x],
    [qw(created creator disabled due effective_id final_priority id initial_priority issue_statement last_updated last_updated_by owner priority queue resolution resolved started starts status subject time_estimated time_left time_worked told type)];

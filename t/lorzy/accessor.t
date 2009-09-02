use Test::More tests => 3;
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

use Test::More tests => 6;
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

use_ok('RT::Lorzy');

my $l = $RT::Lorzy::LCORE;


my $priority10 = $l->analyze_it(q{(RT.MkCondition.PriorityExceeds 10)})->($l->env);

my $queue = RT::Model::Queue->new(current_user => RT->system_user);
my ($queue_id) = $queue->create( name =>  'lorzy');
ok( $queue_id, 'queue created' );

my $ticket = RT::Model::Ticket->new(current_user => RT->system_user );
my ($rv, $msg) = $ticket->create( subject => 'watcher tests', queue => $queue->name );

my $txn = $ticket->transactions->first;

my $ret;
lives_ok {
    $ret = $priority10->apply($ticket, $txn);
};
ok(!$ret);

$ticket->set_priority('11');

lives_ok {
    $ret = $priority10->apply($ticket, $txn);
};
ok($ret);


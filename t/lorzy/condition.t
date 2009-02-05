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

use_ok('Lorzy');

my $eval = Lorzy::Evaluator->new();
$eval->load_package($_) for qw(Str Native);
$eval->load_package('RT', 'RT::Lorzy::Package::RT');

my $tree    = [ { name => 'IfThen',
                  args => { if_true => { name => 'True' },
                            if_false => { name => 'False' },
                            condition => { name => 'RT.Condition.Applicable',
                                args => {
                                    name => "On Create",
                                    ticket => { name => 'Symbol', args => { symbol => 'ticket' }},
                                    transaction => { name => 'Symbol', args => { symbol => 'transaction' }},
                                    }
                            }
                        } } ];

my $builder = Lorzy::Builder->new();
my $on_created  = $builder->defun(
    ops => $tree,
    signature =>
        { ticket => Lorzy::FunctionArgument->new( name => 'ticket', type => 'RT::Model::Ticket' ),
          transaction => Lorzy::FunctionArgument->new( name => 'transaction', type => 'RT::Model::Transaction' ) }
);

my $queue = RT::Model::Queue->new(current_user => RT->system_user);
my ($queue_id) = $queue->create( name =>  'lorzy');
ok( $queue_id, 'queue created' );

my $ticket = RT::Model::Ticket->new(current_user => RT->system_user );
my ($rv, $msg) = $ticket->create( subject => 'watcher tests', queue => $queue->name );

my $txn = $ticket->transactions->first;

my $ret;
lives_ok {
    $ret = $eval->apply_script( $on_created, { 'ticket' => $ticket, transaction => $txn } );
};
ok($ret);

$ticket->set_status('open');

lives_ok {
    $ret = $eval->apply_script( $on_created, { 'ticket' => $ticket, transaction => $ticket->transactions->last } );
};
ok(!$ret);


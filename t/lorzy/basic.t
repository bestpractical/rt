use Test::More tests => 8;
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

my $tree    = [ { name => 'IfThen',
                  args => { if_true => { name => 'True' },
                            if_false => { name => 'False' },
                            condition => { name => 'Str.Eq',
                                args => {
                                    arg1 => "open",
                                    arg2 => { name => 'Native.Invoke',
                                              args => { obj => { name => 'Symbol', args => { symbol => 'ticket' }},
                                                        method => 'status',
                                                        args => { name => 'List',  nodes => []} },
                                          },
                                }
                  } }} ];
my $builder = Lorzy::Builder->new();
my $is_open  = $builder->defun(
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

my $ret;
lives_ok {
    $ret = $eval->apply_script( $is_open, { 'ticket' => $ticket, transaction => $ticket->transactions->first } );
};
ok(!$ret);

$ticket->set_status('open');

lives_ok {
    $ret = $eval->apply_script( $is_open, { 'ticket' => $ticket, transaction => $ticket->transactions->first } );
};
ok($ret);

use RT::Lorzy;

$YAML::Syck::UseCode = $YAML::UseCode = 1;
my $rule = RT::Model::Rule->new( current_user => RT->system_user );
$rule->create_from_factory(
    RT::Lorzy::RuleFactory->make_factory
            ( { condition => $is_open,
                description => 'test action',
                _stage => 'transaction_create',
                action => sub { $_[0]->{context}{hints}{run}++ } } )
);
my ($txn_id, $tmsg, $txn) = $ticket->comment(content => 'lorzy lorzy in the code');
my ($this_rule) = grep { $_->description eq 'test action'} @{$txn->rules};

ok($this_rule);
is_deeply($this_rule->hints, { run => 1 });


use Test::More tests => 28;
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
        { ticket => Lorzy::FunctionArgument->new( name => 'ticket', type => 'RT::Model::Ticket' ) }
);

my $queue = RT::Model::Queue->new(current_user => RT->system_user);
my ($queue_id) = $queue->create( name =>  'lorzy');
ok( $queue_id, 'queue created' );

my $ticket = RT::Model::Ticket->new(current_user => RT->system_user );
my ($rv, $msg) = $ticket->create( subject => 'watcher tests', queue => $queue->name );

my $ret;
lives_ok {
    $ret = $eval->apply_script( $is_open, { 'ticket' => $ticket } );
};
ok(!$ret);

$ticket->set_status('open');

lives_ok {
    $ret = $eval->apply_script( $is_open, { 'ticket' => $ticket } );
};
ok($ret);

use RT::Lorzy;

RT::Lorzy::Dispatcher->add_rule(
    RT::Lorzy::Rule->new( { condition => $is_open,
                            action => sub { warn "rahh!"} } )
);

warn $ticket->comment(content => 'lorzy lorzy in the code');

1;


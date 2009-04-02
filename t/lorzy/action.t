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
use RT::Test::Email;

use_ok('Lorzy');
use_ok('RT::Lorzy');

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

$tree    = [ { name => 'RT.ScripAction.Run',
               args => {
                   name => "Autoreply To requestors",
                   template => "Autoreply",
                   context => { name => 'Symbol', args => { symbol => 'context' } },
                   ticket => { name => 'Symbol', args => { symbol => 'ticket' }},
                   transaction => { name => 'Symbol', args => { symbol => 'transaction' }},
               } } ];
my $auto_reply  = $builder->defun(
    ops => $tree,
    signature =>
        { ticket => Lorzy::FunctionArgument->new( name => 'ticket', type => 'RT::Model::Ticket' ),
          context => Lorzy::FunctionArgument->new( name => 'context', type => 'HASH' ),
          transaction => Lorzy::FunctionArgument->new( name => 'transaction', type => 'RT::Model::Transaction' ) }
);

RT::Lorzy::Dispatcher->reset_rules;

my $rule = RT::Model::Rule->new( current_user => RT->system_user );
$rule->create_from_factory( 
    RT::Lorzy::RuleFactory->make_factory
    ( { condition => $on_created,
        _stage => 'transaction_create',
        action => $auto_reply } )
);

my $queue = RT::Model::Queue->new(current_user => RT->system_user);
my ($queue_id) = $queue->create( name =>  'lorzy');
ok( $queue_id, 'queue created' );

my $ticket = RT::Model::Ticket->new(current_user => RT->system_user );
mail_ok {
lives_ok {
my ($rv, $msg) = $ticket->create( subject => 'lorzy test', queue => $queue->name, requestor => 'foo@localhost' );
};
} { from => qr/lorzy via RT/,
    to => 'foo@localhost',
    subject => qr'AutoReply: lorzy test',
    body => qr/automatically generated/,
};

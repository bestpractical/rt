use Test::More tests => 3;
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

my $queue = RT::Model::Queue->new(current_user => RT->system_user);
my ($queue_id) = $queue->create( name =>  'lorzy');
ok( $queue_id, 'queue created' );

my $ticket = RT::Model::Ticket->new(current_user => RT->system_user );
my ($rv, $msg) = $ticket->create( subject => 'watcher tests', queue => $queue->name );

use RT::Lorzy;

$YAML::Syck::UseCode = $YAML::UseCode = 1;
my $rule = RT::Model::Rule->new( current_user => RT->system_user );
$rule->create_from_factory(
    RT::Lorzy::RuleFactory->make_factory
            ( { condition => sub { die 'condition fail' },
                description => 'test fail action',
                _stage => 'transaction_create',
                action => sub { $_[0]->{context}{hints}{run}++ } } )
);

my ($txn_id, $tmsg, $txn) = $ticket->comment(content => 'lorzy lorzy in the code');
my ($this_rule) = grep { $_->description eq 'test fail action'} @{$txn->rules};

ok(!$this_rule, 'not running failing condition rules');



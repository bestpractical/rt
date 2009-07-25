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
use_ok('LCore');
use_ok('LCore::Level2');

my $l = $RT::Lorzy::LCORE;
$l->env->set_symbol('cause-error' => LCore::Primitive->new
                        ( body => sub {
                              die "fail";
                          },
                          lazy => 0,
                      ));

$l->env->set_symbol('inc-hint-run' => LCore::Primitive->new
                        ( body => sub {
                              my ($context) = @_;
                              $context->{hints}{run}++;
                          },
                          lazy => 0,
                      ));

my $queue = RT::Model::Queue->new(current_user => RT->system_user);
my ($queue_id) = $queue->create( name =>  'lorzy');
ok( $queue_id, 'queue created' );

my $ticket = RT::Model::Ticket->new(current_user => RT->system_user );
my ($rv, $msg) = $ticket->create( subject => 'watcher tests', queue => $queue->name );

use RT::Lorzy;

my $rule = RT::Model::Rule->new( current_user => RT->system_user );
$rule->create( description => 'test fail action',
               condition_code => '(lambda (ticket transaction) (cause-error))',
               action_code    => '(lambda (ticket transaction context) (inc-hint-run context))' );

$rule->create( description => 'test worky action',
               condition_code => '(lambda (ticket transaction) 1)',
               action_code    => '(lambda (ticket transaction context) (inc-hint-run context))' );

my ($txn_id, $tmsg, $txn) = $ticket->comment(content => 'lorzy lorzy in the code');
my ($this_rule) = grep { $_->description eq 'test fail action'} @{$txn->rules};

ok(!$this_rule, 'not running failing condition rules');

($this_rule) = grep { $_->description eq 'test worky action'} @{$txn->rules};
ok($this_rule, 'running worky condition rules');



package RT::Lorzy;
use strict;
use warnings;

use RT::Ruleset;
use Lorzy::Evaluator;
use RT::Lorzy::Dispatcher;

RT::Ruleset->register( 'RT::Lorzy::Dispatcher' );
our $EVAL = Lorzy::Evaluator->new();
#$EVAL->load_package($_) for qw(Str Native);
#$EVAL->load_package('RT', 'RT::Lorzy::Package::RT');
use LCore;
use LCore::Level2;

our $LCORE = LCore->new( env => LCore::Level2->new );
require RT::Lorzy::Package::RT;
$LCORE->env->set_symbol('Native.Invoke' => LCore::Primitive->new
                        ( body => sub {
                              my ($object, $method, @args) = @_;
                              return $object->$method(@args);
                          },
                          lazy => 0,
                      ));

$LCORE->env->set_symbol('Str.Eq' => LCore::Primitive->new
                        ( body => sub {
                              return $_[0] eq $_[1];
                          }));

$LCORE->env->set_symbol('RT.RuleAction.Prepare' => LCore::Primitive->new
                        ( body => sub {
                              my ($name, $template, $context, $ticket, $transaction) = @_;
                              my $rule = RT::Rule->new( current_user => $ticket->current_user,
                                  ticket_obj => $ticket,
                                  transaction_obj => $transaction
                              );
                              my $action = $rule->get_scrip_action($name, $template);
                              $action->prepare or return;
                              $context->{hints} = $action->hints;
                              $context->{action} = $action;
                          },
                          lazy => 0,
                          parameters => [ LCore::Parameter->new({ name => 'name', type => 'Str' }),
                                          LCore::Parameter->new({ name => 'template', type => 'Str' }),
                                          LCore::Parameter->new({ name => 'context', type => 'Str' }),
                                          LCore::Parameter->new({ name => 'ticket', type => 'RT::Model::Ticket' }),
                                          LCore::Parameter->new({ name => 'transaction', type => 'RT::Model::Transaction' }) ],

                      ));

$LCORE->env->set_symbol('RT.RuleAction.Run' => LCore::Primitive->new
                        ( body => sub {
                              my ($name, $template, $context, $ticket, $transaction) = @_;
                              my $action = $context->{action};
                              unless ($action) {
                                  my $rule = RT::Rule->new( current_user => $ticket->current_user,
                                                            ticket_obj => $ticket,
                                                            transaction_obj => $transaction );
                                  $action = $rule->get_scrip_action($name, $template);
                                  $action->prepare or return;
                              }
                              $action->commit;
                          },
                          lazy => 0,
                          parameters => [ LCore::Parameter->new({ name => 'name', type => 'Str' }),
                                          LCore::Parameter->new({ name => 'template', type => 'Str' }),
                                          LCore::Parameter->new({ name => 'context', type => 'Str' }),
                                          LCore::Parameter->new({ name => 'ticket', type => 'RT::Model::Ticket' }),
                                          LCore::Parameter->new({ name => 'transaction', type => 'RT::Model::Transaction' }) ],

                      ));


sub evaluate {
    my ($self, $code, %args) = @_;
    eval { $EVAL->apply_script( $code, \%args ) };
}

my %cond_compat_map = ( 'On Create' => 'OnCreate',
                        'On Transaction' => 'OnTransaction',
                        'On Correspond' => 'OnCorrespond',
                        'On comment' => 'OnComment',
                        'On Status Change' => 'OnStatusChange',
                        'On owner Change' => 'OnOwnerChange',
                        'On priority Change' => 'OnPriorityChange',
                        'On Resolve' => 'OnResolve',
                        'On Close' => 'OnClose',
                        'On Reopen' => 'OnReopen',
                        # doesn't work yet
                        'PriorityExceeds' => 'PriorityExceeds',
                        'BeforeDue' => 'BeforeDue',
                        'OverDue' => 'OverDue',
          );


sub create_scripish {
    my ( $class, $scrip_condition, $scrip_action, $template, $description, $queue ) = @_;
    my $lorzy_cond = $cond_compat_map{$scrip_condition}
        or die "unsupported compat condition: $scrip_condition";

    my $lcore_cond = "(RT.Condition.$lorzy_cond ticket transaction)";
    if ($queue) {
        $lcore_cond = qq{(and $lcore_cond (Str.Eq "$queue" (Native.Invoke ticket "queue")))};
    }
    $lcore_cond = qq{(lambda (ticket transaction) $lcore_cond)};

    my $lcore_prepare = qq{
(lambda (ticket transaction context)
  (RT.RuleAction.Prepare
        (("name"        . "$scrip_action")
         ("template"    . "$template")
         ("context"     . context)
         ("ticket"      . ticket)
         ("transaction" . transaction))))
};

    my $lcore_action = qq{
(lambda (ticket transaction context)
  (RT.RuleAction.Run
        (("name"        . "$scrip_action")
         ("template"    . "$template")
         ("context"     . context)
         ("ticket"      . ticket)
         ("transaction" . transaction))))
};

    my $rule = RT::Model::Rule->new( current_user => RT->system_user );
    $rule->create( condition_code => $lcore_cond,
                   prepare_code   => $lcore_prepare,
                   action_code    => $lcore_action,
                   description    => $description,
               );
}

package RT::Lorzy::RuleFactory;
use base 'Class::Accessor::Fast';
__PACKAGE__->mk_accessors(qw(description condition action prepare _stage));

sub make_factory {
    my $class = shift;
    return $class->SUPER::new(@_);
}

sub new {
    my $self = shift;
    return RT::Lorzy::Rule->new( @_, factory => $self);
}

package RT::Lorzy::Rule;
use base 'RT::Rule';
use base 'Class::Accessor::Fast';

__PACKAGE__->mk_accessors(qw(factory context _last_scripaction));

sub _init {
    my $self = shift;
    Carp::cluck if scalar @_ % 2;
    my %args = @_;
    $self->SUPER::_init(%args);
    $self->context({});
    $self->factory($args{factory});
}

sub prepare {
    my ( $self, %args ) = @_;
    warn "===> hi this is prepare for $self ";
    my $ret = $self->factory->condition->apply($self->ticket_obj, $self->transaction);
    warn $ret;
#    if (my $e = Lorzy::Exception->caught()) {
#        Jifty->log->error("Rule '@{[ $self->description]}' condition error, ignoring: $e");
#    }
    return unless $ret;

    return 1 unless $self->factory->prepare;
    warn "==> hi this is to preprae";
    $ret = $self->factory->prepare->apply($self->ticket_obj, $self->transaction, $self->context);

#    if (my $e = Lorzy::Exception->caught()) {
#        Jifty->log->error("Rule '@{[ $self->description]}' prepare error, ignoring: $e");
#    }
    return $ret;
}

sub description { $_[0]->factory->description }

sub hints {
    my $self = shift;
    return $self->context->{hints};
}

sub commit {
    my ($self, %args) = @_;
    warn "==> trying to commit ".$self->factory->description;
    my $ret = $self->factory->action->apply($self->ticket_obj, $self->transaction, $self->context);

#    if (my $e = Lorzy::Exception->caught()) {
#        Jifty->log->error("Rule '@{[ $self->description]}' commit error: $e");
#    }
    return $ret;
}

1;

package RT::Lorzy;
use strict;
use warnings;

use RT::Ruleset;
use RT::Lorzy::Dispatcher;

RT::Ruleset->register( 'RT::Lorzy::Dispatcher' );
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
                          },
                          parameters => [ LCore::Parameter->new({ name => 'left', type => 'Str' }),
                                          LCore::Parameter->new({ name => 'right', type => 'Str' })],
                          return_type => 'Bool'
                      ));

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

sub install_model_accessors {
    my ($env, $model) = @_;
    my $modelname = lc($model);
    $modelname =~ s/.*://;
    for my $column ($model->columns) {
        next if $column->virtual;
        my $name = $column->name;
        my $type = $column->type;
        $type = $column->refers_to   ? $column->refers_to
              : $type =~ m/^varchar/ ? 'Str'
              : $type eq 'timestamp' ? 'DateTime'
              : $type eq 'boolean'   ? 'Bool'
              : $type eq 'smallint'  ? 'Bool'
              : $type =~ m/int$/     ? 'Int'
              : $type eq 'integer'   ? 'Int'
              : $type eq 'serial'    ? 'Int'
              :                        next;

        $env->set_symbol($model.'.'.$name => LCore::Primitive->new
                             ( body => sub {
                                   my ($object) = @_;
                                   $object->$name
                               },
                               lazy => 0,
                               parameters => [ LCore::Parameter->new({ name => $modelname, type => $model }) ],
                               return_type => $type
                           ));
    }
}

install_model_accessors($RT::Lorzy::LCORE->env, $_)
    for qw(RT::Model::Ticket RT::Model::Transaction RT::Model::Queue);


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
        $lcore_cond = qq{(and $lcore_cond (Str.Eq "$queue" (Native.Invoke ticket "queue_id")))};
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
    return $rule;
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

sub handle_exception {
    my $self = shift;
    my $e;
    if ( $e = LCore::Exception->caught() ) {
        Jifty->log->error("Rule '@{[ $self->description]}' condition error, ignoring: $e");
    }
    elsif ( $e = Exception::Class->caught() ) {
        ref $e ? $e->rethrow : die "$e";
    }
}

sub prepare {
    my ( $self, %args ) = @_;
    my $ret = eval { $self->factory->condition->apply($self->ticket_obj, $self->transaction) };
    return if $self->handle_exception();
    return unless $ret;

    return 1 unless $self->factory->prepare;

    $ret = eval { $self->factory->prepare->apply($self->ticket_obj, $self->transaction, $self->context) };
    return if $self->handle_exception();

    return $ret;
}

sub description { $_[0]->factory->description }

sub hints {
    my $self = shift;
    return $self->context->{hints};
}

sub commit {
    my ($self, %args) = @_;
    my $ret = eval { $self->factory->action->apply($self->ticket_obj, $self->transaction, $self->context) };
    return if $self->handle_exception();

    return $ret;
}

1;

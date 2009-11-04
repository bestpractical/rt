package RT::Lorzy;
use strict;
use warnings;

use RT::Ruleset;
use RT::Lorzy::Dispatcher;

RT::Ruleset->register( 'RT::Lorzy::Dispatcher' );
use LCore;
use LCore::Level2;

use Moose::Util::TypeConstraints;

our $LCORE = LCore->new( env => LCore::Level2->new );
require RT::Lorzy::Package::RT;

$LCORE->env->set_symbol('Str.Eq' => LCore::Primitive->new
                        ( body => sub {
                              return $_[0] eq $_[1];
                          },
                          parameters => [ LCore::Parameter->new({ name => 'left', type => 'Str' }),
                                          LCore::Parameter->new({ name => 'right', type => 'Str' })],
                          return_type => 'Bool'
                      ));

my $ticket_status = enum 'RT::TicketStatus'  => qw(new open stalled resolved rejected deleted);

install_enum_consts($ticket_status);

# XXX type class eq
$LCORE->env->set_symbol('TicketStatus.Eq' => LCore::Primitive->new
                        ( body => sub {
                              die 'not yet';
                              return $_[0] eq $_[1];
                          },
                          parameters => [ LCore::Parameter->new({ name => 'left', type => 'RT::TicketStatus' }),
                                          LCore::Parameter->new({ name => 'right', type => 'RT::TicketStatus' })],
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
                                          LCore::Parameter->new({ name => 'context', type => 'HashRef' }),
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
                                          LCore::Parameter->new({ name => 'context', type => 'HashRef' }),
                                          LCore::Parameter->new({ name => 'ticket', type => 'RT::Model::Ticket' }),
                                          LCore::Parameter->new({ name => 'transaction', type => 'RT::Model::Transaction' }) ],

                      ));


sub install_enum_consts {
    my ($type) = @_;
    # this helper installs const functions for the possible values of
    # an enum type.
    for (@{$type->values}) {
        $LCORE->env->set_symbol($type.'.'.$_ => LCore::Primitive->new
                                    ( body => sub { $_ },
                                      parameters => [],
                                      return_type => $type,
                                  ));
    }
}

sub install_model_accessors {
    my ($env, $model) = @_;
    my $modelname = lc($model);
    $modelname =~ s/.*://;

    my $param_type = $model.'Param';
    type $param_type;

    $env->set_symbol($model.'.Update' => LCore::Primitive->new
                         ( body => sub {
                               my ($ticket, $update) = @_;
                               # update is [ ['tag', $value], .... ]
                               my %params = map { @$_ } @$update;
                               use Data::Dumper;
                               my ( $ret, $msg ) = $ticket->update(
                                   attributes_ref => [keys %params],
                                   args_ref       => \%params );
                           },
                           lazy => 0,
                           slurpy => 1,
                           parameters => [
                               LCore::Parameter->new({ name => $modelname, type => $model }),
                               LCore::Parameter->new({ name => 'update', type => "ArrayRef[$param_type]" }) ],
                           return_type => 'Any',
                       ));

    for my $column ($model->columns) {
        next if $column->virtual;
        my $name = $column->name;
        my $type = $column->type;
        $type = $column->refers_to   ? $column->refers_to
              : $name eq 'status'    ? 'RT::TicketStatus' # XXX hack for now
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
                                   Carp::cluck unless $object;

                                   $object->$name
                               },
                               lazy => 0,
                               parameters => [ LCore::Parameter->new({ name => $modelname, type => $model }) ],
                               return_type => $type
                           ));

        $env->set_symbol($model.'Param.'.$name => LCore::Primitive->new
                             ( body => sub {
                                   my $val = shift;
                                   return [$name => $val]
                               },
                               parameters => [ LCore::Parameter->new({ name => $name, type => $type }) ],
                               return_type => $param_type,
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
    my ( $class, $scrip_condition, $scrip_action, $template, $description, $queue_id ) = @_;
    my $lorzy_cond = $cond_compat_map{$scrip_condition}
        or die "unsupported compat condition: $scrip_condition";

    my $lcore_cond = "(RT.Condition.$lorzy_cond ticket transaction)";
    if ($queue_id) {
        # XXX: Num.Eq
        $lcore_cond = qq{(and $lcore_cond (Str.Eq "$queue_id" (RT::Model::Queue.id (RT::Model::Ticket.queue ticket))))};
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

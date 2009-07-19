package RT::Lorzy;
use strict;
use warnings;

use RT::Ruleset;
use Lorzy::Evaluator;
use RT::Lorzy::Dispatcher;

RT::Ruleset->register( 'RT::Lorzy::Dispatcher' );
our $EVAL = Lorzy::Evaluator->new();
$EVAL->load_package($_) for qw(Str Native);
$EVAL->load_package('RT', 'RT::Lorzy::Package::RT');
use LCore;
use LCore::Level2;

our $LCORE = LCore->new( env => LCore::Level2->new );

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
    my $sigs = { ticket => Lorzy::FunctionArgument->new( name => 'ticket', type => 'RT::Model::Ticket' ),
        transaction => Lorzy::FunctionArgument->new( name => 'transaction', type => 'RT::Model::Transaction' ) };
    my $builder = Lorzy::Builder->new();

    my $lorzy_cond = $cond_compat_map{$scrip_condition}
        or die "unsupported compat condition: $scrip_condition";
    my $tree = {
        name => 'RT.Condition.'.$lorzy_cond,
        args => {
            ticket => { name => 'Symbol', args => { symbol => 'ticket' } },
            transaction => { name => 'Symbol', args => { symbol => 'transaction' } }
        } };

    # my $lcore_code = "(RT.Condition.$lorzy_cond ticket transaction)"

    if ($queue) {

        # $lcore_code = qq{(and $lcore_code (Str.Eq "$queue" (Native.Invoke ticket "queue")))}
        $tree = { name => 'And',
                  args => { nodes =>
                                [ { name => 'Str.Eq',
                                    args => {
                                        arg1 => $queue,
                                        arg2 => { name => 'Native.Invoke',
                                                  args => { obj => { name => 'Native.Invoke',
                                                                     args => { obj => { name => 'Symbol', args => { symbol => 'ticket' }},
                                                                               method => 'queue',
                                                                               args => { name => 'List',  nodes => []} } },
                                                            method => 'id',
                                                            args => { name => 'List',  nodes => []} },
                                              },
                                    }},
                                  $tree ] } };
    }

    my $condition = $builder->defun(
        ops => [ $tree ],
        signature => { %$sigs },
    );

    $sigs->{context} = Lorzy::FunctionArgument->new( name => 'context', type => 'HASH' );

    my $prepare = $builder->defun(
        ops => [ { name => 'RT.ScripAction.Prepare',
                args => {
                    name     => $scrip_action,
                    context => { name => 'Symbol', args => { symbol => 'context' } },
                    template => $template,
                    ticket => { name => 'Symbol', args => { symbol => 'ticket' } },
                    transaction => { name => 'Symbol', args => { symbol => 'transaction' } },
                    } } ],
        signature => $sigs );

    my $action = $builder->defun(
        ops => [ { name => 'RT.ScripAction.Run',
                args => {
                    name     => $scrip_action,
                    context => { name => 'Symbol', args => { symbol => 'context' } },
                    template => $template,
                    ticket => { name => 'Symbol', args => { symbol => 'ticket' } },
                    transaction => { name => 'Symbol', args => { symbol => 'transaction' } },
                    } } ],
        signature => $sigs );

    RT::Lorzy::RuleFactory->make_factory(
        { condition     => $condition,
          prepare       => $prepare,
          action        => $action,
          description   => $description,
          _stage        => 'transaction_create',
      } )
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
#    return unless $ret;

    return 1 unless $self->factory->prepare;
    warn "==> hi this is to preprae";
    $ret = $self->factory->prepare->($self->ticket_obj, $self->transaction, $self->context);

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
    warn "==> trying to commit";
    my $ret = $self->factory->action->apply($self->ticket_obj, $self->transaction, $self->context);

#    if (my $e = Lorzy::Exception->caught()) {
#        Jifty->log->error("Rule '@{[ $self->description]}' commit error: $e");
#    }
    return $ret;
}

1;

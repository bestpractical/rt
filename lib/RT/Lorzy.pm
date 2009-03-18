package RT::Lorzy;
use strict;
use warnings;

use RT::Ruleset;
use Lorzy::Evaluator;

RT::Ruleset->add( name => 'Lorzy', rules => ['RT::Lorzy::Dispatcher'] );
our $EVAL = Lorzy::Evaluator->new();
$EVAL->load_package($_) for qw(Str Native);
$EVAL->load_package('RT', 'RT::Lorzy::Package::RT');

sub evaluate {
    my ($self, $code, %args) = @_;
    my $ret = $EVAL->apply_script( $code, \%args );
    return $ret;
}

sub create_scripish {
    my ( $class, $scrip_condition, $scrip_action, $template, $queue ) = @_;
    my $sigs = { ticket => Lorzy::FunctionArgument->new( name => 'ticket', type => 'RT::Model::Ticket' ),
        transaction => Lorzy::FunctionArgument->new( name => 'transaction', type => 'RT::Model::Transaction' ) };
    my $builder = Lorzy::Builder->new();

    my $tree = {
        name => 'RT.Condition.Applicable',
        args => {
            name => $scrip_condition,
            ticket => { name => 'Symbol', args => { symbol => 'ticket' } },
            transaction => { name => 'Symbol', args => { symbol => 'transaction' } }
        } };

    if ($queue) {

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
        signature => $sigs,
    );

    my $action = $builder->defun(
        ops => [ { name => 'RT.ScripAction.Run',
                args => {
                    name     => $scrip_action,
                    template => $template,
                    ticket => { name => 'Symbol', args => { symbol => 'ticket' } },
                    transaction => { name => 'Symbol', args => { symbol => 'transaction' } },
                    } } ],
        signature => $sigs );

    my $hints = $builder->defun(
        ops => [ { name => 'RT.ScripAction.Hints',
                args => {
                    name     => $scrip_action,
                    template => $template,
                    ticket => { name => 'Symbol', args => { symbol => 'ticket' } },
                    callback => { name => 'Symbol', args => { symbol => 'callback' } },
                    transaction => { name => 'Symbol', args => { symbol => 'transaction' } },
                    } } ],
        signature => {%$sigs,
                      callback => Lorzy::FunctionArgument->new( name => 'callback', type => 'CODE' ) } );

    RT::Lorzy::Rule->new(
        { condition     => $condition,
          collect_hints => $hints,
          action        => $action } )
}

package RT::Lorzy::Rule;
use base 'Class::Accessor::Fast';
__PACKAGE__->mk_accessors(qw(condition action collect_hints));

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    if (ref($self->action) eq 'CODE') {
        # XXX: signature compat check
        $self->action( Lorzy::Lambda::Native->new( body => $self->action,
                                                   signature => 
        { ticket => Lorzy::FunctionArgument->new( name => 'ticket', type => 'RT::Model::Ticket' ),
          transaction => Lorzy::FunctionArgument->new( name => 'transaction', type => 'RT::Model::Transaction' ) }

                                               ) );
    }
    return $self;
}

sub on_condition {
    my ($self, $ticket_obj, $transaction_obj) = @_;
    return RT::Lorzy->evaluate( $self->condition, ticket => $ticket_obj, transaction => $transaction_obj);
}

sub hints {
    my ($self, $ticket_obj, $transaction_obj, $hints) = @_;
    return unless $self->collect_hints;
    return RT::Lorzy->evaluate( $self->collect_hints, ticket => $ticket_obj, transaction => $transaction_obj, callback => $hints);
}

sub commit {
    my ($self, $ticket_obj, $transaction_obj) = @_;
    return RT::Lorzy->evaluate( $self->action, ticket => $ticket_obj, transaction => $transaction_obj);
}

1;

package RT::Lorzy;
use strict;
use warnings;

use RT::Ruleset;
use Lorzy::Evaluator;

RT::Ruleset->add( name => 'Lorzy', rules => ['RT::Lorzy::Dispatcher'] );
our $EVAL = Lorzy::Evaluator->new();
$EVAL->load_package($_) for qw(Str Native);

sub evaluate {
    my ($self, $code, %args) = @_;
    my $ret = $EVAL->apply_script( $code, \%args );
    return $ret;
}

package RT::Lorzy::Rule;
use base 'Class::Accessor::Fast';
__PACKAGE__->mk_accessors(qw(condition action));

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    if (ref($self->action) eq 'CODE') {
        # XXX: signature compat check
        $self->action( Lorzy::Lambda::Native->new( body => $self->action,
                                                   signature => 
        { ticket => Lorzy::FunctionArgument->new( name => 'ticket', type => 'RT::Ticket' ) }

                                               ) );
    }
    return $self;
}

sub on_condition {
    my ($self, $ticket_obj, $transaction_obj) = @_;
    return RT::Lorzy->evaluate( $self->condition, ticket => $ticket_obj);
}

sub commit {
    my ($self, $ticket_obj, $transaction_obj) = @_;
    warn "==> committing action $ticket_obj";
    return RT::Lorzy->evaluate( $self->action, ticket => $ticket_obj);
}

1;

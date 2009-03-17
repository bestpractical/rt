package RT::Lorzy::Dispatcher;
use base 'RT::Rule';
use base 'RT::Ruleset';

my $rules;

sub reset_rules {
    $rules = [];
}

sub add_rule {
    my ($self, $rule) = @_;
    push @$rules, $rule;
}

sub prepare {
    my ($self, %args) = @_;
    for (@$rules) {
        push @{$self->{prepared}}, $_
            if $_->on_condition( $self->ticket_obj, $self->transaction );
    }
    return scalar @{$self->{prepared}};
}

sub commit {
    my ($self, %args) = @_;
    for ( @{$self->{prepared}} ) {
        $_->commit( $self->ticket_obj, $self->transaction );
    }
}

sub hints {
    my ($self, $callback) = @_;
    warn "... hi hints".$self->transaction->object;
    warn "... hi hints".$self->transaction;
    return unless $self->transaction->object;
    for ( @{$self->{prepared}} ) {
        $_->hints( $self->transaction->object, $self->transaction, $callback );
    }
}

1;

package RT::Lorzy::Dispatcher;
use base 'RT::Rule';
use base 'RT::Ruleset';

my $rules;

sub add_rule {
    my ($self, $rule) = @_;
    push @$rules, $rule;
}

sub prepare {
    my ($self, %args) = @_;
    for (@$rules) {
        push @{$self->{prepared}}, $_
            if $_->on_condition( $self->ticket_obj, $self->transaction_obj );
    }
    return scalar @{$self->{prepared}};
}

sub commit {
    my ($self, %args) = @_;
    for ( @{$self->{prepared}} ) {
        $_->commit( $self->ticket_obj, $self->transaction_obj );
    }
}

1;

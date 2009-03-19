package RT::Lorzy::Dispatcher;
use base 'RT::Ruleset';

my $rules = [];

sub reset_rules {
    $rules = [];
}

sub add_rule {
    my ($self, $rule) = @_;
    push @$rules, $rule;
}

sub rules {
    return $rules;
}

1;

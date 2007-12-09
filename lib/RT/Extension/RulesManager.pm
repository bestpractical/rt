package RT::Extension::RuleManager;
use YAML::Syck '1.00';

sub create {
    my $self = shift;
}

sub load {
    my $self  = shift;
    my $id    = shift;
    my $rules = $self->rules;
    return undef if $id <= 0 or $id >= @$rules;
    return $rules->[$id-1];
}

sub raise {
    my $self  = shift;
    my $id    = shift;
    my $rules = $self->rules;
    return undef if $id <= 1 or $id >= @$rules;
    @{$rules}[$id-1, $id-2] = @{$rules}[$id-2, $id-1];
    $rules->[$id-1]{_pos} = $id-1;
    $rules->[$id-2]{_pos} = $id-2;
    return $id;
}

sub named {
    my $self = shift;
    my $name = shift;
    foreach my $rule (@{$self->rules}) {
        return $rule if $rule->name eq $name;
    }
    return undef;
}

sub rules {
    my $self = shift;
    my $rules = $self->_load || [];
    for my $i (0..$#$rules) {
        $rules->[$i]{_pos} = $i;
        $rules->[$i]{_root} = $rules;
        bless $rules->[$i] => 'RT::Extension::RuleManager::Rule';
    }
    return $rules;
}

1;

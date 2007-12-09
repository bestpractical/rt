package RT::Extension::RuleManager;
use YAML::Syck '1.00';

sub create {
    my $self = shift;
}

sub load {
    my $self = shift;
    my $id   = shift;
}

sub named {
    my $self = shift;
    my $name = shift;
}

sub rules {
    my $self = shift;
    my $rules = $self->_load;
}

1;

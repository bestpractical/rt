package RT::View::Form::Field::SelectStatusSchema;
use warnings;
use strict;
use base 'Jifty::Web::Form::Field::Select';

sub _available_values {
    return [ map { { display => $_, value => $_ } } RT::Workflow->list ];
}

sub current_value {
    my $self          = shift;
    my $current_value = $self->SUPER::current_value(@_);

    $current_value = $current_value->name if ref $current_value;
    return $current_value;
}

1;


package RT::View::Form::Field::SelectOwner;
use warnings;
use strict;
use Jifty::View::Declare;
use base 'Jifty::Web::Form::Field::Select';
#use Jifty::View::Declare::Helpers;

sub _render_select_values {
    my $self = shift;
    my $rendered = '';

    my $current_value = $self->current_value;
    for my $value ($self->available_values) {
        $value = "" unless defined $value;
        $rendered .= qq!<option value="@{[ Jifty->web->escape($value) ]}"!;
        $rendered .= qq! selected="selected"!
          if defined $current_value
              && (
                  ref $current_value eq 'ARRAY'
                  ? ( grep { $value eq $_ } @$current_value )
                  : $current_value eq $value );
        $rendered .= qq!>!;

        my $user = RT::Model::User->new;
        $user->load($value);
        $rendered .= mason_scomp('/Elements/ShowUser', user => $user);

        $rendered .= qq!</option>\n!;
    }

    return $rendered;
}

sub render_value {
    my $self  = shift;
    my $field = '<span';
    $field .= qq! class="@{[ $self->classes ]}"> !;
    my $value = $self->current_value;
    if(defined $value) {
        my @value = grep { $_->{value} eq $value } $self->available_values;
        $value = $value[0]->{display} if scalar @value;
    }
    $field .= Jifty->web->escape(_($value)) if defined $value;
    $field .= qq!</span>\n!;
    Jifty->web->out($field);
    return '';
}

1;


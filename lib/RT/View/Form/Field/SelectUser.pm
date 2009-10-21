package RT::View::Form::Field::SelectUser;
use warnings;
use strict;
use base 'Jifty::Web::Form::Field::Select';

sub _render_user {
    my $self = shift;
    my $user = shift;

    if (!ref($user)) {
        my $user_object = RT::Model::User->new;
        $user_object->load($user);
        $user = $user_object;
    }

    return $user->name;
}

sub _render_select_values {
    my $self = shift;
    my $rendered = '';

    my $current_value = $self->current_value;
    for ($self->available_values) {
        my $value = $_->{value};
        $value = "" unless defined $value;
        $rendered .= qq!<option value="@{[ Jifty->web->escape($value) ]}"!;
        $rendered .= qq! selected="selected"!
          if defined $current_value
              && (
                  ref $current_value eq 'ARRAY'
                  ? ( grep { $value eq $_ } @$current_value )
                  : $current_value eq $value );
        $rendered .= qq!>!;

        $rendered .= $self->_render_user($value);

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
        $value = $self->_render_user($value[0]->{value}) if scalar @value;
    }
    $field .= Jifty->web->escape(_($value)) if defined $value;
    $field .= qq!</span>\n!;
    Jifty->web->out($field);
    return '';
}

1;


package RT::View::Form::Field::SelectOwner;
use warnings;
use strict;
use base 'Jifty::Web::Form::Field::Select';

sub render_widget {
    my $self  = shift;
    my $field = qq! <select !;
    $field .= qq! name="@{[ $self->input_name ]}"!;
    $field .= qq! id="@{[ $self->element_id ]}"!;
    $field .= qq! title="@{[ $self->title ]}"! if ($self->title);
    $field .= $self->_widget_class;
    $field .= $self->javascript;
    $field .= q! multiple="multiple"! if $self->multiple;
    $field .= qq!      >\n!;
    my $current_value = $self->current_value;
    for my $opt ($self->available_values) {
        my $display = ref($opt) ? $opt->{'display'} : $opt;
        my $value   = ref($opt) ? $opt->{'value'} : $opt;
        $value = "" unless defined $value;
        $field .= qq!<option value="@{[ Jifty->web->escape($value) ]}"!;
        $field .= qq! selected="selected"!
          if defined $current_value
              && (
                  ref $current_value eq 'ARRAY'
                  ? ( grep { $value eq $_ } @$current_value )
                  : $current_value eq $value );
        $field .= qq!>!;
        $field .= Jifty->web->escape(_($display)) if defined $display;
        $field .= qq!</option>\n!;
    }
    $field .= qq!</select>\n!;
    Jifty->web->out($field);
    '';
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


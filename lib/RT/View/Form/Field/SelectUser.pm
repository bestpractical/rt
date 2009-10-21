package RT::View::Form::Field::SelectUser;
use warnings;
use strict;
use base 'Jifty::Web::Form::Field::Select';
use Email::Address;

sub _render_user {
    my $self = shift;
    my $user = shift;

    if (!ref($user)) {
        my $user_object = RT::Model::User->new;
        $user_object->load($user);
        $user = $user_object;
    }

    my $style = RT->config->get('username_format', Jifty->web->current_user);
    return $self->_render_user_concise($user)
        if $style eq 'concise';
    return $self->_render_user_verbose($user);
}

sub _render_user_concise {
    my $self = shift;
    my $user = shift;

    if ($user->privileged) {
        return $user->real_name
            || $user->nickname
            || $user->name
            || $user->email;
    }

    return $user->email
        || $user->name
        || $user->real_name
        || $user->nickname;
}

sub _render_user_verbose {
    my $self = shift;
    my $user = shift;

    my ($phrase, $comment);
    my $addr = $user->email;

    $phrase = $user->real_name
        if $user->real_name
        && lc $user->real_name ne lc $addr;

    $comment = $user->name
        if lc $user->name ne lc $addr;

    $comment = "($comment)"
        if defined $comment and length $comment;

    my $address = Email::Address->new($phrase, $addr, $comment);

    $address->comment('')
        if $comment && lc $address->user eq lc $comment;

    if ( $phrase and my ($l, $r) = ($phrase =~ /^(\w+) (\w+)$/) ) {
        $address->phrase('')
            if $address->user =~ /^\Q$l\E.\Q$r\E$/
            || $address->user =~ /^\Q$r\E.\Q$l\E$/;
    }

    return $address->format;
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


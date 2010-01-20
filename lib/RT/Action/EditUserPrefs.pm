use strict;
use warnings;

package RT::Action::EditUserPrefs;
use base qw/RT::Action Jifty::Action/;


sub name {
    my $self = shift;
    Jifty->log->error('you need to subclass name');
    return;
}

=head2 take_action

=cut

sub take_action {
    my $self = shift;

    my $user = Jifty->web->current_user->user_object;
    my $pref = $user->preferences( $self->name ) || {};
    for my $arg ( $self->argument_names ) {
        if ( $self->has_argument($arg) ) {
            if ( $self->argument_value($arg) eq 'use_system_default' ) {
                delete $pref->{$arg};
            }
            else {
                $pref->{$arg} = $self->argument_value($arg);
            }
        }
    }
    $user->set_preferences( $self->name, $pref );
    $self->report_success if not $self->result->failure;

    return 1;
}

=head2 report_success

=cut

sub report_success {
    my $self = shift;

    # Your success message here
    $self->result->message( _('Updated user settings') );
}

sub default_value {
    my $self = shift;
    my $name = shift;
    my $pref =
      Jifty->web->current_user->user_object->preferences( $self->name );
    if ( $pref && exists $pref->{$name} ) {
        return $pref->{$name};
    }
    else {
        return 'use_system_default';
    }
}

1;

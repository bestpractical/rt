package RT::Action::UpdateUser;
use strict;
use warnings;

use base qw/Jifty::Action::Record::Update RT::Action::WithCustomFields/;

sub record_class { 'RT::Model::User' }

use constant report_detailed_messages => 1;

use Jifty::Param::Schema;
use Jifty::Action schema {
    param disabled =>
        render as 'Checkbox';
};

sub arguments {
    my $self = shift;
    if ( !$self->{_cached_arguments} ) {

        $self->{_cached_arguments} = $self->SUPER::arguments;
        my $user = RT::Model::User->new;
        my @args = $self->_setup_custom_fields( cfs => $user->custom_fields );
        for my $args (@args) {
            my $name = delete $args->{name};
            $self->{_cached_arguments}{$name} = $args;
        }
    }

    return $self->{_cached_arguments};
}

sub take_action {
    my $self = shift;
    $self->SUPER::take_action;
    $self->_add_custom_field_values;
    if ( $self->has_argument('disabled') ) {
        my ( $status, $msg ) =
          $self->record->set_disabled( $self->argument_value('disabled') );
        Jifty->log->error( $msg ) unless $status;
    }

    return 1;
}

1;

package RT::Action::UpdateGroup;
use strict;
use warnings;

use base qw/Jifty::Action::Record::Update RT::Action::WithCustomFields/;

sub record_class { 'RT::Model::Group' }

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
        my $group = RT::Model::Group->new;
        my @args = $self->_setup_custom_fields( cfs => $group->custom_fields );
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
    $self->_update_custom_field_values;
    if ( $self->has_argument('disabled') ) {
        my ( $status, $msg ) =
          $self->record->set_disabled( $self->argument_value('disabled') );
        Jifty->log->error( $msg ) unless $status;
    }
    return 1;
}

1;

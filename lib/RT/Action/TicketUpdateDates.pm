package RT::Action::TicketUpdateDates;
use strict;
use warnings;

use base qw/Jifty::Action::Record::Update/;

sub record_class { 'RT::Model::Ticket' }

=head2 take_action

=cut

sub take_action {
    my $self        = shift;
    my @date_fields = qw/told starts started due/;

    foreach my $field (@date_fields) {
        my $value = $self->argument_value($field);
        if ( defined $value ) {
            my $date = RT::Date->new();
            $date->set(
                format => 'unknown',
                value  => $value,
            );

            my $obj = $field . '_obj';
            if ( $date->unix != $self->record->$obj()->unix() ) {
                my $set = "set_$field";
                my ( $status, $msg ) = $self->record->$set( $date->iso );
                unless ($status) {
                    $self->result->failure(
                        _( 'Update [_1] failed: [_2]', $field, $msg ) );
                    last;
                }
            }
        }
    }

    $self->report_success unless $self->result->failure;
    return 1;
}

sub report_success {
    my $self = shift;

    # Your success message here
    $self->result->message( _('Dates Updated') );
}

1;

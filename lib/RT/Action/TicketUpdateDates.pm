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

# the date is not real utc, we set it as utc to get rid of user timezone
# convert, since record->$obj already get converted, it's wrong to convert
# it too.
            my $fake_utc_date = RT::Date->new();
            $fake_utc_date->set(
                format => 'unknown',
                value  => $value,
                timezone => 'UTC',
            );

            my $obj = $field . '_obj';
            if ( $fake_utc_date->unix != $self->record->$obj()->unix() ) {
                my $old = $self->record->$obj;
                my $set = "set_$field";
                my ( $status, $msg ) = $self->record->$set( $date->iso );
                if ($status) {
                    $self->result->content(
                        $field,
                        _(
                            "%1 changed from %2 to %3",
                            $field,
                            $old->unix
                            ? $old->iso
                            : _('Not Set'),
                            $fake_utc_date->unix ? $fake_utc_date->iso
                            : _('Not Set')
                        )
                    );
                }
                else {
                    $self->result->failure(
                        _( 'Update %1 failed: %2', $field, $msg ) );
                    last;
                }
            }
        }
    }

    unless ( $self->result->failure ) {
        $self->report_success;
    }
    return 1;
}

sub report_success {
    my $self = shift;

    # Your success message here
    $self->result->message( _('Dates Updated') );
}

1;

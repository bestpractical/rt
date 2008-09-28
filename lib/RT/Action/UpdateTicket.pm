package RT::Action::UpdateTicket;
use strict;
use warnings;

use base qw/Jifty::Action::Record::Update/;

sub record_class { 'RT::Model::Ticket' }

use constant report_detailed_messages => 1;

=head2 take_action

=cut

sub take_action {
    my $self        = shift;
    my @date_fields = qw/told starts started due/;

    foreach my $field (@date_fields) {
        my $value = $self->argument_value($field);
        if ( defined $value ) {
            # convert date to be as utc
            my $date = RT::Date->new();
            $date->set(
                format => 'unknown',
                value  => $value,
            );

            $self->argument_value( $field, $date->iso );
        }
    }

    $self->SUPER::take_action;
    return 1;
}

1;

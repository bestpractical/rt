package RT::Action::UpdateTicket;
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

sub report_success {
    my $self = shift;

    # Your success message here
    $self->result->message( _('Dates Updated') );
}

sub detailed_messages {
    my $self          = shift;
    my $result = {Jifty->web->response->results}->{$self->moniker};
    my @results;
    if ($result) {
        for my $type ( sort keys %{ $result->content->{detailed_messages} } ) {
            push @results, $result->content->{detailed_messages}{$type};
        }
    }
    return @results;
}

sub report_detailed_messages {
    return 1;
}

1;

package RT::Action::CreateTicket;
use strict;
use warnings;
use base 'RT::Action::QueueBased', 'Jifty::Action::Record::Create';

use constant record_class => 'RT::Model::Ticket';
use constant report_detailed_messages => 1;

use Jifty::Param::Schema;
use Jifty::Action schema {
    param status =>
        render as 'select',
        valid_values are 'new', 'open'; # XXX
};

sub after_set_queue {
    my $self  = shift;
    my $queue = shift;
    $self->SUPER::after_set_queue(@_);
    # set valid statuses
}

1;


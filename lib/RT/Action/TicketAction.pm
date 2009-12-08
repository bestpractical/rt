package RT::Action::TicketAction;
use strict;
use warnings;
use base 'RT::Action::QueueBased', 'RT::Action::WithCustomFields';

use constant record_class => 'RT::Model::Ticket';
use constant report_detailed_messages => 1;

1;


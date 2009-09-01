package RT::Action::CreateTicket;
use strict;
use warnings;
use base 'Jifty::Action::Record::Create';

use constant record_class => 'RT::Model::Ticket';
use constant report_detailed_messages => 1;

1;


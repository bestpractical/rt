package RT::Action::CreateTicket;
use strict;
use warnings;

use base qw/Jifty::Action::Record::Create/;

sub record_class { 'RT::Model::Ticket' }

use constant report_detailed_messages => 1;

1;


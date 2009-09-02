package RT::Action::CreateTicket;
use strict;
use warnings;
use base 'Jifty::Action::Record::Create';

use constant record_class => 'RT::Model::Ticket';
use constant report_detailed_messages => 1;

use Jifty::Param::Schema;
use Jifty::Action schema {
    param queue =>
        render as 'text',
        is mandatory,
        default is defer {
            my $queue = Jifty->web->request->argument('queue');
            $queue = $queue->[0] if ref $queue eq 'ARRAY';
            $queue;
        };
};

1;


package RT::Action::CreateTicket;
use strict;
use warnings;
use base 'Jifty::Action::Record::Create';

use constant record_class => 'RT::Model::Ticket';
use constant report_detailed_messages => 1;

use Jifty::Param::Schema;
use Jifty::Action schema {
    param id =>
        render as 'hidden',
        default is defer {
            my $id = Jifty->web->request->argument('id');
            $id = $id->[0] if ref $id eq 'ARRAY';
            $id;
        };

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


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
        render_mode is 'read',
        default is defer {
            my $queue = Jifty->web->request->argument('queue');
            $queue = $queue->[0] if ref $queue eq 'ARRAY';
            $queue;
        };
};

sub set_queue {
    my $self  = shift;
    my $queue = shift;

    if (!ref($queue)) {
        my $queue_obj = RT::Model::Queue->new;
        $queue_obj->load($queue);
        $queue = $queue_obj;
    }

    my @valid_statuses = $queue->status_schema->valid;
}

1;


package RT::Action::UpdateTicket;
use strict;
use warnings;
use base 'RT::Action::TicketAction', 'Jifty::Action::Record::Update';

sub _compute_possible_queues {
    my $self = shift;

    my $q = RT::Model::QueueCollection->new;
    $q->find_all_rows;

    my $queues;

    my $current_queue = $self->record->queue;
    push @$queues, {
        display => _('%1 (unchanged)', $current_queue->name),
        value => $current_queue->id,
    };

    while (my $queue = $q->next) {
        if (   $queue->current_user_has_right('CreateTicket')
            && $queue->id ne $current_queue->id )
        {
            push @$queues, { display => $queue->name, value => $queue->id };
        }
    }

    return $queues;
}

1;

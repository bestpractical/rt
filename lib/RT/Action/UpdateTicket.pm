package RT::Action::UpdateTicket;
use strict;
use warnings;
use base 'RT::Action::TicketAction', 'Jifty::Action::Record::Update';

use Jifty::Param::Schema;
use Jifty::Action schema {
    param id =>
        render as 'hidden',
        is constructor;

    param status =>
        render as 'select',
        label is _('Status');

    param owner =>
        render as 'RT::View::Form::Field::SelectUser',
        # valid_values are queue-specific
        valid_values are lazy { RT->nobody->id },
        label is _('Owner');

    param subject =>
        render as 'text',
        display_length is 60,
        max_length is 200,
        label is _('Subject');
};

sub arguments {
    my $self = shift;
    return $self->Jifty::Action::Record::Update::arguments(@_);

    if (!$self->{_cached_arguments}) {
        my $ticket_args = $self->RT::Action::TicketAction::arguments(@_);
        my $update_args = $self->Jifty::Action::Record::Update::arguments(@_);

        $self->{_cached_arguments} = Jifty::Param::Schema::merge_params(
            $update_args,
            $ticket_args,
        );
    }

    return $self->{_cached_arguments};
}

sub _valid_statuses {
    my $self = shift;

    my $record = $self->record;
    return (
        $record->status,
        $record->queue->status_schema->transitions($record->status),
    );
}

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

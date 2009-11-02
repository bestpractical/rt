package RT::Action::QueueBased;
use strict;
use warnings;
use base 'Jifty::Action';

use Jifty::Param::Schema;
use Jifty::Action schema {
    param queue =>
        render as 'text',
        render_mode is 'read',
        is constructor,
        label is _('Queue');
};

sub arguments {
    my $self = shift;

    if (!$self->{_cached_arguments}) {
        # The blank slate is the parameters provided using Jifty::Param::Schema
        $self->{_cached_arguments} = \%{ $self->PARAMS };

        # The two cases are:
        # 1. Some template called set_queue on this action. The template
        #    has told us which queue to use. We do not want to guess the
        #    queue based on request parameters. We also do not want to call
        #    set_queue since we have just been called by set_queue.
        # 2. Jifty inspected this action's arguments and we are plucking
        #    the queue out of the request. We need to call set_queue to
        #    inform the rest of the arguments of the queue so they can
        #    adjust valid values, etc.
        # We do not want to call set_queue twice. That will cause
        # after_set_queue to be called twice, and that leads to a lot of
        # duplicate work and possibly duplicate data.
        my $already_setting_queue = (caller(1))[3] eq __PACKAGE__.'::set_queue';
        my $action = Jifty->web->request->action($self->moniker);
        my $queue = $action ? $action->argument('queue') : 0;

        if (!$already_setting_queue && $queue) {
            $queue = $queue->[0] if ref $queue eq 'ARRAY';
            $self->set_queue($queue);
        }
    }

    return $self->{_cached_arguments};
}

sub queue {
    my $self = shift;
    return $self->{_cached_arguments}{queue}{default_value}
        if $self->{_cached_arguments};
    return;
}

sub set_queue {
    my $self  = shift;
    my $queue = shift;

    if (!ref($queue)) {
        my $queue_obj = RT::Model::Queue->new;
        $queue_obj->load($queue);
        $queue = $queue_obj;
    }

    # Prep the arguments cache
    $self->arguments if !$self->{_cached_arguments};

    $self->fill_parameter(queue => default_value => $queue->name);

    # Let the action invoke all its queue-specific logic
    $self->after_set_queue($queue);

    return $queue;
}

sub fill_parameter {
    my $self = shift;
    my $name = shift;

    $self->{_cached_arguments}{$name} = {
        %{ $self->{_cached_arguments}{$name} || {} },
        @_,
    };
}

# This is empty so that users can always redispatch cleanly
sub after_set_queue {}

1;


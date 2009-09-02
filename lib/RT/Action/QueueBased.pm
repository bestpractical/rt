package RT::Action::QueueBased;
use strict;
use warnings;
use base 'Jifty::Action';

use Jifty::Param::Schema;
use Jifty::Action schema {
    param queue =>
        render as 'text',
        render_mode is 'read';
};

sub arguments {
    my $self = shift;

    if (!$self->{_cached_arguments}) {
        $self->{_cached_arguments} = \%{ $self->PARAMS };

        if (Jifty->web->request->argument('queue')) {
            my $queue = Jifty->web->request->argument('queue');
            $queue = $queue->[0] if ref $queue eq 'ARRAY';
            $self->set_queue($queue);
        }
    }

    return $self->{_cached_arguments};
}

sub set_queue {
    my $self  = shift;
    my $queue = shift;

    if (!ref($queue)) {
        my $queue_obj = RT::Model::Queue->new;
        $queue_obj->load($queue);
        $queue = $queue_obj;
    }

    $self->after_set_queue($queue);

    return $queue;
}

sub after_set_queue {}

1;


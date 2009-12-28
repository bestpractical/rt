use strict;
use warnings;

package RT::Action::EditQueueGnuPG;
use base qw/RT::Action Jifty::Action/;
use Scalar::Defer;

__PACKAGE__->mk_accessors('queue');

sub arguments {
    my $self = shift;
    return {} unless $self->queue;

    my $args = {};
    $args->{queue_id} = {
        render_as     => 'hidden',
        default_value => $self->queue->id,
    };

    for my $type (qw/sign encrypt/) {
        $args->{$type} = {
            render_as        => 'Checkbox',
            default_value    => defer { $self->queue->$type },
        };
    }
    return $args;
}

=head2 take_action

=cut

sub take_action {
    my $self = shift;

    my $queue = RT::Model::Queue->new;
    my $id    = $self->argument_value('queue_id');
    $queue->load($id);
    unless ( $queue->id ) {
        Jifty->log->error("couldn't load queue #$id");
        return;
    }

    $self->queue($queue);

    for my $type (qw/sign encrypt/) {
        my $method = "set_$type";
        my ( $status, $msg ) =
          $self->queue->$method( $self->argument_value($type) );
        Jifty->log->error( $msg ) unless $status;
    }
    $self->report_success;

    return 1;
}

=head2 report_success

=cut

sub report_success {
    my $self = shift;

    # Your success message here
    $self->result->message('Success');
}

1;


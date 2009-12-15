use strict;
use warnings;

package RT::Action::EditWorkflowStatuses;
use base qw/RT::Action Jifty::Action/;
use RT::Workflow;
use Scalar::Defer;

__PACKAGE__->mk_accessors('name');

sub arguments {
    my $self = shift;
    return {} unless $self->name;
    my $args = {
        name => {
            render_as     => 'hidden',
            default_value => $self->name,
        },
    };

    my $schema = RT::Workflow->new->load( $self->name );

    for my $type (qw/initial active inactive/) {
        $args->{$type} =
          { default_value => defer { ( join ', ', $schema->$type ) || '' }, };
    }

    return $args;
}

=head2 take_action

=cut

sub take_action {
    my $self = shift;

    my $name = $self->argument_value('name');
    return unless $name;

    my $schema = RT::Workflow->new->load( $name );
    my %tmp;
    foreach my $type ( qw(initial active inactive) ) {
        $tmp{$type} = [
            grep length && defined,
            map { s/^\s+//; s/\s+$//; $_ }
              split /\s*,\s*/,
            $self->argument_value($type),
        ];
    }
    my ($status, $msg) = $schema->set_statuses( %tmp );
    unless ($status) {
        Jifty->log->error(
            'failed to set statuses for workflow ' . $name . ': ' . $msg );
        return;
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


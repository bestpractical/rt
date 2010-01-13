use strict;
use warnings;

package RT::Action::CreateWorkflow;
use base qw/RT::Action Jifty::Action/;
use RT::Workflow;

__PACKAGE__->mk_accessors('name');

sub arguments {
    my $self = shift;
    return { name => { } };
}

=head2 take_action

=cut

sub take_action {
    my $self = shift;

    my $name = $self->argument_value('name');
    my $schema = RT::Workflow->new;
    my ($status, $msg) = $schema->create( name => $name );

    unless ($status) {
        Jifty->log->error(
            'failed to create workflow ' . $name . ': ' . $msg );
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
    $self->result->message(_('Created workflow %1', $self->record->name));
}

1;


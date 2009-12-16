use strict;
use warnings;

package RT::Action::SelectWorkflowMappings;
use base qw/RT::Action Jifty::Action/;
use RT::Workflow;
use Scalar::Defer;

sub arguments {
    my $self = shift;
    my $args = {};
    for (qw/from to/) {
        $args->{$_} = {
            render_as     => 'Select',
            available_values => defer { [ RT::Workflow->list ] }
        };
    }
    return $args;
}

=head2 take_action

=cut

sub take_action {
    my $self = shift;

    my $from = $self->argument_value('from');
    my $to   = $self->argument_value('to');
    return unless $from && $to;
    Jifty->web->_redirect(
        "/admin/global/workflows/mappings?from=$from&to=$to&",
    );
}

1;


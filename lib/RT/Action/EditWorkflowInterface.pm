use strict;
use warnings;

package RT::Action::EditWorkflowInterface;
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
    my @valid  = $schema->valid;

    for my $from (@valid) {
        my @next = $schema->transitions($from);
        for my $to (@next) {
            $args->{ $from . '___label___' . $to } = {
                default_value => defer {
                    $schema->transition_label( $from => $to );
                },
                label => '',
            };
        }
    }

    for my $from (@valid) {
        my @next = $schema->transitions($from);
        for my $to (@next) {
            $args->{ $from . '___action___' . $to } = {
                default_value => defer {
                    $schema->transition_action( $from => $to );
                },
                render_as        => 'Select',
                available_values => [
                    {
                        value   => '',
                        display => _('no action')
                    },
                    map { { value => $_, display => _($_) } }
                      qw/hide comment respond/
                ],
                label => '',
            };
        }
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
    my %tmp    = ();

    my @valid = $schema->valid;
    foreach my $from (@valid) {
        foreach my $to (@valid) {
            next if $from eq $to;
            $tmp{ $from . ' -> ' . $to }[0] =
              $self->argument_value( $from . '___label___' . $to );
            $tmp{ $from . ' -> ' . $to }[1] =
              $self->argument_value( $from . '___action___' . $to );
        }
    }

    my ( $status, $msg ) = $schema->set_actions(%tmp);
    unless ($status) {
        Jifty->log->error(
            'failed to set actions for workflow ' . $name . ': ' . $msg );
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
    $self->result->message(_('Updated workflow interface'));
}

1;


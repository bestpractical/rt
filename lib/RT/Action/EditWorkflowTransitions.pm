use strict;
use warnings;

package RT::Action::EditWorkflowTransitions;
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
        $args->{$from} = {
            default_value    => defer { [ $schema->transitions($from) ] },
            available_values => [
                map { { display => _($_), value => $_ } }
                grep { $_ ne $from } @valid
            ],
            render_as => 'Checkboxes',
            label     => '',
        };
    }

    return $args;
}

=head2 take_action

=cut

sub take_action {
    my $self = shift;

    my $name = $self->argument_value('name');
    return unless $name;

    my $schema = RT::Workflow->new->load($name);
    my %tmp    = ();
    my @valid  = $schema->valid;
    for my $status (@valid) {
        my $v    = $self->argument_value($status);
        my @list = grep $schema->is_valid($_),
          $v ? ( ref $v ? @{$v} : ($v) ) : ();
        $tmp{$status} = \@list;
    }
    my ( $status, $msg ) = $schema->set_transitions(%tmp);

    unless ($status) {
        Jifty->log->error(
            'failed to set transitions for workflow ' . $name . ': ' . $msg );
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


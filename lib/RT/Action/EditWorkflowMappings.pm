use strict;
use warnings;

package RT::Action::EditWorkflowMappings;
use base qw/RT::Action Jifty::Action/;
use RT::Workflow;
use Scalar::Defer;

__PACKAGE__->mk_accessors('from', 'to');

sub arguments {
    my $self = shift;
    return {} unless $self->from && $self->to;
    my $args = {};
    for (qw/from to/) {
        $args->{$_} = {
            render_as     => 'hidden',
            default_value => $self->$_,
        };
    }

    my $from_schema = RT::Workflow->new->load($self->from);
    my $to_schema = RT::Workflow->new->load( $self->to );
    return $args unless $from_schema && $to_schema;


    for my $status ( $from_schema->valid ) {
        $args->{"from_$status"} = {
            default_value => defer {
                my $current = $from_schema->map($to_schema)->{ lc $status };
                unless ($current) {
                    if ( $to_schema->is_valid($status) ) {
                        $current = $status;
                    }
                    else {
                        $current =
                          ( $to_schema->valid( $from_schema->from_set($status) ) )
                          [0];
                    }
                }
                return $current;
            },
            available_values => defer {
                [ map { { display => _($_), value => $_ } } $to_schema->valid ];
            },
            label => _($status) . ' -> ',
            render_as => 'Select',
        };
    }

    for my $status ( $to_schema->valid ) {
        $args->{"to_$status"} = {
            default_value => defer {
                my $current = $to_schema->map($from_schema)->{ lc $status };
                unless ($current) {
                    if ( $from_schema->is_valid($status) ) {
                        $current = $status;
                    }
                    else {
                        $current =
                          ( $from_schema->valid( $to_schema->from_set($status) ) )
                          [0];
                    }
                }
                return $current;
            },
            available_values => defer {
                [ map { { display => _($_), value => $_ } } $from_schema->valid ];
            },
            label => _($status) . ' -> ',
            render_as => 'Select',
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

    my $from_schema = RT::Workflow->new->load($from);
    my $to_schema   = RT::Workflow->new->load($to);

    my %map = ();
    foreach my $s ( $from_schema->valid ) {
        $map{ lc $s } = $self->argument_value("from_$s");
    }
    my ( $status, $msg ) = $from_schema->set_map( $to_schema, %map );
    unless ($status) {
        Jifty->log->error(
            "failed to set mapping for workflow $from -> $to: " . $msg );
        return;
    }

    %map = ();
    foreach my $s ( $to_schema->valid ) {
        $map{ lc $s } = $self->argument_value("to_$s");
    }

    ( $status, $msg ) = $to_schema->set_map( $from_schema, %map );
    unless ($status) {
        Jifty->log->error(
            "failed to set mapping for workflow $to -> $from " . $msg );
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


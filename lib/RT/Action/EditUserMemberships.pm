
use strict;
use warnings;

package RT::Action::EditUserMemberships;
use base qw/RT::Action Jifty::Action/;
use Scalar::Defer;

__PACKAGE__->mk_accessors('record');

sub arguments {
    my $self = shift;
    return {} unless $self->record;

    my $args = {};
    $args->{record_id} = {
        render_as     => 'hidden',
        default_value => $self->record->id,
    };
    $args->{record_class} = {
        render_as     => 'hidden',
        default_value => ref $self->record,
    };

    $args->{groups} = {
        render_as        => 'Checkboxes',
        default_value    => defer { $self->default_value },
        available_values => defer { $self->available_values },
    };
    return $args;
}

=head2 take_action

=cut

sub take_action {
    my $self = shift;

    my $record_class = $self->argument_value('record_class');
    return unless $record_class;
    if ( $RT::Model::ACE::OBJECT_TYPES{$record_class} ) {
        my $object    = $record_class->new;
        my $record_id = $self->argument_value('record_id');
        $object->load($record_id);
        unless ( $object->id ) {
            Jifty->log->error("couldn't load $record_class #$record_id");
            return;
        }

        $self->record($object);
    }
    else {
        Jifty->log->error("record class '$record_class' is incorrect");
        return;
    }

    my $value = $self->argument_value('groups');
    my @groups;
    if ( UNIVERSAL::isa( $value, 'ARRAY' ) ) {
        @groups = @$value;
    }
    else {
        @groups = $value;
    }
    @groups = grep { $_ && /^\d+$/ } @groups;

    my $current_groups = $self->default_value();
    my %current_groups = map { $_ => 1 } @$current_groups;
    my %groups         = map { $_ => 1 } @groups;

    my %group_objects;
    for my $id ( @$current_groups, @groups ) {
        next if $group_objects{$id};
        my $group = RT::Model::Group->new;
        $group->load($id);
        $group_objects{$id} = $group;
    }

    for my $group ( keys %current_groups ) {
        next if $groups{$group};

        my ( $val, $msg ) =
          $group_objects{$group}->delete_member( $self->record->id );
        Jifty->log->error($msg) unless $val;
    }

    for my $group ( keys %groups ) {
        next if $current_groups{$group};
        my ( $val, $msg ) =
          $group_objects{$group}->add_member( $self->record->id );
        Jifty->log->error($msg) unless $val;
    }

    $self->report_success;
    return 1;
}

=head2 report_success

=cut

sub report_success {
    my $self = shift;

    # Your success message here
    $self->result->message(_('Updated user memberships'));
}

sub available_values {
    my $self   = shift;
    my $object = $self->record;
    my $groups = RT::Model::GroupCollection->new;
    $groups->limit_to_user_defined_groups;
    return [ map { { display => $_->name, value => $_->id } }
          @{ $groups->items_array_ref } ];
}

sub default_value {
    my $self      = shift;
    my $is_member = RT::Model::GroupCollection->new;
    $is_member->limit_to_user_defined_groups;
    $is_member->with_member( principal => $self->record->id );
    return [ map { $_->id } @{ $is_member->items_array_ref } ];
}

1;


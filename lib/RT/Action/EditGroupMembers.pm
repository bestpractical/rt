
use strict;
use warnings;

package RT::Action::EditGroupMembers;
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

    $args->{users} = {
        render_as        => 'Checkboxes',
        default_value    => defer { $self->default_value('user') },
        available_values => defer { $self->available_values('user') },
    };
    $args->{groups} = {
        render_as        => 'Checkboxes',
        default_value    => defer { $self->default_value('group') },
        available_values => defer { $self->available_values('group') },
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

    for my $type (qw/user group/) {
        my $value = $self->argument_value($type . 's');
        my @members;
        if ( UNIVERSAL::isa( $value, 'ARRAY' ) ) {
            @members = @$value;
        }
        else {
            @members = $value;
        }
        @members = grep { $_ && /^\d+$/ } @members;

        my $current_members = $self->default_value($type);
        my %current_members = map { $_ => 1 } @$current_members;
        my %members         = map { $_ => 1 } @members;

        for my $member ( keys %current_members ) {
            next if $members{$member};

            my ( $val, $msg ) =
              $self->record->delete_member( $member );
            Jifty->log->error($msg) unless $val;
        }

        for my $member ( keys %members ) {
            next if $current_members{$member};
            my ( $val, $msg ) =
              $self->record->add_member( $member );
            Jifty->log->error($msg) unless $val;
        }
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

sub available_values {
    my $self   = shift;
    my $type   = shift || 'user';

    my $collection;
    if ( $type eq 'user' ) {
        $collection = RT::Model::UserCollection->new;
        $collection->limit(
            column           => 'id',
            value            => RT->system_user->id,
            operator         => '!=',
            entry_aggregator => 'AND'
        );
        $collection->limit(
            column           => 'id',
            value            => RT->nobody->id,
            operator         => '!=',
            entry_aggregator => 'AND'
        );
        $collection->limit_to_privileged();
    }
    else {
        $collection = RT::Model::GroupCollection->new;

        # self-recursive group membership considered harmful!
        $collection->limit(
            column   => 'id',
            value    => $self->record->id,
            operator => '!='
        );
        $collection->limit(
            column   => 'domain',
            operator => '=',
            value    => 'UserDefined'
        );
    }
    return [ map { { display => $_->name, value => $_->id } }
          @{ $collection->items_array_ref } ];
}

sub default_value {
    my $self = shift;
    my $type = shift || 'user';
    my @values;
    if ( $type eq 'user' ) {
        my $users = $self->record->user_members( recursively => 0 );
        $users->order_by( column => 'name', order => 'ASC'  );
        while ( my $user = $users->next ) {
            push @values, $user->id;
        }
    }
    else {
        my $group_members = $self->record->members;
        $group_members->limit_to_groups();
        while ( my $member = $group_members->next ) {
            push @values, $member->member_id;
        }
    }
    return \@values;
}

1;


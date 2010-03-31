use strict;
use warnings;

package RT::Action::SelectObjectCustomFields;
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

    my ( $object_name ) = $self->record->lookup_type =~ /RT::Model::(\w+)-/;
    $args->{objects} = {
        render_as        => 'Checkboxes',
        default_value    => defer { $self->default_value },
        available_values => defer { $self->available_values },
        label            => _($object_name),
    };

    return $args;
}

=head2 take_action

=cut

sub take_action {
    my $self = shift;

    my $object    = RT::Model::CustomField->new;
    my $record_id = $self->argument_value('record_id');
    if ($record_id) {
        $object->load($record_id);
        unless ( $object->id ) {
            Jifty->log->error("couldn't load cf #$record_id");
            return;
        }
    }
    $self->record($object);

    my @ids;
    my $value = $self->argument_value('objects');
    if ( UNIVERSAL::isa( $value, 'ARRAY' ) ) {
        @ids = @$value;
    }
    else {
        @ids = $value;
    }

    @ids = grep $_, @ids;

    my $current = $self->default_value;
    my %current = map { $_ => 1 } @$current;
    my %ids     = map { $_ => 1 } @ids;

    my $objects = $self->available_objects;
    while ( my $object = $objects->next ) {
        my $id = $object->id;
        if ( $ids{$id} ) {
            next if $current{$id};
            my ($val, $msg) = $self->record->add_to_object($object);
            Jifty->log->error($msg) unless $val;
        }
        else {
            next unless $current{$id};
            my ($val, $msg) = $self->record->remove_from_object($object);
            Jifty->log->error($msg) unless $val;
        }
    }

    $self->report_success;
    return 1;
}

sub available_objects {
    my $self = shift;
    if ( $self->record->lookup_type =~ /^(.*?)-/ ) {
        my $class = $1;
        my $collection_class;
        if ( UNIVERSAL::can( $class . 'Collection', 'new' ) ) {
            $collection_class = $class . 'Collection';

        }
        elsif ( UNIVERSAL::can( $class . 'es', 'new' ) ) {
            $collection_class = $class . 'es';

        }
        elsif ( UNIVERSAL::can( $class . 's', 'new' ) ) {
            $collection_class = $class . 's';

        }
        else {
            Jifty->log->error(
                _( "Can't find a collection class for '%1'", $class ) );
            return;
        }

        my $objects = $collection_class->new();
        $objects->find_all_rows;
        $objects->order_by( column => 'name' );
        return $objects;
    }
    else {
        Jifty->log->error(
            _(
                "object of type %1 cannot take custom fields",
                $self->record->lookup_type
            )
        );
        return;
    }
}

sub available_values {
    my $self    = shift;
    my $objects = $self->available_objects;
    if ($objects) {
        return [ map { { display => $_->name, value => $_->id } }
              @{ $objects->items_array_ref } ];
    }
    else {
        return [];
    }
}

sub default_value {
    my $self = shift;
    my $object_cfs;
    $object_cfs = RT::Model::ObjectCustomFieldCollection->new;
    $object_cfs->find_all_rows;
    $object_cfs->limit_to_custom_field($self->record->id);
    return [ map { $_->object_id } @{ $object_cfs->items_array_ref } ];
}

=head2 report_success

=cut

sub report_success {
    my $self = shift;

    # Your success message here
    $self->result->message(_('Updated object custom fields selection'));
}

1;


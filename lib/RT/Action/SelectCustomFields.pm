use strict;
use warnings;

package RT::Action::SelectCustomFields;
use base qw/RT::Action Jifty::Action/;
use Scalar::Defer;

__PACKAGE__->mk_accessors('object', 'lookup_type');

sub arguments {
    my $self = shift;
    return {} unless $self->object;
    my $args = {};
    $args->{object_id} = {
        render_as     => 'hidden',
        default_value => $self->object->id,
    };
    $args->{object_type} = {
        render_as     => 'hidden',
        default_value => ref $self->object,
    };
    $args->{lookup_type} = {
        render_as     => 'hidden',
        default_value => $self->lookup_type,
    };

    my $global_cfs;
    if ( $self->object->id ) {
        $global_cfs = RT::Model::ObjectCustomFieldCollection->new;
        $global_cfs->find_all_rows;
        $global_cfs->limit_to_object_id(0);
        $global_cfs->limit_to_lookup_type($self->lookup_type);
    }

    my $object_cfs = RT::Model::ObjectCustomFieldCollection->new;
    $object_cfs->find_all_rows;
    $object_cfs->limit_to_object_id( $self->object->id );
    $object_cfs->limit_to_lookup_type($self->lookup_type);

    my $cfs = RT::Model::CustomFieldCollection->new;
    $cfs->limit_to_lookup_type( $self->lookup_type );
    $cfs->order_by( column => 'name' );
    my @global;
    my @selected;
    my @unselected;
    while ( my $cf = $cfs->next ) {

        if ( $global_cfs && $global_cfs->has_entry_for_custom_field( $cf->id ) )
        {
            push @global, { display => $cf->name, value => $cf->id };
        }
        elsif ( $object_cfs->has_entry_for_custom_field( $cf->id ) ) {
            push @selected, { display => $cf->name, value => $cf->id };
        }
        else {
            push @unselected, { display => $cf->name, value => $cf->id };
        }
    }

    if ($global_cfs) {
        $args->{global_cfs} = {
            default_value    => [@global],
            available_values => [@global],
            render_as        => 'Checkboxes',
            render_mode      => 'read',
            label            => _('Global Custom Fields'),
        };
    }
    $args->{cfs} = {
        default_value    => [@selected],
        available_values => [ @selected, @unselected ],
        render_as        => 'Checkboxes',
        multiple         => 1,
        label            => _('Custom Fields'),
    };

    return $args;
}

=head2 take_action

=cut

sub take_action {
    my $self = shift;

    my $object_type = $self->argument_value('object_type');
    return unless $object_type;
    my $lookup_type = $self->argument_value('lookup_type');
    return unless $lookup_type;
    $self->lookup_type($lookup_type);

    if ( $RT::Model::ACE::OBJECT_TYPES{$object_type} ) {
        my $object    = $object_type->new;
        my $object_id = $self->argument_value('object_id');
        if ($object_id) {
            $object->load($object_id);
            unless ( $object->id ) {
                Jifty->log->error("couldn't load $object_type #$object_id");
                return;
            }
        }
        $self->object($object);
    }
    else {
        Jifty->log->error("object type '$object_type' is incorrect");
        return;
    }

    my @ids;
    my $value = $self->argument_value('cfs');
    if ( UNIVERSAL::isa( $value, 'ARRAY' ) ) {
        @ids = @$value;
    }
    else {
        @ids = $value;
    }

    @ids = grep $_, @ids;

    my $current = $self->default_value();
    my %current = map { $_ => 1 } @$current;
    my %ids     = map { $_ => 1 } @ids;

    my $cfs = RT::Model::CustomFieldCollection->new;
    $cfs->limit_to_lookup_type( $self->lookup_type );
    $cfs->order_by( column => 'name' );
    my @selected;
    my @unselected;

    for my $id ( keys %current ) {
        next if $ids{$id};
        my $cf = RT::Model::CustomField->new;
        my ( $val, $msg ) = $cf->load($id);
        if ($val) {
            ( $val, $msg ) = $cf->remove_from_object( $self->object );
            Jifty->log->error($msg) unless $val;
        }
        else {
            Jifty->log->error($msg);
            next;
        }
    }

    for my $id ( keys %ids ) {
        next if $current{$id};
        my $cf = RT::Model::CustomField->new;
        my ( $val, $msg ) = $cf->load($id);
        if ($val) {
            ( $val, $msg ) = $cf->add_to_object( $self->object );
            Jifty->log->error($msg) unless $val;
        }
        else {
            Jifty->log->error($msg);
            next;
        }
    }
    $self->report_success;
    return 1;
}


sub default_value {
    my $self = shift;
    my $cfs  = RT::Model::CustomFieldCollection->new;
    $cfs->limit_to_lookup_type( $self->lookup_type );
    $cfs->order_by( column => 'name' );

    my $object_cfs = RT::Model::ObjectCustomFieldCollection->new;
    $object_cfs->find_all_rows;
    $object_cfs->limit_to_object_id( $self->object->id );
    $object_cfs->limit_to_lookup_type( $self->lookup_type );

    my @current;
    while ( my $cf = $cfs->next ) {
        if ( $object_cfs->has_entry_for_custom_field( $cf->id ) ) {
            push @current, $cf->id;
        }
    }
    return \@current;
}

=head2 report_success

=cut

sub report_success {
    my $self = shift;

    # Your success message here
    $self->result->message('Success');
}

1;


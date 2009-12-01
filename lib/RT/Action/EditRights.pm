
use strict;
use warnings;

package RT::Action::EditRights;
use base qw/RT::Action Jifty::Action/;
use Scalar::Defer;

__PACKAGE__->mk_accessors('object');

sub arguments {
    my $self = shift;
    $self->log->fatal(
        "Use one of the subclasses, EditUserRights or EditGroupRights" );
}

=head2 take_action

=cut

sub take_action {
    my $self = shift;

    my $object_type = $self->argument_value('object_type');
    return unless $object_type;
    if ( $object_type eq 'RT::System' ) {
        $self->object( RT->system );
    }
    elsif ( $RT::Model::ACE::OBJECT_TYPES{$object_type} ) {
        my $object =
          $object_type->new( current_user => Jifty->web->current_user );
        my $object_id = $self->argument_value('object_id');
        $object->load($object_id);
        unless ( $object->id ) {
            Jifty->log->error("couldn't load $object_type #$object_id");
            return;
        }

        $self->object($object);
    }
    else {
        Jifty->log->error("object type '$object_type' is incorrect");
        return;
    }

    for my $arg ( $self->argument_names ) {
        next
          unless ( $arg =~ /^rights_(\d+)$/ );

        my $principal_id = $1;

        my @rights;
        my $value = $self->argument_value($arg);
        if ( UNIVERSAL::isa( $self->argument_value($arg), 'ARRAY' ) ) {
            @rights = @$value;
        }
        else {
            @rights = $value;
        }

        @rights = grep $_, @rights;
        next unless @rights;

        my $principal =
          RT::Model::Principal->new( current_user => Jifty->web->current_user );
        $principal->load($principal_id);

        my $current_rights = $self->default_value($principal_id);
        my %current_rights = map { $_ => 1 } @$current_rights;
        my %rights         = map { $_ => 1 } @rights;

        for my $right ( keys %current_rights ) {
            next if $rights{$right};
            my ( $val, $msg ) =
              $principal->revoke_right( object => $self->object, right => $right );
            Jifty->log->error($msg) unless $val;
        }

        for my $right ( keys %rights ) {
            next if $current_rights{$right};
            my ( $val, $msg ) =
              $principal->grant_right( object => $self->object, right => $right );
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
    my $object = $self->object;
    my $rights = $object->available_rights;
    return [ sort keys %$rights ];
}

sub default_value {
    my $self  = shift;
    my $principal_id = shift;

    my $object = $self->object;
    my $acl_obj =
      RT::Model::ACECollection->new( current_user => Jifty->web->current_user );
    my $ACE = RT::Model::ACE->new( current_user => Jifty->web->current_user );
    $acl_obj->limit_to_object($object);
    $acl_obj->limit_to_principal( id => $principal_id );
    $acl_obj->order_by( column => 'right_name' );

    my @rights;
    while ( my $acl = $acl_obj->next ) {
        push @rights, $acl->right_name;
    }
    return [@rights];
}

1;


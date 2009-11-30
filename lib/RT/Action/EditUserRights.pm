
use strict;
use warnings;

package RT::Action::EditUserRights;
use base qw/RT::Action Jifty::Action/;
use Scalar::Defer;

sub arguments {
    my $self = shift;

    #    return $self->{__cached_arguments} if ( $self->{__cached_arguments} );
    my $args = {};

    my $privileged =
      RT::Model::Group->new( current_user => Jifty->web->current_user );
    $privileged->load_system_internal('privileged');
    my $users = $privileged->members;

    while ( my $user = $users->next ) {
        my $group =
          RT::Model::Group->new( current_user => Jifty->web->current_user );
        $group->load_acl_equivalence( $user->member );

        my $name = join '-',
          $group->principal_id, ref( $self->object ), $self->object->id;
        $args->{$name} = {
            default_value    => defer { $self->default_value($group) },
            available_values => defer { $self->available_values },
            render_as        => 'Select',
            multiple         => 1,
            label => $user->member->object->real_name,
        };
    }
    return $args;

    #    return $self->{__cached_arguments} = $args;
}

=head2 take_action

=cut

sub take_action {
    my $self = shift;

    for my $arg ( $self->argument_names ) {

    }

    return 1;
}

=head2 report_success

=cut

sub report_success {
    my $self = shift;

    # Your success message here
    $self->result->message('Success');
}

sub object {
    my $self = shift;
    if (@_) {
        $self->{object} = shift;
    }
    else {
        $self->{object};
    }
}

sub available_values {
    my $self   = shift;
    my $object = $self->object;
    my $rights = $object->available_rights;
    return [ sort keys %$rights ];
}

sub default_value {
    my $self  = shift;
    my $group = shift;

    my $object = $self->object;
    my $acl_obj =
      RT::Model::ACECollection->new( current_user => Jifty->web->current_user );
    my $ACE = RT::Model::ACE->new( current_user => Jifty->web->current_user );
    $acl_obj->limit_to_object($object);
    $acl_obj->limit_to_principal( id => $group->principal_id );
    $acl_obj->order_by( column => 'right_name' );

    my @rights;
    while ( my $acl = $acl_obj->next ) {
        push @rights, $acl->right_name;
    }
    return [@rights];
}

1;


package RT::IsPrincipal;

use strict;
use warnings;

=head1 NAME

RT::IsPrincipal - role for objects qualifying some principal

=head1 DESCRIPTION

This is role class with methods common to all principals, for
example User or Group.

=head1 METHODS

=head2 disabled

Returns true if this principal is disabled or false otherwise.

=cut

sub disabled {
    return shift->principal->disabled;
}

=head2 acl_equivalence_group

=cut

sub acl_equivalence_group {
    my $self = shift;

    my $res = RT::Model::Group->new;
    $res->load_acl_equivalence( $self );
    unless ( $res->id ) {
        Jifty->log->fatal( "No ACL equiv group for principal #". $self->id );
        return (undef, _("No ACL equiv group for principal #%1", $self->id));
    }
    return $res;
}

=head2 type_for_acl

Returns type for ACL records. For now only roles has type.

=cut

sub type_for_acl { return undef }

=head2 principal

Returns the L<RT::Model::Principal> object for this record.
Each record which share this role must have one principal record. Returns
undef on error.

=cut

sub principal {
    my $self = shift;

    unless ( $self->id ) {
        Jifty->log->error("Couldn't get principal for not loaded object");
        return undef;
    }

    my $res = RT::Model::Principal->new;
    $res->load_by_id( $self->id );
    unless ( $res->id ) {
        Jifty->log->fatal( 'No principal for '. ref($self) .' #' . $self->id );
        return undef;
    }
# do we really want to check this? it's job for validator
#    elsif ( $res->type ne 'User' ) {
#        Jifty->log->fatal( 'User #' . $self->id . ' has principal of ' . $res->type . ' type' );
#        return undef;
#    }
    return $res;
}

=head2 principal_id

Returns id of the principal record for this object.

=cut

sub principal_id {
    my $self = shift;
    return $self->id;
}

1;

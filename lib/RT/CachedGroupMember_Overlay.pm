# Copyright 1996-2002 Jesse Vincent <jesse@bestpractical.com>
# Released under the terms of the GNU Public License

no warnings qw(redefine);

=item Create PARAMHASH

Create takes a hash of values and creates a row in the database:

  'Group' is the "top level" group we're building the ccache for. This is an 
  RT::Group object

  'Member' is the RT::Principal  of the user or group we're adding
  to the cache.

  'ImmediateParent' is the RT::Principal of the group that this principal
  belongs to to get here

  int(11) 'Via' is an internal reference to CachedGroupMembers->Id of
  the "parent" record of this cached group member. It should be "0" if this
  member is a "direct" member of this group

  This routine should _only_ be called by GroupMember->Create

=cut

sub Create {
    my $self = shift;
    my %args = (
        Group           => '',
        Member          => '',
        ImmediateParent => '',
        Via             => '0',
        @_
    );

    unless ( $args{'Member'} && $args{'Member'}->Id ) {
        $RT::Logger->debug("$self->Create: bogus Member argument");
    }

    unless ( $args{'Group'} && $args{'Group'}->Id ) {
        $RT::Logger->debug("$self->Create: bogus Group argument");
    }

    unless ( $args{'ImmediateParent'} && $args{'ImmediateParent'}->Id ) {
        $RT::Logger->debug("$self->Create: bogus ImmediateParent argument");
    }
    my $id = $self->SUPER::Create(
        GroupId           => $args{'Group'}->Id,
        MemberId          => $args{'Member'}->Id,
        ImmediateParentId => $args{'ImmediateParent'}->Id,
        Via               => $args{'Via'},
    );

    unless ($id) {
        $RT::Logger->warn( "Couldn't create "
              . $args{'Member'}
              . " as a cached member of "
              . $args{'Group'}->Id . " via "
              . $args{'Via'} );
        return (undef);  #this will percolate up and bail out of the transaction
    }

    if ( $args{'Member'}->IsGroup() ) {
        my $GroupMembers = $args->{'Member'}->Object->MembersObj();
        while ( my $member = $GroupMembers->Next() ) {
            my $cached_member =
              RT::CachedGroupMember->new( $self->CurrentUser );
            my $c_id = $cached_member->Create(
                Group           => $args{'Group'},
                Member          => $member->PrincipalObj,
                ImmediateParent => $args{'Member'},
                Via             => $id
            );
            unless ($c_id) {
                return (undef);    #percolate the error upwards.
                     # the caller will log an error and abort the transaction
            }

        }
    }

    return ($id);

}

=head2 Delete

Deletes the current CachedGroupMember from the group it's in and cascades 
the delete to all submembers. This routine could be completely excised if
mysql supported foreign keys with cascading deletes.

=cut 

sub Delete {
    my $self = shift;

    my $member = $self->MemberObj();
    if ( $member->IsGroup ) {
        my $deletable = RT::CachedGroupMembers->new( $session->CurrentUser );

        $deletable->Limit(
            FIELD    => 'Via',
            OPERATOR => '=',
            VALUE    => $self->id
        );

        while ( my $kid = $deletable->Next ) {
            my $kid_err = $kid->Delete();
            unless ($kid_err) {
                $RT::Logger->error(
                    "Couldn't delete CachedGroupMember " . $kid->Id );
                return (undef);
            }
        }
    }
    my $err = $self->SUPER::Delete();
    unless ($err) {
        $RT::Logger->error( "Couldn't delete CachedGroupMember " . $self->Id );
        return (undef);
    }
    return ($err);

}

=head2 MemberObj  

Returns the RT::Principal object for this group member

=cut

sub MemberObj {
    my $self      = shift;
    my $principal = RT::Principal->new( $self->CurrentUser );
    $principal->Load( $self->MemberId );
    return ($principal);
}


1;

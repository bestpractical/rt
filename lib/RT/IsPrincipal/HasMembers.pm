use strict;
use warnings;

package RT::IsPrincipal::HasMembers;
use base 'RT::IsPrincipal';

use Scalar::Util qw(blessed);

=head2 members

Returns either an L<RT::Model::GroupMemberCollection> or L<RT::Model::CachedGroupMemberCollection>
object depending on 'recursively' argument of this group's members.

=cut

sub members {
    my $self = shift;
    my %args = ( recursively => 0, @_ );

    my $class = $args{'recursively'}
        ? 'RT::Model::CachedGroupMemberCollection'
        : 'RT::Model::GroupMemberCollection';

    #If we don't have rights, don't include any results
    # TODO XXX  WHY IS THERE NO ACL CHECK HERE?

    my $res = $class->new;
    $res->limit_to_members_of_group( $self->id );

    return $res;
}

=head2 group_members [recursively => 1]

Returns an L<RT::Model::GroupCollection> object of this group's members.
By default returns groups including all subgroups, but
could be changed with C<recursively> named argument.

B<Note> that groups are not filtered by type and result
may contain as well system groups and other.

=cut

sub group_members {
    my $self = shift;
    my %args = ( recursively => 1, @_ );

    my $groups = RT::Model::GroupCollection->new;
    my $members_table = $args{'recursively'} ? 'CachedGroupMembers' : 'GroupMembers';

    my $members_alias = $groups->new_alias($members_table);
    $groups->join(
        alias1  => $members_alias,
        column1 => 'member_id',
        alias2  => $groups->principals_alias,
        column2 => 'id',
    );
    $groups->limit(
        alias  => $members_alias,
        column => 'group_id',
        value  => $self->id,
    );
    $groups->limit(
        alias  => $members_alias,
        column => 'disabled',
        value  => 0,
    ) if $args{'recursively'};

    return $groups;
}


=head2 user_members

Returns an L<RT::Model::UserCollection> object of this group's members, by default
returns users including all members of subgroups, but could be
changed with C<recursively> named argument.

=cut

sub user_members {
    my $self = shift;
    my %args = ( recursively => 1, @_ );

    #If we don't have rights, don't include any results
    # TODO XXX  WHY IS THERE NO ACL CHECK HERE?

    my $members_table = $args{'recursively'} ? 'CachedGroupMembers' : 'GroupMembers';

    my $users         = RT::Model::UserCollection->new;
    my $members_alias = $users->new_alias($members_table);
    $users->join(
        alias1  => $members_alias,
        column1 => 'member_id',
        alias2  => $users->principals_alias,
        column2 => 'id',
    );
    $users->limit(
        alias  => $members_alias,
        column => 'group_id',
        value  => $self->id,
    );
    $users->limit(
        alias  => $members_alias,
        column => 'disabled',
        value  => 0,
    ) if $args{'recursively'};

    return ($users);
}


=head2 member_emails

Returns an array of the email addresses of all of this group's members

=cut

sub member_emails {
    my $self = shift;

    my %addresses;
    my $members = $self->user_members;
    while ( my $member = $members->next ) {
        $addresses{ $member->email } = 1;
    }
    return ( sort keys %addresses );
}

=head2 member_emails_as_string

Returns a comma delimited string of the email addresses of all users 
who are members of this group.

=cut

sub member_emails_as_string {
    my $self = shift;
    return ( join( ', ', $self->member_emails ) );
}

=head2 has_member

Takes an L<RT::Model::Principal> object or its id and optional 'recursively'
argument. Returns id of a GroupMember or CachedGroupMember record if that user
is a member of this group. By default lookup is not recursive.

Returns undef if the user isn't a member of the group or if the current
user doesn't have permission to find out. Arguably, it should differentiate
between ACL failure and non membership.

=cut

sub has_member {
    my $self      = shift;
    my %args      = (
        principal   => undef,
        recursively => 0,
        @_
    );

    Carp::confess("boo") unless defined $args{'principal'};

    my $id;
    if ( blessed $args{'principal'} ) {
        if ( $args{'principal'}->isa('RT::Model::Principal') ) {
            $id = $args{'principal'}->id;
        } elsif ( $args{'principal'}->isa('RT::IsPrincipal') ) {
            $id = $args{'principal'}->principal_id;
        } else {
            Jifty->log->error(
                "has_member was called with an object that"
                . " isn't a principal. It's ". ref $args{'principal'}
            );
            return undef;
        }
    } elsif ( $args{'principal'} !~ /\D/ ) {
        $id = $args{'principal'};
    } else {
        Jifty->log->error(
            "Group::has_member was called with an argument that"
              . " isn't a principal or its id. It's "
              . ( $args{'principal'} || '(undefined)' )
        );
        return undef;
    }
    return undef unless $id;

    my $class = $args{'recursively'}
        ? 'RT::Model::CachedGroupMember'
        : 'RT::Model::GroupMember';

    my $member_obj = new $class;
    $member_obj->load_by_cols(
        member_id => $id,
        group_id  => $self->id,
    );

    if ( my $member_id = $member_obj->id ) {
        return $member_id;
    } else {
        return (undef);
    }
}




=head2 add_member PRINCIPAL_ID

add_member adds a principal to this group.  It takes a single principal id.
Returns a two value array. the first value is true on successful 
addition or 0 on failure.  The second value is a textual status msg.

=cut

sub add_member {
    my $self       = shift;
    my $new_member = shift;

    # We should only allow membership changes if the user has the right
    # to modify group membership or the user is the principal in question
    # and the user has the right to modify his own membership
    return $self->_add_member( principal => $new_member )
        if $self->current_user_has_right('AdminGroupMembership');

    if ( $self->current_user->id == (blessed $new_member? $new_member->id : $new_member) ) {
        return $self->_add_member( principal => $new_member )
            if $self->current_user_has_right('ModifyOwnMembership');
    }

    return ( 0, _("Permission Denied") )
}

# A helper subroutine for add_member that bypasses the ACL checks
# this should _ONLY_ ever be called from Ticket/Queue AddWatcher
# when we want to deal with groups according to queue rights
# In the dim future, this will all get factored out and life
# will get better

# takes a paramhash of { principal => undef }

sub _add_member {
    my $self = shift;
    my %args = (
        principal => undef,
        @_
    );

    unless ( $self->id ) {
        Jifty->log->fatal( "Attempting to add a member to a group which wasn't loaded. 'oops'" );
        return ( 0, _("Group not found") );
    }

    my ($id, $principal, $object);
    if ( blessed $args{'principal'} ) {
        if ( $args{'principal'}->isa('RT::Model::Principal') ) {
            $principal = $args{'principal'};
            $object = $principal->object;
            $id = $principal->id;
        }
        elsif ( $args{'principal'}->isa('RT::IsPrincipal') ) {
            $object = $args{'principal'};
            $id = $args{'principal'}->principal_id;
        }
        else {
            Jifty->log->fatal("_add_member called with an object that is not principal.");
            return ( 0, _("System error") );
        }
        unless ( $object ) {
            Jifty->log->fatal("_add_member called with an object this is not loaded.");
            return ( 0, _("System error") );
        }
    }
    else {
        if ( $args{'principal'} =~ /\D/ ) {
            Jifty->log->fatal("_add_member called with a parameter that's not an object or an integer.");
            return ( 0, _("System error") );
        }

        $principal = RT::Model::Principal->new;
        $principal->load( $args{'principal'} );
        unless ( $principal->id ) {
            Jifty->log->error("Couldn't find that principal");
            return ( 0, _("Couldn't find that principal") );
        }
        $id = $principal->id;
        $object = $principal->object;
    }

    if ( $self->has_member( principal => $id) ) {
        #User is already a member of this group. no need to add it
        return ( 0, _("Group already has member: %1", $object->name) );
    }
    if ( $object->has_member( principal => $self->principal, recursively => 1 ) ) {
        #This group can't be made to be a member of itself
        return ( 0, _("Groups can't be members of their members") );
    }

    my $member_object = RT::Model::GroupMember->new;
    my ($gm_id, $msg) = $member_object->create(
        member => $object,
        group  => $self->principal,
    );
    if ($gm_id) {
        return ( 1, _( "Member added: %1", $object->name ) );
    } else {
        return ( 0, _("Couldn't add member to group") );
    }
}


=head2 delete_member PRINCIPAL_ID

Takes the principal id of a current user or group.
If the current user has apropriate rights,
removes that GroupMember from this group.
Returns a two value array. the first value is true on successful 
addition or 0 on failure.  The second value is a textual status msg.

=cut

sub delete_member {
    my $self      = shift;
    my $member_id = shift;

    # We should only allow membership changes if the user has the right
    # to modify group membership or the user is the principal in question
    # and the user has the right to modify his own membership
    unless ( ( $member_id == $self->current_user->id && $self->current_user_has_right('ModifyOwnMembership') )
        || $self->current_user_has_right('AdminGroupMembership') )
    {

        #User has no permission to be doing this
        return ( 0, _("Permission Denied") );
    }
    $self->_delete_member($member_id);
}

# A helper subroutine for delete_member that bypasses the ACL checks
# this should _ONLY_ ever be called from Ticket/Queue  DeleteWatcher
# when we want to deal with groups according to queue rights
# In the dim future, this will all get factored out and life
# will get better

sub _delete_member {
    my $self      = shift;
    my $member_id = shift;

    my $member_obj = RT::Model::GroupMember->new;

    $member_obj->load_by_cols(
        member_id => $member_id,
        group_id  => $self->id
    );

    #If we couldn't load it, return undef.
    unless ( $member_obj->id() ) {
        Jifty->log->debug("Group has no member with that id");
        return ( 0, _("Group has no such member") );
    }

    #Now that we've checked ACLs and sanity, delete the groupmember
    my $val = $member_obj->delete();

    if ($val) {
        return ( $val, _("Member deleted") );
    } else {
        Jifty->log->debug( "Failed to delete group " . $self->id . " member " . $member_id );
        return ( 0, _("Member not deleted") );
    }
}








1;

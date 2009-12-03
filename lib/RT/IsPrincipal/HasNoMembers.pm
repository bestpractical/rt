use strict;
use warnings;

package RT::IsPrincipal::HasNoMembers;
use base 'RT::IsPrincipal';

=head2 members

Returns an empty either an L<RT::Model::GroupMemberCollection>
or L<RT::Model::CachedGroupMemberCollection> object depending on
'recursively' argument.

=cut

sub members {
    my $self = shift;
    my %args = ( recursively => 0, @_ );

    my $class = $args{'recursively'}
        ? 'RT::Model::CachedGroupMemberCollection'
        : 'RT::Model::GroupMemberCollection';

    my $res = $class->new;
    $res->limit( column => 'id', value => 0 );
    return $res;
}

=head2 group_members [recursively => 1]

Returns an empty L<RT::Model::GroupCollection> object.

=cut

sub group_members {
    my $self = shift;
    my $groups = RT::Model::GroupCollection->new;
    $groups->limit( column => 'id', value => 0 );
    return $groups;
}


=head2 user_members

Returns an empty L<RT::Model::UserCollection> object.

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

Returns an empty list.

=cut

sub member_emails { return () }

=head2 member_emails_as_string

Returns an empty string.

=cut

sub member_emails_as_string { return '' }

=head2 has_member

Always return false value.
Takes an L<RT::Model::Principal> object or its id and optional 'recursively'
argument. Returns id of a GroupMember or CachedGroupMember record if that user
is a member of this group. By default lookup is not recursive.

Returns undef if the user isn't a member of the group or if the current
user doesn't have permission to find out. Arguably, it should differentiate
between ACL failure and non membership.

=cut

sub has_member { return 0 }

=head2 add_member

Returns false value and error message.

=cut

sub add_member {
    return ( 0, _("This principal can not have members") );
}

sub _add_member {
    return ( 0, _("This principal can not have members") );
}

=head2 delete_member PRINCIPAL_ID

Takes the principal id of a current user or group.
If the current user has apropriate rights,
removes that GroupMember from this group.
Returns a two value array. the first value is true on successful 
addition or 0 on failure.  The second value is a textual status msg.

=cut

sub delete_member  { return ( 0, _("This principal can not have members") ) }

sub _delete_member { return ( 0, _("This principal can not have members") ) }

1;

#$Header: /raid/cvsroot/rt/lib/RT/CachedGroupMembers.pm,v 1.2 2001/11/06 23:04:14 jesse Exp $

=head1 NAME

  RT::CachedGroupMembers - a collection of RT::GroupMember objects

=head1 SYNOPSIS

  use RT::CachedGroupMembers;

=head1 DESCRIPTION


=head1 METHODS


=begin testing

ok (require RT::CachedGroupMembers);

=end testing

=cut

no warnings qw(redefine);

# {{{ LimitToUsers

=head2 LimitToUsers

Limits this search object to users who are members of this group
This is really useful when you want to haave your UI seperate out
groups from users for display purposes

=cut

sub LimitToUsers {
    my $self = shift;

    my $principals = $self->NewAlias('Principals');
    $self->Join( ALIAS1 => 'main', FIELD1 => 'MemberId',
                 ALIAS2 => $principals, FIELD2 =>'Id');

    $self->Limit(       ALIAS => $principals,
                         FIELD => 'PrincipalType',
                         VALUE => 'User',
                         ENTRYAGGREGATOR => 'OR',
                         );
}

# }}}


# {{{ LimitToSystemGroups

=head2 LimitToSystemGroups

Limits this search object to Groups who are members of this group
This is really useful when you want to haave your UI seperate out
groups from users for display purposes

=cut

sub LimitToSystemGroups {
    my $self = shift;

    my $principals = $self->NewAlias('Principals');
    $self->Join( ALIAS1 => 'main', FIELD1 => 'MemberId',
                 ALIAS2 => $principals, FIELD2 =>'Id');

    $self->Limit(       ALIAS => $principals,
                         FIELD => 'PrincipalType',
                         VALUE => 'Group',
                         ENTRYAGGREGATOR => 'OR',
                         );
}

# }}}

# {{{ sub LimitToMembersOfGroup

=head2 LimitToMembersOfGroup PRINCIPAL_ID

Takes a Principal Id as its only argument. 
Limits the current search principals which are _directly_ members
of the group which has PRINCIPAL_ID as its principal id.

=cut

sub LimitToMembersOfGroup {
    my $self = shift;
    my $group = shift;

    return ($self->Limit( 
                         VALUE => $group,
                         FIELD => 'GroupId',
                         ENTRYAGGREGATOR => 'OR',
                         ));

}
# }}}

1;

#$Header: /raid/cvsroot/rt/lib/RT/GroupMembers.pm,v 1.2 2001/11/06 23:04:14 jesse Exp $

=head1 NAME

  RT::GroupMembers - a collection of RT::GroupMember objects

=head1 SYNOPSIS

  use RT::GroupMembers;

=head1 DESCRIPTION


=head1 METHODS


=begin testing

ok (require RT::GroupMembers);

=end testing

=cut

no warnings qw(redefine);

# {{{ LimitToUsers

=head2 LimitToUsers

Limits this search object to users who are members of this group

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

# {{{ sub NewItem 

sub NewItem  {
    my $self = shift;
    return(RT::GroupMember->new($self->CurrentUser))
}

# }}}
1;

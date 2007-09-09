use strict;


=head1 NAME

  RT::Model::GroupMemberCollection -- Class Description
 
=head1 SYNOPSIS

  use RT::Model::GroupMemberCollection

=head1 DESCRIPTION


=head1 METHODS

=cut

package RT::Model::GroupMemberCollection;

use RT::Model::GroupMember;
use base qw/RT::SearchBuilder/;


=head2 LimitToUsers

Limits this search object to users who are members of this group.
This is really useful when you want to have your UI separate out
groups from users for display purposes

=cut

sub LimitToUsers {
    my $self = shift;

    my $principals = $self->new_alias('Principals');
    $self->join( alias1 => 'main', column1 => 'MemberId',
                 alias2 => $principals, column2 =>'id');

    $self->limit(       alias => $principals,
                         column => 'PrincipalType',
                         value => 'User',
                         entry_aggregator => 'OR',
                         );
}

# }}}


# {{{ LimitToGroups

=head2 LimitToGroups

Limits this search object to Groups who are members of this group.
This is really useful when you want to have your UI separate out
groups from users for display purposes

=cut

sub LimitToGroups {
    my $self = shift;

    my $principals = $self->new_alias('Principals');
    $self->join( alias1 => 'main', column1 => 'MemberId',
                 alias2 => $principals, column2 =>'id');

    $self->limit(       alias => $principals,
                         column => 'PrincipalType',
                         value => 'Group',
                         entry_aggregator => 'OR',
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

    return ($self->limit( 
                         value => $group,
                         column => 'GroupId',
                         entry_aggregator => 'OR',
			             quote_value => 0
                         ));

}
# }}}

1;

# BEGIN LICENSE BLOCK
# 
# Copyright (c) 1996-2003 Jesse Vincent <jesse@bestpractical.com>
# 
# (Except where explictly superceded by other copyright notices)
# 
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
# 
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# Unless otherwise specified, all modifications, corrections or
# extensions to this work which alter its source code become the
# property of Best Practical Solutions, LLC when submitted for
# inclusion in the work.
# 
# 
# END LICENSE BLOCK
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

use strict;
no warnings qw(redefine);

# {{{ LimitToUsers

=head2 LimitToUsers

Limits this search object to users who are members of this group.
This is really useful when you want to haave your UI seperate out
groups from users for display purposes

=cut

sub LimitToUsers {
    my $self = shift;

    my $principals = $self->NewAlias('Principals');
    $self->Join( ALIAS1 => 'main', FIELD1 => 'MemberId',
                 ALIAS2 => $principals, FIELD2 =>'id');

    $self->Limit(       ALIAS => $principals,
                         FIELD => 'PrincipalType',
                         VALUE => 'User',
                         ENTRYAGGREGATOR => 'OR',
                         );
}

# }}}


# {{{ LimitToGroups

=head2 LimitToGroups

Limits this search object to Groups who are members of this group.
This is really useful when you want to haave your UI seperate out
groups from users for display purposes

=cut

sub LimitToGroups {
    my $self = shift;

    my $principals = $self->NewAlias('Principals');
    $self->Join( ALIAS1 => 'main', FIELD1 => 'MemberId',
                 ALIAS2 => $principals, FIELD2 =>'id');

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
			             QUOTEVALUE => 0
                         ));

}
# }}}

1;

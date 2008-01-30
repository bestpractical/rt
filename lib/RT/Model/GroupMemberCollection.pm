# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2007 Best Practical Solutions, LLC
#                                          <jesse@bestpractical.com>
#
# (Except where explicitly superseded by other copyright notices)
#
#
# LICENSE:
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
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/copyleft/gpl.html.
#
#
# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
#
# END BPS TAGGED BLOCK }}}

=head1 name

  RT::Model::GroupMemberCollection - a collection of RT::Model::GroupMember objects

=head1 SYNOPSIS

  use RT::Model::GroupMemberCollection;

=head1 description


=head1 METHODS



=cut

use warnings;
use strict;

package RT::Model::GroupMemberCollection;
use base qw/RT::SearchBuilder/;

# {{{ limit_ToUsers

=head2 limit_ToUsers

Limits this search object to users who are members of this group.
This is really useful when you want to have your UI separate out
groups from users for display purposes

=cut

sub limit_to_users {
    my $self = shift;

    my $principals = $self->new_alias('Principals');
    $self->join(
        alias1  => 'main',
        column1 => 'member_id',
        alias2  => $principals,
        column2 => 'id'
    );

    $self->limit(
        alias            => $principals,
        column           => 'principal_type',
        value            => 'User',
        entry_aggregator => 'OR',
    );
}

# }}}

# {{{ limit_ToGroups

=head2 limit_ToGroups

Limits this search object to Groups who are members of this group.
This is really useful when you want to have your UI separate out
groups from users for display purposes

=cut

sub limit_to_groups {
    my $self = shift;

    my $principals = $self->new_alias('Principals');
    $self->join(
        alias1  => 'main',
        column1 => 'member_id',
        alias2  => $principals,
        column2 => 'id'
    );

    $self->limit(
        alias            => $principals,
        column           => 'principal_type',
        value            => 'Group',
        entry_aggregator => 'OR',
    );
}

# }}}

# {{{ sub limit_ToMembersOfGroup

=head2 limit_ToMembersOfGroup PRINCIPAL_ID

Takes a Principal id as its only argument. 
Limits the current search principals which are _directly_ members
of the group which has PRINCIPAL_ID as its principal id.

=cut

sub limit_to_members_of_group {
    my $self  = shift;
    my $group = shift;

    return (
        $self->limit(
            value            => $group,
            column           => 'group_id',
            entry_aggregator => 'OR',
            quote_value      => 0
        )
    );

}

# }}}

1;

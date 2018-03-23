# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2018 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
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
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
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

=head1 NAME

  RT::CachedGroupMembers - a collection of RT::GroupMember objects

=head1 SYNOPSIS

  use RT::CachedGroupMembers;

=head1 DESCRIPTION


=head1 METHODS



=cut


package RT::CachedGroupMembers;

use strict;
use warnings;

use base 'RT::SearchBuilder';

use RT::CachedGroupMember;

sub Table { 'CachedGroupMembers'}

# {{{ LimitToUsers

=head2 LimitToUsers

Limits this search object to users who are members of this group
This is really useful when you want to have your UI separate out
groups from users for display purposes

=cut

sub LimitToUsers {
    my $self = shift;

    my $principals = $self->Join(
        ALIAS1 => 'main', FIELD1 => 'MemberId',
        TABLE2 => 'Principals', FIELD2 =>'id'
    );

    $self->Limit(       ALIAS => $principals,
                         FIELD => 'PrincipalType',
                         VALUE => 'User',
                         ENTRYAGGREGATOR => 'OR',
                         );
}




=head2 LimitToGroups

Limits this search object to Groups who are members of this group
This is really useful when you want to have your UI separate out
groups from users for display purposes

=cut

sub LimitToGroups {
    my $self = shift;

    my $principals = $self->Join(
        ALIAS1 => 'main', FIELD1 => 'MemberId',
        TABLE2 => 'Principals', FIELD2 =>'id'
    );


    $self->Limit(       ALIAS => $principals,
                         FIELD => 'PrincipalType',
                         VALUE => 'Group',
                         ENTRYAGGREGATOR => 'OR',
                         );
}



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


=head2 LimitToGroupsWithMember PRINCIPAL_ID

Takes a Principal Id as its only argument. 
Limits the current search to groups which contain PRINCIPAL_ID as a member  or submember.
This function gets used by GroupMember->Create to populate subgroups

=cut

sub LimitToGroupsWithMember {
    my $self = shift;
    my $member = shift;

    

    return ($self->Limit( 
                         VALUE => $member || '0',
                         FIELD => 'MemberId',
                         ENTRYAGGREGATOR => 'OR',
                         QUOTEVALUE => 0
                         ));

}
# }}}


RT::Base->_ImportOverlays();

1;

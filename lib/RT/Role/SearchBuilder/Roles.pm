# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2012 Best Practical Solutions, LLC
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

use strict;
use warnings;

package RT::Role::SearchBuilder::Roles;
use Role::Basic;
use Scalar::Util qw(blessed);

=head1 NAME

RT::Role::Record::Roles - Common methods for records which "watchers" or "roles"

=head1 REQUIRES

=head2 L<RT::Role::SearchBuilder>

=cut

with 'RT::Role::SearchBuilder';

require RT::System;
require RT::Principal;
require RT::Group;
require RT::User;

require RT::EmailParser;

=head1 PROVIDES

=cut

sub _RoleGroupsJoin {
    my $self = shift;
    my %args = (New => 0, Class => 'Ticket', Type => '', @_);
    $args{Class} =~ s/^RT:://;
    return $self->{'_sql_role_group_aliases'}{ $args{'Class'} .'-'. $args{'Type'} }
        if $self->{'_sql_role_group_aliases'}{ $args{'Class'} .'-'. $args{'Type'} }
           && !$args{'New'};

    # we always have watcher groups for ticket, so we use INNER join
    my $groups = $self->Join(
        ALIAS1          => 'main',
        FIELD1          => $args{'Class'} eq 'Queue'? 'Queue': 'id',
        TABLE2          => 'Groups',
        FIELD2          => 'Instance',
        ENTRYAGGREGATOR => 'AND',
    );
    $self->Limit(
        LEFTJOIN        => $groups,
        ALIAS           => $groups,
        FIELD           => 'Domain',
        VALUE           => 'RT::'. $args{'Class'} .'-Role',
    );
    $self->Limit(
        LEFTJOIN        => $groups,
        ALIAS           => $groups,
        FIELD           => 'Type',
        VALUE           => $args{'Type'},
    ) if $args{'Type'};

    $self->{'_sql_role_group_aliases'}{ $args{'Class'} .'-'. $args{'Type'} } = $groups
        unless $args{'New'};

    return $groups;
}

sub _GroupMembersJoin {
    my $self = shift;
    my %args = (New => 1, GroupsAlias => undef, Left => 1, @_);

    return $self->{'_sql_group_members_aliases'}{ $args{'GroupsAlias'} }
        if $self->{'_sql_group_members_aliases'}{ $args{'GroupsAlias'} }
            && !$args{'New'};

    my $alias = $self->Join(
        $args{'Left'} ? (TYPE            => 'LEFT') : (),
        ALIAS1          => $args{'GroupsAlias'},
        FIELD1          => 'id',
        TABLE2          => 'CachedGroupMembers',
        FIELD2          => 'GroupId',
        ENTRYAGGREGATOR => 'AND',
    );
    $self->Limit(
        $args{'Left'} ? (LEFTJOIN => $alias) : (),
        ALIAS => $alias,
        FIELD => 'Disabled',
        VALUE => 0,
    );

    $self->{'_sql_group_members_aliases'}{ $args{'GroupsAlias'} } = $alias
        unless $args{'New'};

    return $alias;
}

=head2 _WatcherJoin

Helper function which provides joins to a watchers table both for limits
and for ordering.

=cut

sub _WatcherJoin {
    my $self = shift;
    my $type = shift || '';


    my $groups = $self->_RoleGroupsJoin( Type => $type );
    my $group_members = $self->_GroupMembersJoin( GroupsAlias => $groups );
    # XXX: work around, we must hide groups that
    # are members of the role group we search in,
    # otherwise them result in wrong NULLs in Users
    # table and break ordering. Now, we know that
    # RT doesn't allow to add groups as members of the
    # ticket roles, so we just hide entries in CGM table
    # with MemberId == GroupId from results
    $self->Limit(
        LEFTJOIN   => $group_members,
        FIELD      => 'GroupId',
        OPERATOR   => '!=',
        VALUE      => "$group_members.MemberId",
        QUOTEVALUE => 0,
    );
    my $users = $self->Join(
        TYPE            => 'LEFT',
        ALIAS1          => $group_members,
        FIELD1          => 'MemberId',
        TABLE2          => 'Users',
        FIELD2          => 'id',
    );
    return ($groups, $group_members, $users);
}


sub RoleLimit {
    my $self = shift;
    my %args = (
        TYPE => '',
        FIELD => undef,
        OPERATOR => '=',
        VALUE => undef,
        @_
    );

    my $class = blessed($self->NewItem);

    $args{FIELD} ||= 'id' if $args{VALUE} =~ /^\d+$/;
    my $type = delete $args{TYPE};
    if ($type) {
        unless ($class->HasRole($type)) {
            RT->Logger->warn("RoleLimit called with invalid role $type for $class");
            return;
        }
        my $column = $class->Role($type)->{Column};
        if ( $column ) {
            if ( $args{OPERATOR} =~ /^!?=$/
                     && (!$args{FIELD} || $args{FIELD} eq 'Name' || $args{FIELD} eq 'EmailAddress') ) {
                my $o = RT::User->new( $self->CurrentUser );
                my $method = ($args{FIELD}||'') eq 'EmailAddress' ? 'LoadByEmail': 'Load';
                $o->$method( $args{VALUE} );
                $self->Limit(
                    %args,
                    FIELD => $column,
                    VALUE => $o->id,
                );
                return;
            }
            if ( $args{FIELD} and $args{FIELD} eq 'id' ) {
                $self->Limit(
                    %args,
                    FIELD => $column,
                );
                return;
            }
        }
    }

    $args{FIELD} ||= 'EmailAddress';

    my $groups = $self->_RoleGroupsJoin( Type => $type, Class => $class, New => !$type );

    $self->_OpenParen( $args{SUBCLAUSE} ) if $args{SUBCLAUSE};
    if ( $args{OPERATOR} =~ /^IS(?: NOT)?$/i ) {
        # is [not] empty case

        my $group_members = $self->_GroupMembersJoin( GroupsAlias => $groups );
        # to avoid joining the table Users into the query, we just join GM
        # and make sure we don't match records where group is member of itself
        $self->Limit(
            LEFTJOIN   => $group_members,
            FIELD      => 'GroupId',
            OPERATOR   => '!=',
            VALUE      => "$group_members.MemberId",
            QUOTEVALUE => 0,
        );
        $self->Limit(
            %args,
            ALIAS         => $group_members,
            FIELD         => 'GroupId',
            OPERATOR      => $args{OPERATOR},
            VALUE         => $args{VALUE},
        );
    }
    elsif ( $args{OPERATOR} =~ /^!=$|^NOT\s+/i ) {
        # negative condition case

        # reverse op
        $args{OPERATOR} =~ s/!|NOT\s+//i;

        # XXX: we have no way to build correct "Watcher.X != 'Y'" when condition
        # "X = 'Y'" matches more then one user so we try to fetch two records and
        # do the right thing when there is only one exist and semi-working solution
        # otherwise.
        my $users_obj = RT::Users->new( $self->CurrentUser );
        $users_obj->Limit(
            FIELD         => $args{FIELD},
            OPERATOR      => $args{OPERATOR},
            VALUE         => $args{VALUE},
        );
        $users_obj->OrderBy;
        $users_obj->RowsPerPage(2);
        my @users = @{ $users_obj->ItemsArrayRef };

        my $group_members = $self->_GroupMembersJoin( GroupsAlias => $groups );
        if ( @users <= 1 ) {
            my $uid = 0;
            $uid = $users[0]->id if @users;
            $self->Limit(
                LEFTJOIN      => $group_members,
                ALIAS         => $group_members,
                FIELD         => 'MemberId',
                VALUE         => $uid,
            );
            $self->Limit(
                %args,
                ALIAS           => $group_members,
                FIELD           => 'id',
                OPERATOR        => 'IS',
                VALUE           => 'NULL',
            );
        } else {
            $self->Limit(
                LEFTJOIN   => $group_members,
                FIELD      => 'GroupId',
                OPERATOR   => '!=',
                VALUE      => "$group_members.MemberId",
                QUOTEVALUE => 0,
            );
            my $users = $self->Join(
                TYPE            => 'LEFT',
                ALIAS1          => $group_members,
                FIELD1          => 'MemberId',
                TABLE2          => 'Users',
                FIELD2          => 'id',
            );
            $self->Limit(
                LEFTJOIN      => $users,
                ALIAS         => $users,
                FIELD         => $args{FIELD},
                OPERATOR      => $args{OPERATOR},
                VALUE         => $args{VALUE},
                CASESENSITIVE => 0,
            );
            $self->Limit(
                %args,
                ALIAS         => $users,
                FIELD         => 'id',
                OPERATOR      => 'IS',
                VALUE         => 'NULL',
            );
        }
    } else {
        # positive condition case

        my $group_members = $self->_GroupMembersJoin(
            GroupsAlias => $groups, New => 1, Left => 0
        );
        my $users = $self->Join(
            TYPE            => 'LEFT',
            ALIAS1          => $group_members,
            FIELD1          => 'MemberId',
            TABLE2          => 'Users',
            FIELD2          => 'id',
        );
        $self->Limit(
            %args,
            ALIAS           => $users,
            FIELD           => $args{FIELD},
            OPERATOR        => $args{OPERATOR},
            VALUE           => $args{VALUE},
            CASESENSITIVE   => 0,
        );
    }
    $self->_CloseParen( $args{SUBCLAUSE} ) if $args{SUBCLAUSE};
}

1;

# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2025 Best Practical Solutions, LLC
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

package RT::SearchBuilder::Role::Roles;
use Role::Basic;
use Scalar::Util qw(blessed);

=head1 NAME

RT::Record::Role::Roles - Common methods for records which "watchers" or "roles"

=head1 REQUIRES

=head2 L<RT::SearchBuilder::Role>

=cut

with 'RT::SearchBuilder::Role';

require RT::System;
require RT::Principal;
require RT::Group;
require RT::User;

require RT::EmailParser;

=head1 PROVIDES

=head2 _RoleGroupClass

Returns the class name on which role searches should be based.  This relates to
the internal L<RT::Group/Domain> and distinguishes between roles on the objects
being searched and their counterpart roles on containing classes.  For example,
limiting on L<RT::Queue> roles while searching for L<RT::Ticket>s.

The default implementation is:

    $self->RecordClass

which is the class that this collection object searches and instantiates objects
for.  If you're doing something hinky, you may need to override this method.

=cut

sub _RoleGroupClass {
    my $self = shift;
    return $self->RecordClass;
}

sub _RoleGroupsJoin {
    my $self = shift;
    my %args = (New => 0, Class => '', Name => '', Alias => 'main', @_);

    $args{'Class'} ||= $self->_RoleGroupClass;

    my $name = $args{'Name'};

    return $self->{'_sql_role_group_aliases'}{ $args{'Class'} .'-'. $name }
        if $self->{'_sql_role_group_aliases'}{ $args{'Class'} .'-'. $name }
           && !$args{'New'};

    # If we're looking at a role group on a class that "contains" this record
    # (i.e. roles on queues for tickets), then we assume that the current
    # record has a column named after the containing class (i.e.
    # Tickets.Queue).
    my $instance = $self->_RoleGroupClass eq $args{Class} ? "id" : $args{Class};
       $instance =~ s/^RT:://;

    # Watcher groups are no longer always created for each record, so we now use left join.
    # Previously (before 4.4) this used an inner join.
    my $groups = $self->Join(
        TYPE            => 'left',
        ALIAS1          => $args{Alias},
        FIELD1          => $instance,
        TABLE2          => 'Groups',
        FIELD2          => 'Instance',
        ENTRYAGGREGATOR => 'AND',
        DISTINCT        => !!$args{'Type'},
    );
    $self->Limit(
        LEFTJOIN        => $groups,
        ALIAS           => $groups,
        FIELD           => 'Domain',
        VALUE           => $args{'Class'} .'-Role',
        CASESENSITIVE   => 0,
    );
    $self->Limit(
        LEFTJOIN        => $groups,
        ALIAS           => $groups,
        FIELD           => 'Name',
        VALUE           => $name,
        CASESENSITIVE   => 0,
    ) if $name;

    $self->{'_sql_role_group_aliases'}{ $args{'Class'} .'-'. $name } = $groups
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
        LEFTJOIN => $alias,
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

    my $groups = $self->_RoleGroupsJoin(@_);
    my $group_members = $self->_GroupMembersJoin( GroupsAlias => $groups );
    # XXX: work around, we must hide groups that
    # are members of the role group we search in,
    # otherwise they result in wrong NULLs in Users
    # table and break ordering.

    # Exclude role groups themselves
    $self->Limit(
        LEFTJOIN   => $group_members,
        FIELD      => 'GroupId',
        OPERATOR   => '!=',
        VALUE      => "$group_members.MemberId",
        QUOTEVALUE => 0,
    );

    # Exclude groups added in role groups.  It technially also covers
    # the above limit, but with that limit, SQL could be faster as it
    # reduces rows to process before the following join.

    my $groups_2 = $self->Join(
        TYPE   => 'LEFT',
        ALIAS1 => $group_members,
        FIELD1 => 'MemberId',
        TABLE2 => 'Groups',
        FIELD2 => 'id',
    );
    $self->Limit(
        ALIAS           => $groups_2,
        FIELD           => 'id',
        OPERATOR        => 'IS',
        VALUE           => 'NULL',
        SUBCLAUSE       => "exclude_groups",
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
        CLASS => '',
        FIELD => undef,
        OPERATOR => '=',
        VALUE => undef,
        @_
    );
    my $is_shallow = ( $args{OPERATOR} =~ s/^shallow\s*//i );

    my $class = $args{CLASS} || $self->_RoleGroupClass;

    $args{FIELD} ||= 'id' if $args{VALUE} =~ /^\d+$/;

    my $type = delete $args{TYPE};
    if ($type and not $class->HasRole($type)) {
        RT->Logger->warn("RoleLimit called with invalid role $type for $class");
        return;
    }

    my $column = $type ? $class->Role($type)->{Column} : undef;

    # if it's equality op and search by Email or Name then we can preload user/group
    # we do it to help some DBs better estimate number of rows and get better plans
    if ( $args{QUOTEVALUE} && $args{OPERATOR} =~ /^!?=$/
             && (!$args{FIELD} || $args{FIELD} eq 'Name' || $args{FIELD} eq 'EmailAddress') ) {
        my $o = RT::User->new( $self->CurrentUser );
        my $method =
            !$args{FIELD}
            ? ($column ? 'Load' : 'LoadByEmail')
            : $args{FIELD} eq 'EmailAddress' ? 'LoadByEmail': 'Load';
        $o->$method( $args{VALUE} );
        my @values;
        @values = $o->Id if $o->Id;

        if ( !$args{FIELD} || $args{FIELD} eq 'Name' ) {
            my $group = RT::Group->new( $self->CurrentUser );
            $group->LoadUserDefinedGroup( $args{VALUE} );
            push @values, $group->Id if $group->Id;
        }

        $args{FIELD} = 'id';
        if ( @values == 1 ) {
            $args{VALUE} = $values[0];
        }
        elsif ( @values > 1 ) {
            RT->Logger->debug("Name $args{VALUE} is used in both user and group");
            $args{VALUE} = \@values;
            $args{OPERATOR} = $args{OPERATOR} =~ /!/ ? 'NOT IN' : 'IN';
        }
        else {
            $args{VALUE} = 0;
        }
    }

    if ( $column and $args{FIELD} and $args{FIELD} eq 'id' ) {
        $self->Limit(
            %args,
            FIELD => $column,
        );
        return;
    }

    $args{FIELD} ||= $args{QUOTEVALUE} ? 'EmailAddress' : 'id';

    my ($groups, $group_members, $cgm_2, $group_members_2, $users);
    if ( $args{'BUNDLE'} and @{$args{'BUNDLE'}}) {
        ($groups, $group_members, $cgm_2, $group_members_2, $users) = @{ $args{'BUNDLE'} };
    } else {
        $groups = $self->_RoleGroupsJoin( Name => $type, Class => $class, New => !$type );
    }

    $self->_OpenParen( $args{SUBCLAUSE} ) if $args{SUBCLAUSE};
    if ( $args{OPERATOR} =~ /^IS(?: NOT)?$/i ) {
        # is [not] empty case

        $group_members ||= $self->_GroupMembersJoin( GroupsAlias => $groups );
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

        $group_members ||= $self->_GroupMembersJoin( GroupsAlias => $groups );
        if ( @users <= 1 ) {
            my $uid = 0;
            $uid = $users[0]->id if @users;

            my @ids;
            if ( $is_shallow ) {
                @ids = $uid;
            }
            else {
                my $groups = RT::Groups->new( RT->SystemUser );
                $groups->LimitToUserDefinedGroups;
                $groups->WithMember( PrincipalId => $uid, Recursively => 1 );
                @ids = ( $uid, map { $_->id } @{ $groups->ItemsArrayRef } );
            }

            $self->Limit(
                LEFTJOIN      => $group_members,
                ALIAS         => $group_members,
                FIELD         => 'MemberId',
                VALUE         => \@ids,
                OPERATOR      => 'IN',
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
            $users ||= $self->Join(
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

        $group_members ||= $self->_GroupMembersJoin(
            GroupsAlias => $groups, New => 1,
        );
        if ($args{FIELD} eq "id") {
            my @ids = ref $args{VALUE} eq 'ARRAY' ? @{ $args{VALUE} } : $args{VALUE};
            if ( !$is_shallow ) {
                my @group_ids;
                for my $id (@ids) {
                    my $groups = RT::Groups->new( RT->SystemUser );
                    $groups->LimitToUserDefinedGroups;
                    $groups->WithMember( PrincipalId => $id, Recursively => 1 );
                    push @group_ids, map { $_->id } @{ $groups->ItemsArrayRef };
                }
                push @ids, @group_ids;
            }

            # Save a left join to Users, if possible
            $self->Limit(
                %args,
                ALIAS           => $group_members,
                FIELD           => "MemberId",
                OPERATOR        => 'IN',
                VALUE           => \@ids,
                CASESENSITIVE   => 0,
            );
        } else {

            if ( $is_shallow ) {
                $users ||= $self->Join(
                    TYPE            => 'LEFT',
                    ALIAS1          => $group_members,
                    FIELD1          => 'MemberId',
                    TABLE2          => 'Users',
                    FIELD2          => 'id',
                );
            }
            elsif ( !$users ) {
                $cgm_2           ||= $self->NewAlias('CachedGroupMembers');
                $group_members_2 ||= $self->Join(
                    TYPE   => 'LEFT',
                    ALIAS1 => $group_members,
                    FIELD1 => 'MemberId',
                    ALIAS2 => $cgm_2,
                    FIELD2 => 'GroupId',
                );
                $self->Limit(
                    LEFTJOIN => $group_members_2,
                    ALIAS => $cgm_2,
                    FIELD => 'Disabled',
                    VALUE => 0,
                    ENTRYAGGREGATOR => 'AND',
                );

                $users = $self->Join(
                    TYPE            => 'LEFT',
                    ALIAS1          => $group_members_2,
                    FIELD1          => 'MemberId',
                    TABLE2          => 'Users',
                    FIELD2          => 'id',
                );
            }
            $self->Limit(
                %args,
                ALIAS           => $users,
                FIELD           => $args{FIELD},
                OPERATOR        => $args{OPERATOR},
                VALUE           => $args{VALUE},
                CASESENSITIVE   => 0,
            );
        }
    }
    $self->_CloseParen( $args{SUBCLAUSE} ) if $args{SUBCLAUSE};
    if ($args{BUNDLE} and not @{$args{BUNDLE}}) {
        @{$args{BUNDLE}} = ($groups, $group_members, $cgm_2, $group_members_2, $users);
    }
    return ($groups, $group_members, $cgm_2, $group_members_2, $users);
}

RT::Base->_ImportOverlays();

1;

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

  RT::Model::GroupCollection - a collection of RT::Model::Group objects

=head1 SYNOPSIS

  use RT::Model::GroupCollection;
  my $groups = RT::Model::GroupCollection->new($current_user );
  $groups->find_all_rows();
  while (my $group = $groups->next()) {
     print $group->id ." is a group id\n";
  }

=head1 description


=head1 METHODS



=cut

use warnings;
use strict;

package RT::Model::GroupCollection;

use base qw/RT::SearchBuilder/;

use RT::Model::UserCollection;

# XXX: below some code is marked as subject to generalize in Groups, Users classes.
# RUZ suggest name Principals::Generic or Principals::Base as abstract class, but
# Jesse wants something that doesn't imply it's a Principals.pm subclass.
# See comments below for candidats.

# {{{ sub _init

sub implicit_clauses {
    my $self = shift;
    $self->order_by(
        alias  => 'main',
        column => 'name',
        order  => 'ASC'
    );

    # XXX: this code should be generalized
    $self->{'princalias'} = $self->join(
        alias1  => 'main',
        column1 => 'id',
        table2  => 'Principals',
        column2 => 'id'
    );

    # even if this condition is useless and ids in the Groups table
    # only match principals with type 'Group' this could speed up
    # searches in some DBs.
    $self->limit(
        alias  => $self->{'princalias'},
        column => 'principal_type',
        value  => 'Group',
    );

}

# }}}

=head2 principals_alias

Returns the string that represents this Users object's primary "Principals" alias.

=cut

# XXX: should be generalized, code duplication
sub principals_alias {
    my $self = shift;
    return ( $self->{'princalias'} );

}

# {{{ LimiToSystemInternalGroups

=head2 limit_to_system_internal_groups

Return only SystemInternal Groups, such as "privileged" "unprivileged" and "everyone" 

=cut

sub limit_to_system_internal_groups {
    my $self = shift;
    $self->limit(
        column   => 'domain',
        operator => '=',
        value    => 'SystemInternal'
    );

    # All system internal groups have the same instance. No reason to limit down further
    #$self->limit(column => 'instance', operator => '=', value => '0');
}

# }}}

# {{{ LimiToUserDefinedGroups

=head2 limit_to_user_defined Groups

Return only UserDefined Groups

=cut

sub limit_to_user_defined_groups {
    my $self = shift;
    $self->limit(
        column   => 'domain',
        operator => '=',
        value    => 'UserDefined'
    );

    # All user-defined groups have the same instance. No reason to limit down further
    #$self->limit(column => 'instance', operator => '=', value => '');
}

# }}}

# {{{ LimiToPersonalGroups

=head2 limit_to_personal_groups_for PRINCIPAL_ID

Return only Personal Groups for the user whose principal id 
is PRINCIPAL_ID

=cut

sub limit_to_personal_groups_for {
    my $self  = shift;
    my $princ = shift;

    $self->limit( column => 'domain', operator => '=', value => 'Personal' );
    $self->limit(
        column   => 'instance',
        operator => '=',
        value    => $princ
    );
}

# }}}

# {{{ limit_ToRolesForQueue

=head2 limit_to_roles_for_queue QUEUE_ID

Limits the set of groups found to role groups for queue QUEUE_ID

=cut

sub limit_to_roles_for_queue {
    my $self  = shift;
    my $queue = shift;
    $self->limit(
        column   => 'domain',
        operator => '=',
        value    => 'RT::Model::Queue-Role'
    );
    $self->limit( column => 'instance', operator => '=', value => $queue );
}

# }}}

# {{{ limit_ToRolesForTicket

=head2 limit_to_roles_for_ticket Ticket_ID

Limits the set of groups found to role groups for Ticket Ticket_ID

=cut

sub limit_to_roles_for_ticket {
    my $self   = shift;
    my $Ticket = shift;
    $self->limit(
        column   => 'domain',
        operator => '=',
        value    => 'RT::Model::Ticket-Role'
    );
    $self->limit( column => 'instance', operator => '=', value => '$Ticket' );
}

# }}}

# {{{ limit_ToRolesForSystem

=head2 limit_to_roles_for_system System_ID

Limits the set of groups found to role groups for System System_ID

=cut

sub limit_to_roles_for_system {
    my $self = shift;
    $self->limit(
        column   => 'domain',
        operator => '=',
        value    => 'RT::System-Role'
    );
}

# }}}

=head2 with_member {principal_id => PRINCIPAL_ID, recursively => undef}

Limits the set of groups returned to groups which have
Principal PRINCIPAL_ID as a member

=cut

sub with_member {
    my $self = shift;
    my %args = (
        principal_id => undef,
        recursively  => undef,
        @_
    );
    my $members;

    if ( $args{'recursively'} ) {
        $members = $self->new_alias('CachedGroupMembers');
    } else {
        $members = $self->new_alias('GroupMembers');
    }
    $self->join(
        alias1  => 'main',
        column1 => 'id',
        alias2  => $members,
        column2 => 'group_id'
    );

    $self->limit(
        alias    => $members,
        column   => 'member_id',
        operator => '=',
        value    => $args{'principal_id'}
    );
}

sub without_member {
    my $self = shift;
    my %args = (
        principal_id => undef,
        recursively  => undef,
        @_
    );

    my $members = $args{'recursively'} ? 'CachedGroupMembers' : 'GroupMembers';
    my $members_alias = $self->join(
        type    => 'LEFT',
        column1 => 'id',
        table2  => $members,
        column2 => 'group_id',
    );
    $self->limit(
        left_join => $members_alias,
        alias     => $members_alias,
        column    => 'member_id',
        operator  => '=',
        value     => $args{'principal_id'},
    );
    $self->limit(
        alias       => $members_alias,
        column      => 'member_id',
        operator    => 'IS',
        value       => 'NULL',
        quote_value => 0,
    );
}

=head2 withright { right => RIGHTNAME, object => RT::Record, include_system_rights => 1, include_superusers => 0, equiv_objects => [ ] }


Find all groups which have RIGHTNAME for RT::Record. Optionally include global rights and superusers. By default, include the global rights, but not the superusers.



=cut

#XXX: should be generilized
sub with_right {
    my $self = shift;
    my %args = (
        right                    => undef,
        object                   => => undef,
        include_system_rights    => 1,
        include_superusers       => undef,
        include_subgroup_members => 0,
        equiv_objects            => [],
        @_
    );

    my $from_role = $self->clone;
    $from_role->with_role_right(%args);

    my $from_group = $self->clone;
    $from_group->with_group_right(%args);

    #XXX: DIRTY HACK
    use Jifty::DBI::Collection::Union;
    my $union = new Jifty::DBI::Collection::Union;
    $union->add($from_role);
    $union->add($from_group);
    %$self = %$union;
    bless $self, ref($union);

    return;
}

#XXX: methods are active aliases to Users class to prevent code duplication
# should be generalized
sub _join_groups {
    my $self = shift;
    my %args = (@_);
    return 'main' unless $args{'include_subgroup_members'};
    return $self->RT::Model::UserCollection::_join_groups(%args);
}

sub _join_group_members {
    my $self = shift;
    my %args = (@_);
    return 'main' unless $args{'include_subgroup_members'};
    return $self->RT::Model::UserCollection::_join_group_members(%args);
}

sub _join_group_members_for_group_rights {
    my $self          = shift;
    my %args          = (@_);
    my $group_members = $self->_join_group_members(%args);
    unless ( $group_members eq 'main' ) {
        return $self->RT::Model::UserCollection::_join_group_members_for_group_rights(%args);
    }
    $self->limit(
        alias       => $args{'aclalias'},
        column      => 'principal_id',
        value       => "main.id",
        quote_value => 0,
    );
}
sub _join_acl { return (shift)->RT::Model::UserCollection::_join_acl(@_) }

sub _role_clauses {
    return (shift)->RT::Model::UserCollection::_RoleClauses(@_);
}

sub who_have_role_right_splitted {
    return (shift)->RT::Model::UserCollection::_who_have_role_rightSplitted(@_);
}

sub _get_equiv_objects {
    return (shift)->RT::Model::UserCollection::_get_equiv_objects(@_);
}

sub with_group_right {
    return (shift)->RT::Model::UserCollection::who_have_group_right(@_);
}

sub with_role_right {
    return (shift)->RT::Model::UserCollection::who_have_role_right(@_);
}

# {{{ sub limit_to_enabled

=head2 limit_to_enabled

Only find items that haven\'t been disabled

=cut

sub limit_to_enabled {
    my $self = shift;

    $self->limit(
        alias    => $self->principals_alias,
        column   => 'disabled',
        value    => '0',
        operator => '=',
    );
}

# }}}

# {{{ sub next

sub next {
    my $self = shift;

    # Don't show groups which the user isn't allowed to see.

    my $Group = $self->SUPER::next();
    if ( ( defined($Group) ) and ( ref($Group) ) ) {
        unless ( $Group->current_user_has_right('SeeGroup') ) {
            return $self->next();
        }

        return $Group;
    } else {
        return undef;
    }
}

sub _do_search {
    my $self = shift;

    #unless we really want to find disabled rows, make sure we\'re only finding enabled ones.
    unless ( $self->{'find_disabled_rows'} ) {
        $self->limit_to_enabled();
    }

    return ( $self->SUPER::_do_search(@_) );

}

1;


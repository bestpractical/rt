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

use base qw/RT::IsPrincipalCollection RT::Collection/;

use RT::Model::UserCollection;

sub implicit_clauses {
    my $self = shift;
    $self->order_by(
        alias  => 'main',
        column => 'name',
        order  => 'ASC'
    );
}


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

=head2 limit_to_roles

Limits the set of groups found to role groups for an instance of a model. Takes:

=over 4

=item object - an object roles of which should be looked, replaces the following
two arguments;

=item model - mandatory name of a model, for example: 'RT::Model::Ticket';

=item instance - optional id of the model record;

=item type - optional type of the role groups, for example 'cc';

=item subclause and entry_aggregator - use to combine with different conditions;
by default aggregator is 'OR' and subclause matches name of the method, so you can
call this method multiple times and get role of groups of different models.

=cut

sub limit_to_roles {
    my $self  = shift;
    my %args = (
        model            => undef,
        type             => undef,
        instance         => undef,
        entry_aggregator => 'OR',
        subclause        => 'limit_to_roles',
        @_
    );
    @args{'model', 'instance'} = (ref $args{'object'}, $args{'object'}->id)
        if $args{'object'};

    $self->open_paren( $args{'subclause'} );
    $self->limit(
        subclause        => $args{'subclause'},
        entry_aggregator => $args{'entry_aggregator'},
        column           => 'domain',
        operator         => '=',
        value            => $args{'model'} .'-Role',
    );
    $self->limit(
        subclause        => $args{'subclause'},
        entry_aggregator => 'AND',
        column           => 'instance',
        operator         => '=',
        value            => $args{'instance'},
    ) if defined $args{'instance'};
    $self->limit(
        subclause        => $args{'subclause'},
        entry_aggregator => 'AND',
        column           => 'type',
        operator         => '=',
        value            => $args{'type'},
    ) if defined $args{'type'};
    $self->close_paren( $args{'subclause'} );
}

=head2 with_member {principal => PRINCIPAL_ID, recursively => undef}

Limits the set of groups returned to groups which have
Principal PRINCIPAL_ID as a member

=cut

sub with_member {
    my $self = shift;
    my %args = (
        principal => undef,
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
        value    => $args{'principal'}
    );
}

sub without_member {
    my $self = shift;
    my %args = (
        principal => undef,
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
        value     => $args{'principal'},
    );
    $self->limit(
        alias       => $members_alias,
        column      => 'member_id',
        operator    => 'IS',
        value       => 'NULL',
        quote_value => 0,
    );
}

sub _join_groups {
    my $self = shift;
    my %args = (@_);
    return 'main' unless $args{'recursive'};
    return $self->SUPER::_join_groups(%args);
}

sub _join_group_members {
    my $self = shift;
    my %args = (@_);
    return 'main' unless $args{'recursive'};
    return $self->SUPER::_join_group_members(%args);
}

sub _join_group_members_for_group_rights {
    my $self          = shift;
    my %args          = (@_);
    my $group_members = $self->_join_group_members(%args);
    unless ( $group_members eq 'main' ) {
        return $self->SUPER::_join_group_members_for_group_rights(%args);
    }
    $self->limit(
        alias       => $args{'aclalias'},
        column      => 'principal',
        value       => "main.id",
        quote_value => 0,
    );
}

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

    return $self->SUPER::_do_search(@_);
}

1;

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

  RT::Model::UserCollection - Collection of RT::Model::User objects

=head1 SYNOPSIS

  use RT::Model::UserCollection;


=head1 description


=head1 METHODS


=cut

use warnings;
use strict;

package RT::Model::UserCollection;
use base qw/RT::SearchBuilder/;

# {{{ sub _init
sub _init {
    my $self = shift;

    my @result = $self->SUPER::_init(@_);

    # By default, order by name
    $self->order_by(
        alias  => 'main',
        column => 'name',
        order  => 'ASC'
    );

    $self->{'princ_alias'} = $self->new_alias('Principals');

    # XXX: should be generalized
    $self->join(
        alias1  => 'main',
        column1 => 'id',
        alias2  => $self->principals_alias,
        column2 => 'id'
    );
    $self->limit(
        alias  => $self->principals_alias,
        column => 'principal_type',
        value  => 'User',
    );

    return (@result);
}

# }}}

=head2 principals_alias

Returns the string that represents this Users object's primary "Principals" alias.

=cut

# XXX: should be generalized
sub principals_alias {
    my $self = shift;
    return ( $self->{'princ_alias'} );

}

# {{{ sub _do_search

=head2 _do_search

  A subclass of Jifty::DBI::_do_search that makes sure that _disabled rows never get seen unless
we're explicitly trying to see them.

=cut

sub _do_search {
    my $self = shift;

#unless we really want to find disabled rows, make sure we\'re only finding enabled ones.
    unless ( $self->{'find_disabled_rows'} ) {
        $self->limit_to_enabled();
    }
    return ( $self->SUPER::_do_search(@_) );

}

# }}}
# {{{ sub limit_to_enabled

=head2 limit_to_enabled

Only find items that haven\'t been disabled

=cut

# XXX: should be generalized
sub limit_to_enabled {
    my $self = shift;

    $self->limit(
        alias    => $self->principals_alias,
        column   => 'disabled',
        value    => '0',
        operator => '='
    );
}

# }}}

# {{{ limit_to_email

=head2 limit_to_email

Takes one argument. an email address. limits the returned set to
that email address

=cut

sub limit_to_email {
    my $self = shift;
    my $addr = shift;
    $self->limit( column => 'email', value => "$addr" );
}

# }}}

# {{{ member_of_group

=head2 member_of_group PRINCIPAL_ID

takes one argument, a group's principal id. Limits the returned set
to members of a given group

=cut

sub member_of_group {
    my $self  = shift;
    my $group = shift;

    return _("No group specified") if ( !defined $group );

    my $groupalias = $self->new_alias('CachedGroupMembers');

    # join the principal to the groups table
    $self->join(
        alias1  => $self->principals_alias,
        column1 => 'id',
        alias2  => $groupalias,
        column2 => 'member_id'
    );

    $self->limit(
        alias    => "$groupalias",
        column   => 'group_id',
        value    => "$group",
        operator => "="
    );
}

# }}}

# {{{ limit_to_privileged

=head2 limit_to_privileged

Limits to users who can be made members of ACLs and groups

=cut

sub limit_to_privileged {
    my $self = shift;

    my $priv = RT::Model::Group->new;
    $priv->load_system_internal_group('privileged');
    unless ( $priv->id ) {
        Jifty->log->fatal("Couldn't find a privileged users group");
    }
    $self->member_of_group( $priv->principal_id );
}

# }}}

# {{{ who_have_right

=head2 who_have_right { right => 'name', object => $rt_object , include_superusers => undef, include_subgroup_members => undef, include_system_rights => undef, equiv_objects => [ ] }


find all users who the right right for this group, either individually
or as members of groups

If passed a queue object, with no id, it will find users who have that right for _any_ queue

=cut

# XXX: should be generalized
sub _join_group_members {
    my $self = shift;
    my %args = (
        include_subgroup_members => 1,
        @_
    );

    my $principals = $self->principals_alias;

    # The cachedgroupmembers table is used for unrolling group memberships
    # to allow fast lookups. if we bind to CachedGroupMembers, we'll find
    # all members of groups recursively. if we don't we'll find only 'direct'
    # members of the group in question
    my $group_members;
    if ( $args{'include_subgroup_members'} ) {
        $group_members = $self->new_alias('CachedGroupMembers');
    } else {
        $group_members = $self->new_alias('GroupMembers');
    }

    $self->join(
        alias1  => $group_members,
        column1 => 'member_id',
        alias2  => $principals,
        column2 => 'id'
    );

    return $group_members;
}

# XXX: should be generalized
sub _join_groups {
    my $self = shift;
    my %args = (@_);

    my $group_members = $self->_join_group_members(%args);
    my $groups        = $self->new_alias('Groups');
    $self->join(
        alias1  => $groups,
        column1 => 'id',
        alias2  => $group_members,
        column2 => 'group_id'
    );

    return $groups;
}

# XXX: should be generalized
sub _join_acl {
    my $self = shift;
    my %args = (
        right             => undef,
        include_superusers => undef,
        @_,
    );

    my $acl = $self->new_alias('ACL');
    $self->limit(
        alias    => $acl,
        column   => 'right_name',
        operator => ( $args{right} ? '=' : 'IS NOT' ),
        value => $args{right} || 'NULL',
        entry_aggregator => 'OR'
    );
    if ( $args{'include_superusers'} and $args{'right'} ) {
        $self->limit(
            alias            => $acl,
            column           => 'right_name',
            operator         => '=',
            value            => 'SuperUser',
            entry_aggregator => 'OR'
        );
    }
    return $acl;
}

# XXX: should be generalized
sub _get_equiv_objects {
    my $self = shift;
    my %args = (
        object              => undef,
        include_system_rights => undef,
        equiv_objects       => [],
        @_
    );
    return () unless $args{'object'};

    my @objects = ( $args{'object'} );
    if ( UNIVERSAL::isa( $args{'object'}, 'RT::Model::Ticket' ) ) {

# If we're looking at ticket rights, we also want to look at the associated queue rights.
# this is a little bit hacky, but basically, now that we've done the ticket roles magic,
# we load the queue object and ask all the rest of our questions about the queue.

        # XXX: This should be abstracted into object itself
        if ( $args{'object'}->id ) {
            push @objects, $args{'object'}->acl_equivalence_objects;
        } else {
            push @objects, 'RT::Model::Queue';
        }
    }

    if ( $args{'include_system_rights'} ) {
        push @objects, 'RT::System';
    }
    push @objects, @{ $args{'equiv_objects'} };
    return grep $_, @objects;
}

# XXX: should be generalized
sub who_have_right {
    my $self = shift;
    my %args = (
        right                  => undef,
        object                 => undef,
        include_system_rights    => undef,
        include_superusers      => undef,
        include_subgroup_members => 1,
        equiv_objects          => [],
        @_
    );

    if ( defined $args{'object_type'} || defined $args{'object_id'} ) {
        Jifty->log->fatal(
            "who_have_right called with the Obsolete object_id/Object_type API"
        );
        return (undef);
    }

    my $from_role = $self->clone;
    $from_role->who_have_role_right(%args);

    my $from_group = $self->clone;
    $from_group->who_have_group_right(%args);

    #XXX: DIRTY HACK
    use Jifty::DBI::Collection::Union;
    my $union = new Jifty::DBI::Collection::Union;
    $union->add($from_role);
    $union->add($from_group);
    %$self = %$union;
    bless $self, ref($union);

    return;
}

# }}}

# XXX: should be generalized
sub who_have_role_right {
    my $self = shift;
    my %args = (
        right                  => undef,
        object                 => undef,
        include_system_rights    => undef,
        include_superusers      => undef,
        include_subgroup_members => 1,
        equiv_objects          => [],
        @_
    );

    my $groups = $self->_join_groups(%args);
    my $acl    = $self->_join_acl(%args);

    my ( $check_roles, $check_objects ) = ( '', '' );

    my @objects = $self->_get_equiv_objects(%args);

    if (@objects) {
        my @role_clauses;
        my @object_clauses;
        foreach my $obj (@objects) {
            my $type = ref($obj) ? ref($obj) : $obj;
            my $id;
            $id = $obj->id
                if ref($obj) && UNIVERSAL::can( $obj, 'id' ) && $obj->id;

            my $role_clause = "$groups.domain = '$type-Role'";

            # if we want mysql 4.0 use indexes here. we MUST convert that
            # field to integer and drop this quotes.
            $role_clause .= " AND $groups.instance = '$id'" if $id;
            push @role_clauses, "($role_clause)";
            my $object_clause = "$acl.object_type = '$type'";
            $object_clause .= " AND $acl.object_id = $id" if $id;
            push @object_clauses, "($object_clause)";

        }

        $check_roles .= join ' OR ', @role_clauses;
        $check_objects = join ' OR ', @object_clauses;
    } else {
        if ( !$args{'include_system_rights'} ) {
            $check_objects = "($acl.object_type != 'RT::System')";
        }
    }

    $self->_add_subclause( "Whichobject", "($check_objects)" );
    $self->_add_subclause( "WhichRole",   "($check_roles)" );

    $self->limit(
        alias       => $acl,
        column      => 'principal_type',
        value       => "$groups.Type",
        quote_value => 0,
    );

    # no system user
    $self->limit(
        alias    => $self->principals_alias,
        column   => 'id',
        operator => '!=',
        value    => RT->system_user->id
    );
    return;
}

# XXX: should be generalized
sub _join_group_members_for_group_rights {
    my $self          = shift;
    my %args          = (@_);
    my $group_members = $self->_join_group_members(%args);
    $self->limit(
        alias       => $args{'aclalias'},
        column      => 'principal_id',
        value       => "$group_members.group_id",
        quote_value => 0,
    );
}

# XXX: should be generalized
sub who_have_group_right {
    my $self = shift;
    my %args = (
        right                  => undef,
        object                 => undef,
        include_system_rights    => undef,
        include_superusers      => undef,
        include_subgroup_members => 1,
        equiv_objects          => [],
        @_
    );

    # Find only rows where the Right granted is
    # the one we're looking up or _possibly_ superuser
    my $acl = $self->_join_acl(%args);

    my ($check_objects) = ('');
    my @objects = $self->_get_equiv_objects(%args);

    if (@objects) {
        my @object_clauses;
        foreach my $obj (@objects) {
            my $type = ref($obj) ? ref($obj) : $obj;
            my $id;
            $id = $obj->id
                if ref($obj) && UNIVERSAL::can( $obj, 'id' ) && $obj->id;

            my $object_clause = "$acl.object_type = '$type'";
            $object_clause .= " AND $acl.object_id   = $id" if $id;
            push @object_clauses, "($object_clause)";
        }

        $check_objects = join ' OR ', @object_clauses;
    } else {
        if ( !$args{'include_system_rights'} ) {
            $check_objects = "($acl.object_type != 'RT::System')";
        }
    }
    $self->_add_subclause( "Whichobject", "($check_objects)" );

    $self->_join_group_members_for_group_rights( %args, aclalias => $acl );

    # Find only members of groups that have the right.
    $self->limit(
        alias  => $acl,
        column => 'principal_type',
        value  => 'Group',
    );

    # no system user
    $self->limit(
        alias    => $self->principals_alias,
        column   => 'id',
        operator => '!=',
        value    => RT->system_user->id
    );
    return;
}

# {{{ who_belong_to_groups

=head2 who_belong_to_groups { Groups => ARRAYREF, include_subgroup_members => 1 }

=cut

# XXX: should be generalized
sub who_belong_to_groups {
    my $self = shift;
    my %args = (
        groups                 => undef,
        include_subgroup_members => 1,
        @_
    );

    # Unprivileged users can't be granted real system rights.
    # is this really the right thing to be saying?
    $self->limit_to_privileged();

    my $group_members = $self->_join_group_members(%args);

    foreach my $groupid ( @{ $args{'groups'} } ) {
        $self->limit(
            alias            => $group_members,
            column           => 'group_id',
            value            => $groupid,
            quote_value      => 0,
            entry_aggregator => 'OR',
        );
    }
}

# }}}

1;

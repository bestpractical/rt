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
=head1 NAME

  RT::Model::UserCollection - Collection of RT::Model::User objects

=head1 SYNOPSIS

  use RT::Model::UserCollection;


=head1 DESCRIPTION


=head1 METHODS


=cut


package RT::Model::UserCollection;

use strict;
no warnings qw(redefine);

# {{{ sub _init 
sub _init {
    my $self = shift;
    $self->{'table'} = 'Users';
        $self->{'primary_key'} = 'id';



    my @result =          $self->SUPER::_init(@_);
    # By default, order by name
    $self->order_by( alias => 'main',
                    column => 'Name',
                        order => 'ASC' );

    $self->{'princalias'} = $self->new_alias('Principals');

    # XXX: should be generalized
    $self->join( alias1 => 'main',
                 column1 => 'id',
                 alias2 => $self->{'princalias'},
                 column2 => 'id' );
    $self->limit( alias => $self->{'princalias'},
                  column => 'PrincipalType',
                  value => 'User',
                );

    return (@result);
}

# }}}

=head2 PrincipalsAlias

Returns the string that represents this Users object's primary "Principals" alias.

=cut

# XXX: should be generalized
sub PrincipalsAlias {
    my $self = shift;
    return($self->{'princalias'});

}


# {{{ sub _do_search 

=head2 _do_search

  A subclass of Jifty::DBI::_do_search that makes sure that _Disabled rows never get seen unless
we're explicitly trying to see them.

=cut

sub _do_search {
    my $self = shift;

    #unless we really want to find disabled rows, make sure we\'re only finding enabled ones.
    unless ( $self->{'find_disabled_rows'} ) {
        $self->LimitToEnabled();
    }
    return ( $self->SUPER::_do_search(@_) );

}

# }}}
# {{{ sub LimitToEnabled

=head2 LimitToEnabled

Only find items that haven\'t been disabled

=cut

# XXX: should be generalized
sub LimitToEnabled {
    my $self = shift;

    $self->limit( alias    => $self->PrincipalsAlias,
                  column    => 'Disabled',
                  value    => '0',
                  operator => '=' );
}

# }}}

# {{{ LimitToEmail

=head2 LimitToEmail

Takes one argument. an email address. limits the returned set to
that email address

=cut

sub LimitToEmail {
    my $self = shift;
    my $addr = shift;
    $self->limit( column => 'EmailAddress', value => "$addr" );
}

# }}}

# {{{ MemberOfGroup

=head2 MemberOfGroup PRINCIPAL_ID

takes one argument, a group's principal id. Limits the returned set
to members of a given group

=cut

sub MemberOfGroup {
    my $self  = shift;
    my $group = shift;

    return $self->loc("No group specified") if ( !defined $group );

    my $groupalias = $self->new_alias('CachedGroupMembers');

    # join the principal to the groups table
    $self->join( alias1 => $self->PrincipalsAlias,
                 column1 => 'id',
                 alias2 => $groupalias,
                 column2 => 'MemberId' );

    $self->limit( alias    => "$groupalias",
                  column    => 'GroupId',
                  value    => "$group",
                  operator => "=" );
}

# }}}

# {{{ LimitToPrivileged

=head2 LimitToPrivileged

Limits to users who can be made members of ACLs and groups

=cut

sub LimitToPrivileged {
    my $self = shift;

    my $priv = RT::Model::Group->new( $self->current_user );
    $priv->load_system_internal_group('Privileged');
    unless ( $priv->id ) {
        $RT::Logger->crit("Couldn't find a privileged users group");
    }
    $self->MemberOfGroup( $priv->PrincipalId );
}

# }}}

# {{{ WhoHaveRight

=head2 WhoHaveRight { Right => 'name', Object => $rt_object , IncludeSuperusers => undef, IncludeSubgroupMembers => undef, IncludeSystemRights => undef, EquivObjects => [ ] }


find all users who the right Right for this group, either individually
or as members of groups

If passed a queue object, with no id, it will find users who have that right for _any_ queue

=cut

# XXX: should be generalized
sub _joinGroupMembers
{
    my $self = shift;
    my %args = (
        IncludeSubgroupMembers => 1,
        @_
    );

    my $principals = $self->PrincipalsAlias;

    # The cachedgroupmembers table is used for unrolling group memberships
    # to allow fast lookups. if we bind to CachedGroupMembers, we'll find
    # all members of groups recursively. if we don't we'll find only 'direct'
    # members of the group in question
    my $group_members;
    if ( $args{'IncludeSubgroupMembers'} ) {
        $group_members = $self->new_alias('CachedGroupMembers');
    }
    else {
        $group_members = $self->new_alias('GroupMembers');
    }

    $self->join(
        alias1 => $group_members,
        column1 => 'MemberId',
        alias2 => $principals,
        column2 => 'id'
    );

    return $group_members;
}

# XXX: should be generalized
sub _joinGroups
{
    my $self = shift;
    my %args = (@_);

    my $group_members = $self->_joinGroupMembers( %args );
    my $groups = $self->new_alias('Groups');
    $self->join(
        alias1 => $groups,
        column1 => 'id',
        alias2 => $group_members,
        column2 => 'GroupId'
    );

    return $groups;
}

# XXX: should be generalized
sub _joinACL
{
    my $self = shift;
    my %args = (
        Right                  => undef,
        IncludeSuperusers      => undef,
        @_,
    );

    my $acl = $self->new_alias('ACL');
    $self->limit(
        alias    => $acl,
        column    => 'RightName',
        operator => ( $args{Right} ? '=' : 'IS NOT' ),
        value => $args{Right} || 'NULL',
        entry_aggregator => 'OR'
    );
    if ( $args{'IncludeSuperusers'} and $args{'Right'} ) {
        $self->limit(
            alias           => $acl,
            column           => 'RightName',
            operator        => '=',
            value           => 'SuperUser',
            entry_aggregator => 'OR'
        );
    }
    return $acl;
}

# XXX: should be generalized
sub _GetEquivObjects
{
    my $self = shift;
    my %args = (
        Object                 => undef,
        IncludeSystemRights    => undef,
        EquivObjects           => [ ],
        @_
    );
    return () unless $args{'Object'};

    my @objects = ($args{'Object'});
    if ( UNIVERSAL::isa( $args{'Object'}, 'RT::Model::Ticket' ) ) {
        # If we're looking at ticket rights, we also want to look at the associated queue rights.
        # this is a little bit hacky, but basically, now that we've done the ticket roles magic,
        # we load the queue object and ask all the rest of our questions about the queue.

        # XXX: This should be abstracted into object itself
        if( $args{'Object'}->id ) {
            push @objects, $args{'Object'}->ACLEquivalenceObjects;
        } else {
            push @objects, 'RT::Model::Queue';
        }
    }

    if( $args{'IncludeSystemRights'} ) {
        push @objects, 'RT::System';
    }
    push @objects, @{ $args{'EquivObjects'} };
    return grep $_, @objects;
}

# XXX: should be generalized
sub WhoHaveRight {
    my $self = shift;
    my %args = (
        Right                  => undef,
        Object                 => undef,
        IncludeSystemRights    => undef,
        IncludeSuperusers      => undef,
        IncludeSubgroupMembers => 1,
        EquivObjects           => [ ],
        @_
    );

    if ( defined $args{'ObjectType'} || defined $args{'ObjectId'} ) {
        $RT::Logger->crit( "WhoHaveRight called with the Obsolete ObjectId/ObjectType API");
        return (undef);
    }

    my $from_role = $self->clone;
    $from_role->WhoHaveRoleRight( %args );

    my $from_group = $self->clone;
    $from_group->WhoHaveGroupRight( %args );

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
sub WhoHaveRoleRight
{
    my $self = shift;
    my %args = (
        Right                  => undef,
        Object                 => undef,
        IncludeSystemRights    => undef,
        IncludeSuperusers      => undef,
        IncludeSubgroupMembers => 1,
        EquivObjects           => [ ],
        @_
    );

    my $groups = $self->_joinGroups( %args );
    my $acl = $self->_joinACL( %args );

    my ($check_roles, $check_objects) = ('','');
    
    my @objects = $self->_GetEquivObjects( %args );
    if ( @objects ) {
        my @role_clauses;
        my @object_clauses;
        foreach my $obj ( @objects ) {
            my $type = ref($obj)? ref($obj): $obj;
            my $id;
            $id = $obj->id if ref($obj) && UNIVERSAL::can($obj, 'id') && $obj->id;

            my $role_clause = "$groups.Domain = '$type-Role'";
            # XXX: Groups.Instance is VARCHAR in DB, we should quote value
            # if we want mysql 4.0 use indexes here. we MUST convert that
            # field to integer and drop this quotes.
            $role_clause   .= " AND $groups.Instance = '$id'" if $id;
            push @role_clauses, "($role_clause)";

            my $object_clause = "$acl.ObjectType = '$type'";
            $object_clause   .= " AND $acl.ObjectId = $id" if $id;
            push @object_clauses, "($object_clause)";
        }

        $check_roles .= join ' OR ', @role_clauses;
        $check_objects = join ' OR ', @object_clauses;
    } else {
        if( !$args{'IncludeSystemRights'} ) {
            $check_objects = "($acl.ObjectType != 'RT::System')";
        }
    }

    $self->_add_subclause( "WhichObject", "($check_objects)" );
    $self->_add_subclause( "WhichRole", "($check_roles)" );

    $self->limit( alias => $acl,
                  column => 'PrincipalType',
                  value => "$groups.Type",
                  quote_value => 0,
                );

    # no system user
    $self->limit( alias => $self->PrincipalsAlias,
                  column => 'id',
                  operator => '!=',
                  value => $RT::SystemUser->id
                );
    return;
}

# XXX: should be generalized
sub _joinGroupMembersForGroupRights
{
    my $self = shift;
    my %args = (@_);
    my $group_members = $self->_joinGroupMembers( %args );
    $self->limit( alias => $args{'ACLAlias'},
                  column => 'PrincipalId',
                  value => "$group_members.GroupId",
                  quote_value => 0,
                );
}

# XXX: should be generalized
sub WhoHaveGroupRight
{
    my $self = shift;
    my %args = (
        Right                  => undef,
        Object                 => undef,
        IncludeSystemRights    => undef,
        IncludeSuperusers      => undef,
        IncludeSubgroupMembers => 1,
        EquivObjects           => [ ],
        @_
    );

    # Find only rows where the right granted is
    # the one we're looking up or _possibly_ superuser
    my $acl = $self->_joinACL( %args );

    my ($check_objects) = ('');
    my @objects = $self->_GetEquivObjects( %args );

    if ( @objects ) {
        my @object_clauses;
        foreach my $obj ( @objects ) {
            my $type = ref($obj)? ref($obj): $obj;
            my $id;
            $id = $obj->id if ref($obj) && UNIVERSAL::can($obj, 'id') && $obj->id;

            my $object_clause = "$acl.ObjectType = '$type'";
            $object_clause   .= " AND $acl.ObjectId   = $id" if $id;
            push @object_clauses, "($object_clause)";
        }

        $check_objects = join ' OR ', @object_clauses;
    } else {
        if( !$args{'IncludeSystemRights'} ) {
            $check_objects = "($acl.ObjectType != 'RT::System')";
        }
    }
    $self->_add_subclause( "WhichObject", "($check_objects)" );
    
    $self->_joinGroupMembersForGroupRights( %args, ACLAlias => $acl );
    # Find only members of groups that have the right.
    $self->limit( alias => $acl,
                  column => 'PrincipalType',
                  value => 'Group',
                );
    
    # no system user
    $self->limit( alias => $self->PrincipalsAlias,
                  column => 'id',
                  operator => '!=',
                  value => $RT::SystemUser->id
                );
    return;
}

# {{{ WhoBelongToGroups

=head2 WhoBelongToGroups { Groups => ARRAYREF, IncludeSubgroupMembers => 1 }

=cut

# XXX: should be generalized
sub WhoBelongToGroups {
    my $self = shift;
    my %args = ( Groups                 => undef,
                 IncludeSubgroupMembers => 1,
                 @_ );

    # Unprivileged users can't be granted real system rights.
    # is this really the right thing to be saying?
    $self->LimitToPrivileged();

    my $group_members = $self->_joinGroupMembers( %args );

    foreach my $groupid (@{$args{'Groups'}}) {
        $self->limit( alias           => $group_members,
                      column           => 'GroupId',
                      value           => $groupid,
                      quote_value      => 0,
                      entry_aggregator => 'OR',
                    );
    }
}
# }}}


1;

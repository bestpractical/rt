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

  RT::Users - Collection of RT::User objects

=head1 SYNOPSIS

  use RT::Users;


=head1 DESCRIPTION


=head1 METHODS


=cut


package RT::Users;

use strict;
use warnings;

use base 'RT::SearchBuilder';

use RT::User;

sub Table { 'Users'}


sub _Init {
    my $self = shift;
    $self->{'with_disabled_column'} = 1;

    my @result = $self->SUPER::_Init(@_);
    # By default, order by name
    $self->OrderBy( ALIAS => 'main',
                    FIELD => 'Name',
                    ORDER => 'ASC' );

    # XXX: should be generalized
    $self->{'princalias'} = $self->Join(
                 ALIAS1 => 'main',
                 FIELD1 => 'id',
                 TABLE2 => 'Principals',
                 FIELD2 => 'id' );
    $self->Limit( ALIAS => $self->{'princalias'},
                  FIELD => 'PrincipalType',
                  VALUE => 'User',
                );

    return (@result);
}

sub OrderByCols {
    my $self = shift;
    my @res  = ();

    for my $row (@_) {
        if (($row->{FIELD}||'') =~ /^CustomField\.\{(.*)\}$/) {
            my $name = $1 || $2;
            my $cf = RT::CustomField->new( $self->CurrentUser );
            $cf->LoadByName(
                Name => $name,
                ObjectType => 'RT::User',
            );
            if ( $cf->id ) {
                push @res, $self->_OrderByCF( $row, $cf->id, $cf );
            }
        } else {
            push @res, $row;
        }
    }
    return $self->SUPER::OrderByCols( @res );
}

=head2 PrincipalsAlias

Returns the string that represents this Users object's primary "Principals" alias.

=cut

# XXX: should be generalized
sub PrincipalsAlias {
    my $self = shift;
    return($self->{'princalias'});

}


=head2 LimitToEnabled

Only find items that haven't been disabled

=cut

# XXX: should be generalized
sub LimitToEnabled {
    my $self = shift;

    $self->{'handled_disabled_column'} = 1;
    $self->Limit(
        ALIAS    => $self->PrincipalsAlias,
        FIELD    => 'Disabled',
        VALUE    => '0',
    );
}

=head2 LimitToDeleted

Only find items that have been deleted.

=cut

sub LimitToDeleted {
    my $self = shift;
    
    $self->{'handled_disabled_column'} = $self->{'find_disabled_rows'} = 1;
    $self->Limit(
        ALIAS => $self->PrincipalsAlias,
        FIELD => 'Disabled',
        VALUE => 1,
    );
}



=head2 LimitToEmail

Takes one argument. an email address. limits the returned set to
that email address

=cut

sub LimitToEmail {
    my $self = shift;
    my $addr = shift;
    $self->Limit( FIELD => 'EmailAddress', VALUE => $addr, CASESENSITIVE => 0 );
}



=head2 MemberOfGroup PRINCIPAL_ID

takes one argument, a group's principal id. Limits the returned set
to members of a given group

=cut

sub MemberOfGroup {
    my $self  = shift;
    my $group = shift;

    return $self->loc("No group specified") if ( !defined $group );

    my $groupalias = $self->NewAlias('CachedGroupMembers');

    # Join the principal to the groups table
    $self->Join( ALIAS1 => $self->PrincipalsAlias,
                 FIELD1 => 'id',
                 ALIAS2 => $groupalias,
                 FIELD2 => 'MemberId' );
    $self->Limit( ALIAS => $groupalias,
                  FIELD => 'Disabled',
                  VALUE => 0 );

    $self->Limit( ALIAS    => "$groupalias",
                  FIELD    => 'GroupId',
                  VALUE    => "$group",
                  OPERATOR => "=" );
}



=head2 LimitToPrivileged

Limits to users who can be made members of ACLs and groups

=cut

sub LimitToPrivileged {
    my $self = shift;
    $self->MemberOfGroup( RT->PrivilegedUsers->id );
}

=head2 LimitToUnprivileged

Limits to unprivileged users only

=cut

sub LimitToUnprivileged {
    my $self = shift;
    $self->MemberOfGroup( RT->UnprivilegedUsers->id);
}


sub Limit {
    my $self = shift;
    my %args = @_;
    $args{'CASESENSITIVE'} = 0 unless exists $args{'CASESENSITIVE'} or $args{'ALIAS'};
    return $self->SUPER::Limit( %args );
}

=head2 WhoHaveRight { Right => 'name', Object => $rt_object , IncludeSuperusers => undef, IncludeSubgroupMembers => undef, IncludeSystemRights => undef, EquivObjects => [ ] }


find all users who the right Right for this group, either individually
or as members of groups

If passed a queue object, with no id, it will find users who have that right for _any_ queue

=cut

# XXX: should be generalized
sub _JoinGroupMembers
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
        $group_members = $self->NewAlias('CachedGroupMembers');
    }
    else {
        $group_members = $self->NewAlias('GroupMembers');
    }

    $self->Join(
        ALIAS1 => $group_members,
        FIELD1 => 'MemberId',
        ALIAS2 => $principals,
        FIELD2 => 'id'
    );
    $self->Limit(
        ALIAS => $group_members,
        FIELD => 'Disabled',
        VALUE => 0,
    ) if $args{'IncludeSubgroupMembers'};

    return $group_members;
}

# XXX: should be generalized
sub _JoinGroups
{
    my $self = shift;
    my %args = (@_);

    my $group_members = $self->_JoinGroupMembers( %args );
    my $groups = $self->NewAlias('Groups');
    $self->Join(
        ALIAS1 => $groups,
        FIELD1 => 'id',
        ALIAS2 => $group_members,
        FIELD2 => 'GroupId'
    );

    return $groups;
}

# XXX: should be generalized
sub _JoinACL
{
    my $self = shift;
    my %args = (
        Right                  => undef,
        IncludeSuperusers      => undef,
        @_,
    );

    if ( $args{'Right'} ) {
        my $canonic = RT::ACE->CanonicalizeRightName( $args{'Right'} );
        unless ( $canonic ) {
            $RT::Logger->error("Invalid right. Couldn't canonicalize right '$args{'Right'}'");
        }
        else {
            $args{'Right'} = $canonic;
        }
    }

    my $acl = $self->NewAlias('ACL');
    $self->Limit(
        ALIAS    => $acl,
        FIELD    => 'RightName',
        OPERATOR => ( $args{Right} ? '=' : 'IS NOT' ),
        VALUE => $args{Right} || 'NULL',
        ENTRYAGGREGATOR => 'OR'
    );
    if ( $args{'IncludeSuperusers'} and $args{'Right'} ) {
        $self->Limit(
            ALIAS           => $acl,
            FIELD           => 'RightName',
            OPERATOR        => '=',
            VALUE           => 'SuperUser',
            ENTRYAGGREGATOR => 'OR'
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
    if ( UNIVERSAL::isa( $args{'Object'}, 'RT::Ticket' ) ) {
        # If we're looking at ticket rights, we also want to look at the associated queue rights.
        # this is a little bit hacky, but basically, now that we've done the ticket roles magic,
        # we load the queue object and ask all the rest of our questions about the queue.

        # XXX: This should be abstracted into object itself
        if( $args{'Object'}->id ) {
            push @objects, $args{'Object'}->ACLEquivalenceObjects;
        } else {
            push @objects, 'RT::Queue';
        }
    }

    if( $args{'IncludeSystemRights'} ) {
        push @objects, $RT::System;
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

    my $from_role = $self->Clone;
    $from_role->WhoHaveRoleRight( %args );

    my $from_group = $self->Clone;
    $from_group->WhoHaveGroupRight( %args );

    #XXX: DIRTY HACK
    use DBIx::SearchBuilder::Union;
    my $union = DBIx::SearchBuilder::Union->new();
    $union->add( $from_group );
    $union->add( $from_role );
    %$self = %$union;
    bless $self, ref($union);

    return;
}

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

    my @objects = $self->_GetEquivObjects( %args );

    # RT::Principal->RolesWithRight only expects EquivObjects, so we need to
    # fill it.  At the very least it needs $args{Object}, which
    # _GetEquivObjects above does for us.
    unshift @{$args{'EquivObjects'}}, @objects;

    my @roles = RT::Principal->RolesWithRight( %args );
    unless ( @roles ) {
        $self->_AddSubClause( "WhichRole", "(main.id = 0)" );
        return;
    }

    my $groups = $self->_JoinGroups( %args );

    # no system user
    $self->Limit( ALIAS => $self->PrincipalsAlias,
                  FIELD => 'id',
                  OPERATOR => '!=',
                  VALUE => RT->SystemUser->id
                );

    $self->_AddSubClause( "WhichRole", "(". join( ' OR ',
        map $RT::Handle->__MakeClauseCaseInsensitive("$groups.Name", '=', "'$_'"), @roles
    ) .")" );

    my @groups_clauses = $self->_RoleClauses( $groups, @objects );
    $self->_AddSubClause( "WhichObject", "(". join( ' OR ', @groups_clauses ) .")" )
        if @groups_clauses;

    return;
}

sub _RoleClauses {
    my $self = shift;
    my $groups = shift;
    my @objects = @_;

    my @groups_clauses;
    foreach my $obj ( @objects ) {
        my $type = ref($obj)? ref($obj): $obj;

        my $role_clause = $RT::Handle->__MakeClauseCaseInsensitive("$groups.Domain", '=', "'$type-Role'");

        if ( my $id = eval { $obj->id } ) {
            $role_clause .= " AND $groups.Instance = $id";
        }
        push @groups_clauses, "($role_clause)";
    }
    return @groups_clauses;
}

# XXX: should be generalized
sub _JoinGroupMembersForGroupRights
{
    my $self = shift;
    my %args = (@_);
    my $group_members = $self->_JoinGroupMembers( %args );
    $self->Limit( ALIAS => $args{'ACLAlias'},
                  FIELD => 'PrincipalId',
                  VALUE => "$group_members.GroupId",
                  QUOTEVALUE => 0,
                );
    return $group_members;
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
    my $acl = $self->_JoinACL( %args );

    my ($check_objects) = ('');
    my @objects = $self->_GetEquivObjects( %args );

    my %seen;
    if ( @objects ) {
        my @object_clauses;
        foreach my $obj ( @objects ) {
            my $type = ref($obj)? ref($obj): $obj;
            my $id = 0;
            $id = $obj->id if ref($obj) && UNIVERSAL::can($obj, 'id') && $obj->id;
            next if $seen{"$type-$id"}++;

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
    $self->_AddSubClause( "WhichObject", "($check_objects)" );
    
    my $group_members = $self->_JoinGroupMembersForGroupRights( %args, ACLAlias => $acl );
    # Find only members of groups that have the right.
    $self->Limit( ALIAS => $acl,
                  FIELD => 'PrincipalType',
                  VALUE => 'Group',
                );
    
    # no system user
    $self->Limit( ALIAS => $self->PrincipalsAlias,
                  FIELD => 'id',
                  OPERATOR => '!=',
                  VALUE => RT->SystemUser->id
                );
    return $group_members;
}


=head2 WhoBelongToGroups { Groups => ARRAYREF, IncludeSubgroupMembers => 1, IncludeUnprivileged => 0 }

Return members who belong to any of the groups passed in the groups whose IDs
are included in the Groups arrayref.

If IncludeSubgroupMembers is true (default) then members of any group that's a
member of one of the passed groups are returned. If it's cleared then only
direct member users are returned.

If IncludeUnprivileged is false (default) then only privileged members are
returned; otherwise either privileged or unprivileged group members may be
returned.

=cut

sub WhoBelongToGroups {
    my $self = shift;
    my %args = ( Groups                 => undef,
                 IncludeSubgroupMembers => 1,
                 IncludeUnprivileged    => 0,
                 @_ );

    if (!$args{'IncludeUnprivileged'}) {
        $self->LimitToPrivileged();
    }
    my $group_members = $self->_JoinGroupMembers( %args );

    $self->Limit(
        ALIAS      => $group_members,
        FIELD      => 'GroupId',
        OPERATOR   => 'IN',
        VALUE      => [ 0, @{$args{'Groups'}} ],
    );
}

=head2 SimpleSearch

Does a 'simple' search of Users against a specified Term.

This Term is compared to a number of fields using various types of SQL
comparison operators.

Ensures that the returned collection of Users will have a value for Return.

This method is passed the following.  You must specify a Term and a Return.

    Privileged - Whether or not to limit to Privileged Users (0 or 1)
    Fields     - Hashref of data - defaults to C<$UserSearchFields> emulate that if you want to override
    Term       - String that is in the fields specified by Fields
    Return     - What field on the User you want to be sure isn't empty
    Exclude    - Array reference of ids to exclude
    Max        - What to limit this collection to

=cut

sub SimpleSearch {
    my $self = shift;
    my %args = (
        Privileged  => 0,
        Fields      => RT->Config->Get('UserSearchFields'),
        Term        => undef,
        Exclude     => [],
        Return      => undef,
        Max         => 10,
        @_
    );

    return $self unless defined $args{Return}
                        and defined $args{Term}
                        and length $args{Term};

    $self->RowsPerPage( $args{Max} );

    $self->LimitToPrivileged() if $args{Privileged};

    while (my ($name, $op) = each %{$args{Fields}}) {
        $op = 'STARTSWITH'
        unless $op =~ /^(?:LIKE|(?:START|END)SWITH|=|!=)$/i;

        if ($name =~ /^CF\.(?:\{(.*)}|(.*))$/) {
            my $cfname = $1 || $2;
            my $cf = RT::CustomField->new(RT->SystemUser);
            my ($ok, $msg) = $cf->LoadByName( Name => $cfname, LookupType => 'RT::User');
            if ( $ok ) {
                $self->LimitCustomField(
                    CUSTOMFIELD     => $cf->Id,
                    OPERATOR        => $op,
                    VALUE           => $args{Term},
                    ENTRYAGGREGATOR => 'OR',
                    SUBCLAUSE       => 'autocomplete',
                );
            } else {
                RT->Logger->warning("Asked to search custom field $name but unable to load a User CF with the name $cfname: $msg");
            }
        } else {
            $self->Limit(
                FIELD           => $name,
                OPERATOR        => $op,
                VALUE           => $args{Term},
                ENTRYAGGREGATOR => 'OR',
                SUBCLAUSE       => 'autocomplete',
            );
        }
    }

    # Exclude users we don't want
    $self->Limit(FIELD => 'id', OPERATOR => 'NOT IN', VALUE => $args{Exclude} )
        if @{$args{Exclude}};

    if ( RT->Config->Get('DatabaseType') eq 'Oracle' ) {
        $self->Limit(
            FIELD    => $args{Return},
            OPERATOR => 'IS NOT',
            VALUE    => 'NULL',
        );
    }
    else {
        $self->Limit( FIELD => $args{Return}, OPERATOR => '!=', VALUE => '' );
        $self->Limit(
            FIELD           => $args{Return},
            OPERATOR        => 'IS NOT',
            VALUE           => 'NULL',
            ENTRYAGGREGATOR => 'AND'
        );
    }

    return $self;
}

RT::Base->_ImportOverlays();

1;

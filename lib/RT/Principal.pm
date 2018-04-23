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

#

package RT::Principal;

use strict;
use warnings;


use base 'RT::Record';

sub Table {'Principals'}



use RT;
use RT::Group;
use RT::User;

# Set up the ACL cache on startup
our $_ACL_CACHE;
InvalidateACLCache();

require RT::ACE;
RT::ACE->RegisterCacheHandler(sub { RT::Principal->InvalidateACLCache() });

=head2 IsGroup

Returns true if this principal is a group. 
Returns undef, otherwise

=cut

sub IsGroup {
    my $self = shift;
    if ( defined $self->PrincipalType && 
            $self->PrincipalType eq 'Group' ) {
        return 1;
    }
    return undef;
}

=head2 IsRoleGroup

Returns true if this principal is a role group.
Returns undef, otherwise.

=cut

sub IsRoleGroup {
    my $self = shift;
    return ($self->IsGroup and $self->Object->RoleClass)
        ? 1 : undef;
}

=head2 IsUser 

Returns true if this principal is a User. 
Returns undef, otherwise

=cut

sub IsUser {
    my $self = shift;
    if ($self->PrincipalType eq 'User') {
        return(1);
    }
    else {
        return undef;
    }
}



=head2 Object

Returns the user or group associated with this principal

=cut

sub Object {
    my $self = shift;

    unless ( $self->{'object'} ) {
        if ( $self->IsUser ) {
           $self->{'object'} = RT::User->new($self->CurrentUser);
        }
        elsif ( $self->IsGroup ) {
            $self->{'object'}  = RT::Group->new($self->CurrentUser);
        }
        else { 
            $RT::Logger->crit("Found a principal (".$self->Id.") that was neither a user nor a group");
            return(undef);
        }
        $self->{'object'}->Load( $self->id );
    }
    return ($self->{'object'});


}

=head2 DisplayName

Returns the relevant display name for this principal

=cut

sub DisplayName {
    my $self = shift;

    return undef unless $self->Object;

    # If this principal is an ACLEquivalence group, return the user name
    return $self->Object->InstanceObj->Name if ($self->Object->Domain eq 'ACLEquivalence');

    # Otherwise, show the group name
    return $self->Object->Label;
}

=head2 GrantRight  { Right => RIGHTNAME, Object => undef }

A helper function which calls RT::ACE->Create



   Returns a tuple of (STATUS, MESSAGE);  If the call succeeded, STATUS is true. Otherwise it's 
   false.

=cut

sub GrantRight {
    my $self = shift;
    my %args = (
        Right => undef,
        Object => undef,
        @_
    );

    return (0, "Permission Denied") if $args{'Right'} eq 'ExecuteCode'
        and RT->Config->Get('DisallowExecuteCode');

    #ACL check handled in ACE.pm
    my $ace = RT::ACE->new( $self->CurrentUser );

    my $type = $self->_GetPrincipalTypeForACL();

    # If it's a user, we really want to grant the right to their 
    # user equivalence group
    my ($id, $msg) = $ace->Create(
        RightName     => $args{'Right'},
        Object        => $args{'Object'},
        PrincipalType => $type,
        PrincipalId   => $self->Id,
    );

    return ($id, $msg);
}


=head2 RevokeRight { Right => "RightName", Object => "object" }

Delete a right that a user has 


   Returns a tuple of (STATUS, MESSAGE);  If the call succeeded, STATUS is true. Otherwise it's 
      false.


=cut

sub RevokeRight {

    my $self = shift;
    my %args = (
        Right  => undef,
        Object => undef,
        @_
    );

    #if we haven't specified any sort of right, we're talking about a global right
    if (!defined $args{'Object'} && !defined $args{'ObjectId'} && !defined $args{'ObjectType'}) {
        $args{'Object'} = $RT::System;
    }
    #ACL check handled in ACE.pm
    my $type = $self->_GetPrincipalTypeForACL();

    my $ace = RT::ACE->new( $self->CurrentUser );
    my ($status, $msg) = $ace->LoadByValues(
        RightName     => $args{'Right'},
        Object        => $args{'Object'},
        PrincipalType => $type,
        PrincipalId   => $self->Id
    );

    if ( not $status and $msg =~ /Invalid right/ ) {
        $RT::Logger->warn("Tried to revoke the invalid right '$args{Right}', ignoring it.");
        return (1);
    }

    return ($status, $msg) unless $status;

    my $right = $ace->RightName;
    ($status, $msg) = $ace->Delete;

    return ($status, $msg);
}



=head2 HasRight (Right => 'right' Object => undef)

Checks to see whether this principal has the right "Right" for the Object
specified. This takes the params:

=over 4

=item Right

name of a right

=item Object

an RT style object (->id will get its id)

=back

Returns 1 if a matching ACE was found. Returns undef if no ACE was found.

Use L</HasRights> to fill a fast cache, especially if you're going to
check many different rights with the same principal and object.

=cut

sub HasRight {

    my $self = shift;
    my %args = ( Right        => undef,
                 Object       => undef,
                 EquivObjects => undef,
                 @_,
               );

    # RT's SystemUser always has all rights
    if ( $self->id == RT->SystemUser->id ) {
        return 1;
    }

    if ( my $right = RT::ACE->CanonicalizeRightName( $args{'Right'} ) ) {
        $args{'Right'} = $right;
    } else {
        $RT::Logger->error(
               "Invalid right. Couldn't canonicalize right '$args{'Right'}'");
        return undef;
    }

    return undef if $args{'Right'} eq 'ExecuteCode'
        and RT->Config->Get('DisallowExecuteCode');

    $args{'EquivObjects'} = [ @{ $args{'EquivObjects'} } ]
        if $args{'EquivObjects'};

    if ( $self->__Value('Disabled') ) {
        $RT::Logger->debug(   "Disabled User #"
                            . $self->id
                            . " failed access check for "
                            . $args{'Right'} );
        return (undef);
    }

    if ( eval { $args{'Object'}->id } ) {
        push @{ $args{'EquivObjects'} }, $args{'Object'};
    } else {
        $RT::Logger->crit("HasRight called with no valid object");
        return (undef);
    }

    {
        my $cached = $_ACL_CACHE->{
            $self->id .';:;'. ref($args{'Object'}) .'-'. $args{'Object'}->id
        };
        return $cached->{'SuperUser'} || $cached->{ $args{'Right'} }
            if $cached;
    }

    unshift @{ $args{'EquivObjects'} },
        $args{'Object'}->ACLEquivalenceObjects;
    unshift @{ $args{'EquivObjects'} }, $RT::System;

    # If we've cached a win or loss for this lookup say so

# Construct a hashkeys to cache decisions:
# 1) full_hashkey - key for any result and for full combination of uid, right and objects
# 2) short_hashkey - one key for each object to store positive results only, it applies
# only to direct group rights and partly to role rights
    my $full_hashkey = join (";:;", $self->id, $args{'Right'});
    foreach ( @{ $args{'EquivObjects'} } ) {
        my $ref_id = $self->_ReferenceId($_);
        $full_hashkey .= ";:;".$ref_id;

        my $short_hashkey = join(";:;", $self->id, $args{'Right'}, $ref_id);
        my $cached_answer = $_ACL_CACHE->{ $short_hashkey };
        return $cached_answer > 0 if defined $cached_answer;
    }

    {
        my $cached_answer = $_ACL_CACHE->{ $full_hashkey };
        return $cached_answer > 0 if defined $cached_answer;
    }

    my ( $hitcount, $via_obj ) = $self->_HasRight(%args);

    $_ACL_CACHE->{ $full_hashkey } = $hitcount ? 1 : -1;
    $_ACL_CACHE->{ join ';:;',  $self->id, $args{'Right'}, $via_obj } = 1
        if $via_obj && $hitcount;

    return ($hitcount);
}

=head2 HasRights

Returns a hash reference with all rights this principal has on an
object. Takes Object as a named argument.

Main use case of this method is the following:

    $ticket->CurrentUser->PrincipalObj->HasRights( Object => $ticket );
    ...
    $ticket->CurrentUserHasRight('A');
    ...
    $ticket->CurrentUserHasRight('Z');

Results are cached and the cache is used in this and, as well, in L</HasRight>
method speeding it up. Don't use hash reference returned by this method
directly for rights checks as it's more complicated then it seems, especially
considering config options like 'DisallowExecuteCode'.

=cut

sub HasRights {
    my $self = shift;
    my %args = (
        Object       => undef,
        EquivObjects => undef,
        @_
    );
    return {} if $self->__Value('Disabled');

    my $object = $args{'Object'};
    unless ( eval { $object->id } ) {
        $RT::Logger->crit("HasRights called with no valid object");
    }

    my $cache_key = $self->id .';:;'. ref($object) .'-'. $object->id;
    my $cached = $_ACL_CACHE->{ $cache_key };
    return $cached if $cached;

    push @{ $args{'EquivObjects'} }, $object;
    unshift @{ $args{'EquivObjects'} },
        $args{'Object'}->ACLEquivalenceObjects;
    unshift @{ $args{'EquivObjects'} }, $RT::System;

    my %res = ();
    {
        my $query
            = "SELECT DISTINCT ACL.RightName "
            . $self->_HasGroupRightQuery(
                EquivObjects => $args{'EquivObjects'}
            );
        my $rights = $RT::Handle->dbh->selectcol_arrayref($query);
        unless ($rights) {
            $RT::Logger->warning( $RT::Handle->dbh->errstr );
            return ();
        }
        $res{$_} = 1 foreach @$rights;
    }
    my $roles;
    {
        my $query
            = "SELECT DISTINCT Groups.Name "
            . $self->_HasRoleRightQuery(
                EquivObjects => $args{'EquivObjects'}
            );
        $roles = $RT::Handle->dbh->selectcol_arrayref($query);
        unless ($roles) {
            $RT::Logger->warning( $RT::Handle->dbh->errstr );
            return ();
        }
    }
    if ( @$roles ) {
        my $query
            = "SELECT DISTINCT ACL.RightName "
            . $self->_RolesWithRightQuery(
                EquivObjects => $args{'EquivObjects'}
            )
            . ' AND ('. join( ' OR ', map "PrincipalType = '$_'", @$roles ) .')'
        ;
        my $rights = $RT::Handle->dbh->selectcol_arrayref($query);
        unless ($rights) {
            $RT::Logger->warning( $RT::Handle->dbh->errstr );
            return ();
        }
        $res{$_} = 1 foreach @$rights;
    }

    delete $res{'ExecuteCode'} if 
        RT->Config->Get('DisallowExecuteCode');

    $_ACL_CACHE->{ $cache_key } = \%res;
    return \%res;
}

=head2 _HasRight

Low level HasRight implementation, use HasRight method instead.

=cut

sub _HasRight {
    my $self = shift;
    {
        my ( $hit, @other ) = $self->_HasGroupRight(@_);
        return ( $hit, @other ) if $hit;
    }
    {
        my ( $hit, @other ) = $self->_HasRoleRight(@_);
        return ( $hit, @other ) if $hit;
    }
    return (0);
}

# this method handles role rights partly in situations
# where user plays role X on an object and as well the right is
# assigned to this role X of the object, for example right CommentOnTicket
# is granted to Cc role of a queue and user is in cc list of the queue
sub _HasGroupRight {
    my $self = shift;
    my %args = ( Right        => undef,
                 EquivObjects => [],
                 @_
               );

    my $query
        = "SELECT ACL.id, ACL.ObjectType, ACL.ObjectId "
        . $self->_HasGroupRightQuery( %args );

    $self->_Handle->ApplyLimits( \$query, 1 );
    my ( $hit, $obj, $id ) = $self->_Handle->FetchResult($query);
    return (0) unless $hit;

    $obj .= "-$id" if $id;
    return ( 1, $obj );
}

sub _HasGroupRightQuery {
    my $self = shift;
    my %args = (
        Right        => undef,
        EquivObjects => [],
        @_
    );

    my $query
        = "FROM ACL, Principals, CachedGroupMembers WHERE "

        # Never find disabled groups.
        . "Principals.id = ACL.PrincipalId "
        . "AND Principals.PrincipalType = 'Group' "
        . "AND Principals.Disabled = 0 "

# See if the principal is a member of the group recursively or _is the rightholder_
# never find recursively disabled group members
# also, check to see if the right is being granted _directly_ to this principal,
#  as is the case when we want to look up group rights
        . "AND CachedGroupMembers.GroupId  = ACL.PrincipalId "
        . "AND CachedGroupMembers.GroupId  = Principals.id "
        . "AND CachedGroupMembers.MemberId = ". $self->Id . " "
        . "AND CachedGroupMembers.Disabled = 0 ";

    my @clauses;
    foreach my $obj ( @{ $args{'EquivObjects'} } ) {
        my $type = ref($obj) || $obj;
        my $clause = "ACL.ObjectType = '$type'";

        if ( defined eval { $obj->id } ) {    # it might be 0
            $clause .= " AND ACL.ObjectId = " . $obj->id;
        }

        push @clauses, "($clause)";
    }
    if (@clauses) {
        $query .= " AND (" . join( ' OR ', @clauses ) . ")";
    }
    if ( my $right = $args{'Right'} ) {
        # Only find superuser or rights with the name $right
        $query .= " AND (ACL.RightName = 'SuperUser' "
            . ( $right ne 'SuperUser' ? "OR ACL.RightName = '$right'" : '' )
        . ") ";
    }
    return $query;
}

sub _HasRoleRight {
    my $self = shift;
    my %args = ( Right        => undef,
                 EquivObjects => [],
                 @_
               );

    my @roles = $self->RolesWithRight(%args);
    return 0 unless @roles;

    my $query = "SELECT Groups.id "
        . $self->_HasRoleRightQuery( %args, Roles => \@roles );

    $self->_Handle->ApplyLimits( \$query, 1 );
    my ($hit) = $self->_Handle->FetchResult($query);
    return (1) if $hit;

    return 0;
}

sub _HasRoleRightQuery {
    my $self = shift;
    my %args = ( Right        => undef,
                 EquivObjects => [],
                 Roles        => undef,
                 @_
               );

    my $query =
        " FROM Groups, Principals, CachedGroupMembers WHERE "

        # Never find disabled things
        . "Principals.Disabled = 0 " . "AND CachedGroupMembers.Disabled = 0 "

        # We always grant rights to Groups
        . "AND Principals.id = Groups.id "
        . "AND Principals.PrincipalType = 'Group' "

# See if the principal is a member of the group recursively or _is the rightholder_
# never find recursively disabled group members
# also, check to see if the right is being granted _directly_ to this principal,
#  as is the case when we want to look up group rights
        . "AND Principals.id = CachedGroupMembers.GroupId "
        . "AND CachedGroupMembers.MemberId = " . $self->Id . " "
    ;

    if ( $args{'Roles'} ) {
        $query .= "AND (" . join( ' OR ',
            map $RT::Handle->__MakeClauseCaseInsensitive('Groups.Name', '=', "'$_'"),
            @{ $args{'Roles'} }
        ) . ")";
    }

    my @object_clauses = RT::Users->_RoleClauses( Groups => @{ $args{'EquivObjects'} } );
    $query .= " AND (" . join( ' OR ', @object_clauses ) . ")";
    return $query;
}

=head2 RolesWithRight

Returns list with names of roles that have right on
set of objects. Takes Right, EquiveObjects,
IncludeSystemRights and IncludeSuperusers arguments.

IncludeSystemRights is true by default, rights
granted systemwide are ignored when IncludeSystemRights
is set to a false value.

IncludeSuperusers is true by default, SuperUser right
is not checked if it's set to a false value.

=cut

sub RolesWithRight {
    my $self = shift;
    my %args = ( Right               => undef,
                 IncludeSystemRights => 1,
                 IncludeSuperusers   => 1,
                 EquivObjects        => [],
                 @_
               );

    return () if $args{'Right'} eq 'ExecuteCode'
        and RT->Config->Get('DisallowExecuteCode');

    my $query = "SELECT DISTINCT PrincipalType "
        . $self->_RolesWithRightQuery( %args );

    my $roles = $RT::Handle->dbh->selectcol_arrayref($query);
    unless ($roles) {
        $RT::Logger->warning( $RT::Handle->dbh->errstr );
        return ();
    }
    return @$roles;
}

sub _RolesWithRightQuery {
    my $self = shift;
    my %args = ( Right               => undef,
                 IncludeSystemRights => 1,
                 IncludeSuperusers   => 1,
                 EquivObjects        => [],
                 @_
               );

    my $query = " FROM ACL WHERE"

        # we need only roles
        . " PrincipalType != 'Group'";

    if ( my $right = $args{'Right'} ) {
        $query .=
            # Only find superuser or rights with the requested right
            " AND ( RightName = '$right' "

            # Check SuperUser if we were asked to
            . ( $args{'IncludeSuperusers'} ? "OR RightName = 'SuperUser' " : '' )
            . ")";
    }

    # skip rights granted on system level if we were asked to
    unless ( $args{'IncludeSystemRights'} ) {
        $query .= " AND ObjectType != 'RT::System'";
    }

    my (@object_clauses);
    foreach my $obj ( @{ $args{'EquivObjects'} } ) {
        my $type = ref($obj) ? ref($obj) : $obj;

        my $object_clause = "ObjectType = '$type'";
        if ( my $id = eval { $obj->id } ) {
            $object_clause .= " AND ObjectId = $id";
        }
        push @object_clauses, "($object_clause)";
    }

    # find ACLs that are related to our objects only
    $query .= " AND (" . join( ' OR ', @object_clauses ) . ")"
        if @object_clauses;

    return $query;
}


=head2 InvalidateACLCache

Cleans out and reinitializes the user rights cache

=cut

sub InvalidateACLCache {
    $_ACL_CACHE = {}
}





=head2 _GetPrincipalTypeForACL

Gets the principal type. if it's a user, it's a user. if it's a role group and it has a Type, 
return that. if it has no type, return group.

=cut

sub _GetPrincipalTypeForACL {
    my $self = shift;
    if ($self->IsRoleGroup) {
        return $self->Object->Name;
    } else {
        return $self->PrincipalType;
    }
}



=head2 _ReferenceId

Returns a list uniquely representing an object or normal scalar.

For a scalar, its string value is returned.
For an object that has an id() method which returns a value, its class name and id are returned as a string separated by a "-".
For an object that has an id() method which returns false, its class name is returned.

=cut

sub _ReferenceId {
    my $self = shift;
    my $scalar = shift;
    my $id = eval { $scalar->id };
    if ($@) {
        return $scalar;
    } elsif ($id) {
        return ref($scalar) . "-" . $id;
    } else {
        return ref($scalar);
    }
}

=head2 id

Returns the current value of id.
(In the database, id is stored as int(11).)


=cut


=head2 PrincipalType

Returns the current value of PrincipalType.
(In the database, PrincipalType is stored as varchar(16).)



=head2 SetPrincipalType VALUE


Set PrincipalType to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, PrincipalType will be stored as a varchar(16).)


=cut


=head2 Disabled

Returns the current value of Disabled.
(In the database, Disabled is stored as smallint(6).)



=head2 SetDisabled VALUE


Set Disabled to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Disabled will be stored as a smallint(6).)


=cut



sub _CoreAccessible {
    {

        id =>
                {read => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        PrincipalType =>
                {read => 1, write => 1, sql_type => 12, length => 16,  is_blob => 0,  is_numeric => 0,  type => 'varchar(16)', default => ''},
        Disabled =>
                {read => 1, write => 1, sql_type => 5, length => 6,  is_blob => 0,  is_numeric => 1,  type => 'smallint(6)', default => '0'},

 }
};


sub __DependsOn {
    my $self = shift;
    my %args = (
        Shredder => undef,
        Dependencies => undef,
        @_,
    );
    my $deps = $args{'Dependencies'};
    my $list = [];

# Group or User
# Could be wiped allready
    my $obj = $self->Object;
    if( defined $obj->id ) {
        push( @$list, $obj );
    }

# Access Control List
    my $objs = RT::ACL->new( $self->CurrentUser );
    $objs->Limit(
        FIELD => 'PrincipalId',
        OPERATOR        => '=',
        VALUE           => $self->Id
    );
    push( @$list, $objs );

# AddWatcher/DelWatcher txns
    foreach my $type ( qw(AddWatcher DelWatcher) ) {
        my $objs = RT::Transactions->new( $self->CurrentUser );
        $objs->Limit( FIELD => $type =~ /Add/? 'NewValue': 'OldValue', VALUE => $self->Id );
        $objs->Limit( FIELD => 'Type', VALUE => $type );
        push( @$list, $objs );
    }

    $deps->_PushDependencies(
        BaseObject => $self,
        Flags => RT::Shredder::Constants::DEPENDS_ON,
        TargetObjects => $list,
        Shredder => $args{'Shredder'}
    );
    return $self->SUPER::__DependsOn( %args );
}

RT::Base->_ImportOverlays();

1;

# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2010 Best Practical Solutions, LLC
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

use Cache::Simple::TimedExpiry;


use RT;
use RT::Group;
use RT::User;

# Set up the ACL cache on startup
our $_ACL_CACHE;
InvalidateACLCache();


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
        $self->{'object'}->Load( $self->ObjectId() );
    }
    return ($self->{'object'});


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

    return (0, "Permission denied") if $args{'Right'} eq 'ExecuteCode'
        and RT->Config->Get('DisallowExecuteCode');

    #ACL check handled in ACE.pm
    my $ace = RT::ACE->new( $self->CurrentUser );

    my $type = $self->_GetPrincipalTypeForACL();

    RT->System->QueueCacheNeedsUpdate(1) if $args{'Right'} eq 'SeeQueue';

    # If it's a user, we really want to grant the right to their 
    # user equivalence group
    return $ace->Create(
        RightName     => $args{'Right'},
        Object        => $args{'Object'},
        PrincipalType => $type,
        PrincipalId   => $self->Id,
    );
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

    RT->System->QueueCacheNeedsUpdate(1) if $args{'Right'} eq 'SeeQueue';
    return ($status, $msg) unless $status;
    return $ace->Delete;
}



=head2 sub HasRight (Right => 'right' Object => undef)


Checks to see whether this principal has the right "Right" for the Object
specified. If the Object parameter is omitted, checks to see whether the 
user has the right globally.

This still hard codes to check to see if a user has queue-level rights
if we ask about a specific ticket.


This takes the params:

    Right => name of a right

    And either:

    Object => an RT style object (->id will get its id)


Returns 1 if a matching ACE was found.

Returns undef if no ACE was found.

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

    $args{'Right'} = RT::ACE->CanonicalizeRightName( $args{'Right'} );
    unless ( $args{'Right'} ) {
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

    unshift @{ $args{'EquivObjects'} },
        $args{'Object'}->ACLEquivalenceObjects;

    unshift @{ $args{'EquivObjects'} }, $RT::System
        unless $self->can('_IsOverrideGlobalACL')
            && $self->_IsOverrideGlobalACL( $args{'Object'} );

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
        my $cached_answer = $_ACL_CACHE->fetch($short_hashkey);
        return $cached_answer > 0 if defined $cached_answer;
    }

    {
        my $cached_answer = $_ACL_CACHE->fetch($full_hashkey);
        return $cached_answer > 0 if defined $cached_answer;
    }

    my ( $hitcount, $via_obj ) = $self->_HasRight(%args);

    $_ACL_CACHE->set( $full_hashkey => $hitcount ? 1 : -1 );
    $_ACL_CACHE->set( join(';:;',  $self->id, $args{'Right'},$via_obj) => 1 )
        if $via_obj && $hitcount;

    return ($hitcount);
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
        $query .= "AND (" . join( ' OR ', map "Groups.Type = '$_'", @{ $args{'Roles'} } ) . ")";
    }

    my (@object_clauses);
    foreach my $obj ( @{ $args{'EquivObjects'} } ) {
        my $type = ref($obj) ? ref($obj) : $obj;

        my $clause = "Groups.Domain = '$type-Role'";

        # XXX: Groups.Instance is VARCHAR in DB, we should quote value
        # if we want mysql 4.0 use indexes here. we MUST convert that
        # field to integer and drop this quotes.
        if ( my $id = eval { $obj->id } ) {
            $clause .= " AND Groups.Instance = '$id'";
        }
        push @object_clauses, "($clause)";
    }
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
    $_ACL_CACHE = Cache::Simple::TimedExpiry->new();
    my $lifetime;
    $lifetime = $RT::Config->Get('ACLCacheLifetime') if $RT::Config;
    $_ACL_CACHE->expire_after( $lifetime || 60 );
}





=head2 _GetPrincipalTypeForACL

Gets the principal type. if it's a user, it's a user. if it's a role group and it has a Type, 
return that. if it has no type, return group.

=cut

sub _GetPrincipalTypeForACL {
    my $self = shift;
    if ($self->PrincipalType eq 'Group' && $self->Object->Domain =~ /Role$/) {
        return $self->Object->Type;
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


1;

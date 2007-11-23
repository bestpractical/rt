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
#

package RT::Principal;

use strict;
use warnings;

no warnings qw(redefine);

use Cache::Simple::TimedExpiry;



use RT::Group;
use RT::User;

# Set up the ACL cache on startup
our $_ACL_CACHE;
InvalidateACLCache();

# {{{ IsGroup

=head2 IsGroup

Returns true if this principal is a group. 
Returns undef, otherwise

=cut

sub IsGroup {
    my $self = shift;
    if ($self->PrincipalType eq 'Group') {
        return(1);
    }
    else {
        return undef;
    }
}

# }}}

# {{{ IsUser

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

# }}}

# {{{ Object

=head2 Object

Returns the user or group associated with this principal

=cut

sub Object {
    my $self = shift;

    unless ($self->{'object'}) {
    if ($self->IsUser) {
       $self->{'object'} = RT::User->new($self->CurrentUser);
    }
    elsif ($self->IsGroup) {
        $self->{'object'}  = RT::Group->new($self->CurrentUser);
    }
    else { 
        $RT::Logger->crit("Found a principal (".$self->Id.") that was neither a user nor a group");
        return(undef);
    }
    $self->{'object'}->Load($self->ObjectId());
    }
    return ($self->{'object'});


}
# }}} 

# {{{ ACL Related routines

# {{{ GrantRight 

=head2 GrantRight  { Right => RIGHTNAME, Object => undef }

A helper function which calls RT::ACE->Create



   Returns a tuple of (STATUS, MESSAGE);  If the call succeeded, STATUS is true. Otherwise it's 
   false.

=cut

sub GrantRight {
    my $self = shift;
    my %args = ( Right => undef,
                Object => undef,
                @_);


    unless ($args{'Right'}) {
        return(0, $self->loc("Invalid Right"));
    }


    #ACL check handled in ACE.pm
    my $ace = RT::ACE->new( $self->CurrentUser );


    my $type = $self->_GetPrincipalTypeForACL();

    # If it's a user, we really want to grant the right to their 
    # user equivalence group
        return ( $ace->Create(RightName => $args{'Right'},
                          Object => $args{'Object'},
                          PrincipalType =>  $type,
                          PrincipalId => $self->Id
                          ) );
}
# }}}

# {{{ RevokeRight

=head2 RevokeRight { Right => "RightName", Object => "object" }

Delete a right that a user has 


   Returns a tuple of (STATUS, MESSAGE);  If the call succeeded, STATUS is true. Otherwise it's 
      false.


=cut

sub RevokeRight {

    my $self = shift;
    my %args = (
        Right      => undef,
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
    $ace->LoadByValues(
        RightName     => $args{'Right'},
        Object    => $args{'Object'},
        PrincipalType => $type,
        PrincipalId   => $self->Id
    );

    unless ( $ace->Id ) {
        return ( 0, $self->loc("ACE not found") );
    }
    return ( $ace->Delete );
}

# }}}

# {{{ sub _CleanupInvalidDelegations

=head2 sub _CleanupInvalidDelegations { InsideTransaction => undef }

Revokes all ACE entries delegated by this principal which are
inconsistent with this principal's current delegation rights.  Does
not perform permission checks, but takes no action and returns success
if this principal still retains DelegateRights.  Should only ever be
called from inside the RT library.

If this principal is a group, recursively calls this method on each
cached user member of itself.

If called from inside a transaction, specify a true value for the
InsideTransaction parameter.

Returns a true value if the deletion succeeded; returns a false value
and logs an internal error if the deletion fails (should not happen).

=cut

# This is currently just a stub for the methods of the same name in
# RT::User and RT::Group.

sub _CleanupInvalidDelegations {
    my $self = shift;
    unless ( $self->Id ) {
	$RT::Logger->warning("Principal not loaded.");
	return (undef);
    }
    return ($self->Object->_CleanupInvalidDelegations(@_));
}

# }}}

# {{{ sub HasRight

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
    my %args = (
        Right        => undef,
        Object       => undef,
        EquivObjects => undef,
        @_,
    );

    unless ( $args{'Right'} ) {
        $RT::Logger->crit("HasRight called without a right");
        return (undef);
    }

    $args{'EquivObjects'} = [ @{ $args{'EquivObjects'} } ]
        if $args{'EquivObjects'};

    if ( $self->Disabled ) {
        $RT::Logger->error( "Disabled User #"
              . $self->id
              . " failed access check for "
              . $args{'Right'} );
        return (undef);
    }

    if (   defined( $args{'Object'} )
        && UNIVERSAL::can( $args{'Object'}, 'id' )
        && $args{'Object'}->id ) {

        push @{ $args{'EquivObjects'} }, $args{'Object'};
    }
    else {
        $RT::Logger->crit("HasRight called with no valid object");
        return (undef);
    }

    # If this object is a ticket, we care about ticket roles and queue roles
    if ( UNIVERSAL::isa( $args{'Object'} => 'RT::Ticket' ) ) {

        # this is a little bit hacky, but basically, now that we've done
        # the ticket roles magic, we load the queue object
        # and ask all the rest of our questions about the queue.
        unshift @{ $args{'EquivObjects'} }, $args{'Object'}->QueueObj;

    }

    unshift @{ $args{'EquivObjects'} }, $RT::System
        unless $self->can('_IsOverrideGlobalACL')
               && $self->_IsOverrideGlobalACL( $args{'Object'} );


    # {{{ If we've cached a win or loss for this lookup say so

    # Construct a hashkeys to cache decisions:
    # 1) full_hashkey - key for any result and for full combination of uid, right and objects
    # 2) short_hashkey - one key for each object to store positive results only, it applies
    # only to direct group rights and partly to role rights
    my $self_id = $self->id;
    my $full_hashkey = join ";:;", $self_id, $args{'Right'};
    foreach ( @{ $args{'EquivObjects'} } ) {
        my $ref_id = _ReferenceId($_);
        $full_hashkey .= ";:;$ref_id";

        my $short_hashkey = join ";:;", $self_id, $args{'Right'}, $ref_id;
        my $cached_answer = $_ACL_CACHE->fetch($short_hashkey);
        return $cached_answer > 0 if defined $cached_answer;
    }

    {
        my $cached_answer = $_ACL_CACHE->fetch($full_hashkey);
        return $cached_answer > 0 if defined $cached_answer;
    }


    my ($hitcount, $via_obj) = $self->_HasRight( %args );

    $_ACL_CACHE->set( $full_hashkey => $hitcount? 1: -1 );
    $_ACL_CACHE->set( "$self_id;:;$args{'Right'};:;$via_obj" => 1 )
        if $via_obj && $hitcount;

    return ($hitcount);
}

=head2 _HasRight

Low level HasRight implementation, use HasRight method instead.

=cut

sub _HasRight
{
    my $self = shift;
    {
        my ($hit, @other) = $self->_HasGroupRight( @_ );
        return ($hit, @other) if $hit;
    }
    {
        my ($hit, @other) = $self->_HasRoleRight( @_ );
        return ($hit, @other) if $hit;
    }
    return (0);
}

# this method handles role rights partly in situations
# where user plays role X on an object and as well the right is
# assigned to this role X of the object, for example right CommentOnTicket
# is granted to Cc role of a queue and user is in cc list of the queue
sub _HasGroupRight
{
    my $self = shift;
    my %args = (
        Right        => undef,
        EquivObjects => [],
        @_
    );
    my $right = $args{'Right'};

    my $query =
      "SELECT ACL.id, ACL.ObjectType, ACL.ObjectId " .
      "FROM ACL, Principals, CachedGroupMembers WHERE " .

      # Only find superuser or rights with the name $right
      "(ACL.RightName = 'SuperUser' OR ACL.RightName = '$right') "

      # Never find disabled groups.
      . "AND Principals.id = ACL.PrincipalId "
      . "AND Principals.PrincipalType = 'Group' "
      . "AND Principals.Disabled = 0 "

      # See if the principal is a member of the group recursively or _is the rightholder_
      # never find recursively disabled group members
      # also, check to see if the right is being granted _directly_ to this principal,
      #  as is the case when we want to look up group rights
      . "AND CachedGroupMembers.GroupId  = ACL.PrincipalId "
      . "AND CachedGroupMembers.GroupId  = Principals.id "
      . "AND CachedGroupMembers.MemberId = ". $self->Id ." "
      . "AND CachedGroupMembers.Disabled = 0 ";

    my @clauses;
    foreach my $obj ( @{ $args{'EquivObjects'} } ) {
        my $type = ref( $obj ) || $obj;
        my $clause = "ACL.ObjectType = '$type'";

        if ( ref($obj) && UNIVERSAL::can($obj, 'id') && $obj->id ) {
            $clause .= " AND ACL.ObjectId = ". $obj->id;
        }

        push @clauses, "($clause)";
    }
    if ( @clauses ) {
        $query .= " AND (". join( ' OR ', @clauses ) .")";
    }

    $self->_Handle->ApplyLimits( \$query, 1 );
    my ($hit, $obj, $id) = $self->_Handle->FetchResult( $query );
    return (0) unless $hit;

    $obj .= "-$id" if $id;
    return (1, $obj);
}

sub _HasRoleRight
{
    my $self = shift;
    my %args = (
        Right        => undef,
        EquivObjects => [],
        @_
    );
    my $right = $args{'Right'};

    my $query =
      "SELECT ACL.id " .
      "FROM ACL, Groups, Principals, CachedGroupMembers WHERE " .

      # Only find superuser or rights with the name $right
      "(ACL.RightName = 'SuperUser' OR ACL.RightName = '$right') "

      # Never find disabled things
      . "AND Principals.Disabled = 0 "
      . "AND CachedGroupMembers.Disabled = 0 "

      # We always grant rights to Groups
      . "AND Principals.id = Groups.id "
      . "AND Principals.PrincipalType = 'Group' "

      # See if the principal is a member of the group recursively or _is the rightholder_
      # never find recursively disabled group members
      # also, check to see if the right is being granted _directly_ to this principal,
      #  as is the case when we want to look up group rights
      . "AND Principals.id = CachedGroupMembers.GroupId "
      . "AND CachedGroupMembers.MemberId = ". $self->Id ." "
      . "AND ACL.PrincipalType = Groups.Type ";

    my (@object_clauses);
    foreach my $obj ( @{ $args{'EquivObjects'} } ) {
        my $type = ref($obj)? ref($obj): $obj;
        my $id;
        $id = $obj->id if ref($obj) && UNIVERSAL::can($obj, 'id') && $obj->id;

        my $object_clause = "ACL.ObjectType = '$type'";
        $object_clause   .= " AND ACL.ObjectId = $id" if $id;
        push @object_clauses, "($object_clause)";
    }
    # find ACLs that are related to our objects only
    $query .= " AND (". join( ' OR ', @object_clauses ) .")";

    # because of mysql bug in versions up to 5.0.45 we do one query per object
    # each query should be faster on any DB as it uses indexes more effective
    foreach my $obj ( @{ $args{'EquivObjects'} } ) {
        my $type = ref($obj)? ref($obj): $obj;
        my $id;
        $id = $obj->id if ref($obj) && UNIVERSAL::can($obj, 'id') && $obj->id;

        my $tmp = $query;
        $tmp .= " AND Groups.Domain = '$type-Role'";
        # XXX: Groups.Instance is VARCHAR in DB, we should quote value
        # if we want mysql 4.0 use indexes here. we MUST convert that
        # field to integer and drop this quotes.
        $tmp .= " AND Groups.Instance = '$id'" if $id;

        $self->_Handle->ApplyLimits( \$tmp, 1 );
        my ($hit) = $self->_Handle->FetchResult( $tmp );
        return (1) if $hit;
    }

    return 0;
}

# }}}

# }}}

# {{{ ACL caching


# {{{ InvalidateACLCache

=head2 InvalidateACLCache

Cleans out and reinitializes the user rights cache

=cut

sub InvalidateACLCache {
    $_ACL_CACHE = Cache::Simple::TimedExpiry->new();
    $_ACL_CACHE->expire_after($RT::ACLCacheLifetime||60);

}

# }}}

# }}}


# {{{ _GetPrincipalTypeForACL

=head2 _GetPrincipalTypeForACL

Gets the principal type. if it's a user, it's a user. if it's a role group and it has a Type, 
return that. if it has no type, return group.

=cut

sub _GetPrincipalTypeForACL {
    my $self = shift;
    my $type;    
    if ($self->PrincipalType eq 'Group' && $self->Object->Domain =~ /Role$/) {
        $type = $self->Object->Type;
    }
    else {
        $type = $self->PrincipalType;
    }

    return($type);
}

# }}}

# {{{ _ReferenceId

=head2 _ReferenceId

Returns a list uniquely representing an object or normal scalar.

For scalars, its string value is returned; for objects that has an
id() method, its class name and Id are returned as a string separated by a "-".

=cut

sub _ReferenceId {
    my $scalar = shift;

    # just return the value for non-objects
    return $scalar unless UNIVERSAL::can($scalar, 'id');

    return ref($scalar) unless $scalar->id;

    # an object -- return the class and id
    return(ref($scalar)."-". $scalar->id);
}

# }}}

1;

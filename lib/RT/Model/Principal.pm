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

package RT::Model::Principal;

use strict;
use warnings;

use Cache::Simple::TimedExpiry;

use RT;
use RT::Model::Group;
use RT::Model::User;

use base qw/RT::Record/;

use Jifty::DBI::Schema;
use Jifty::DBI::Record schema {

    column principal_type => type is 'text';
    column object_id      => type is 'integer';
    column disabled       => type is 'integer', default is '0';

};

sub table {'Principals'}

# Set up the ACL cache on startup
our $_ACL_CACHE;
invalidate_acl_cache();

# {{{ is_group

=head2 is_group

Returns true if this principal is a group. 
Returns undef, otherwise

=cut

sub is_group {
    my $self = shift;
    if ( defined $self->principal_type
        && $self->principal_type eq 'Group' )
    {
        return 1;
    }
    return undef;
}

# }}}

# {{{ is_user

=head2 is_user 

Returns true if this principal is a User. 
Returns undef, otherwise

=cut

sub is_user {
    my $self = shift;
    if ( $self->principal_type eq 'User' ) {
        return (1);
    } else {
        return undef;
    }
}

# }}}

# {{{ Object

=head2 Object

Returns the user or group associated with this principal

=cut

sub object {
    my $self = shift;

    unless ( $self->{'object'} ) {
        if ( $self->is_user ) {
            $self->{'object'} = RT::Model::User->new;
        } elsif ( $self->is_group ) {
            $self->{'object'} = RT::Model::Group->new;
        } else {
            return (undef);
        }
        $self->{'object'}->load( $self->object_id() );
    }
    return ( $self->{'object'} );

}

# }}}

# {{{ ACL Related routines

# {{{ grant_right

=head2 grant_right  { Right => RIGHTNAME, Object => undef }

A helper function which calls RT::Model::ACE->create



   Returns a tuple of (STATUS, MESSAGE);  If the call succeeded, STATUS is true. Otherwise it's 
   false.

=cut

sub grant_right {
    my $self = shift;
    my %args = (
        Right  => undef,
        Object => undef,
        @_
    );

    unless ( $args{'Right'} ) {
        return ( 0, _("Invalid Right") );
    }

    #ACL check handled in ACE.pm
    my $ace = RT::Model::ACE->new;

    my $type = $self->_get_principal_type_for_acl();

    # If it's a user, we really want to grant the right to their
    # user equivalence group
    return (
        $ace->create(
            right_name     => $args{'Right'},
            Object         => $args{'Object'},
            principal_type => $type,
            principal_id   => $self->id
        )
    );
}

# }}}

# {{{ revoke_right

=head2 revoke_right { Right => "right_name", Object => "object" }

Delete a right that a user has 


   Returns a tuple of (STATUS, MESSAGE);  If the call succeeded, STATUS is true. Otherwise it's 
      false.


=cut

sub revoke_right {

    my $self = shift;
    my %args = (
        Right  => undef,
        Object => undef,
        @_
    );

#if we haven't specified any sort of right, we're talking about a global right
    if (   !defined $args{'Object'}
        && !defined $args{'object_id'}
        && !defined $args{'object_type'} )
    {
        $args{'Object'} = RT->system;
    }

    #ACL check handled in ACE.pm
    my $type = $self->_get_principal_type_for_acl();

    my $ace = RT::Model::ACE->new;
    $ace->load_by_values(
        right_name     => $args{'Right'},
        Object         => $args{'Object'},
        principal_type => $type,
        principal_id   => $self->id
    );

    unless ( $ace->id ) {
        return ( 0, _("ACE not found") );
    }
    return ( $ace->delete );
}

# }}}

# {{{ sub _cleanup_invalid_delegations

=head2 sub _cleanup_invalid_delegations { InsideTransaction => undef }

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
# RT::Model::User and RT::Model::Group.

sub _cleanup_invalid_delegations {
    my $self = shift;
    unless ( $self->id ) {
        Jifty->log->warn("Principal not loaded.");
        return (undef);
    }
    return ( $self->object->_cleanup_invalid_delegations(@_) );
}

# }}}

# {{{ sub has_right

=head2 sub has_right (Right => 'right' Object => undef)


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

sub has_right {
    my $self = shift;
    my %args = (
        Right         => undef,
        Object        => undef,
        equiv_objects => undef,
        @_,
    );
    unless ( $args{'Right'} ) {
        Jifty->log->fatal("has_right called without a right");
        return (undef);
    }

    $args{'equiv_objects'} = [ @{ $args{'equiv_objects'} } ]
        if $args{'equiv_objects'};

    if ( $self->disabled ) {
        Jifty->log->error( "disabled User #"
                . $self->id
                . " failed access check for "
                . $args{'Right'} );
        return (undef);
    }

    if (   defined( $args{'Object'} )
        && UNIVERSAL::can( $args{'Object'}, 'id' )
        && $args{'Object'}->id )
    {

        push @{ $args{'equiv_objects'} }, $args{'Object'};
    } else {
        Jifty->log->fatal("has_right called with no valid object");
        return (undef);
    }

    # If this object is a ticket, we care about ticket roles and queue roles
    if ( UNIVERSAL::isa( $args{'Object'} => 'RT::Model::Ticket' ) ) {

        # this is a little bit hacky, but basically, now that we've done
        # the ticket roles magic, we load the queue object
        # and ask all the rest of our questions about the queue.
        unshift @{ $args{'equiv_objects'} },
            $args{'Object'}->acl_equivalence_objects;

    }

    unshift @{ $args{'equiv_objects'} }, RT->system
        unless $self->can('_IsOverrideGlobalACL')
            && $self->_IsOverrideGlobalACL( $args{'Object'} );

    # {{{ If we've cached a win or loss for this lookup say so

# Construct a hashkeys to cache decisions:
# 1) full_hashkey - key for any result and for full combination of uid, right and objects
# 2) short_hashkey - one key for each object to store positive results only, it applies
# only to direct group rights and partly to role rights
    my $self_id = $self->id;
    my $full_hashkey = join ";:;", $self_id, $args{'Right'};
    foreach ( @{ $args{'equiv_objects'} } ) {
        my $ref_id = _reference_id($_);
        $full_hashkey .= ";:;$ref_id";

        my $short_hashkey = join ";:;", $self_id, $args{'Right'}, $ref_id;
        my $cached_answer = $_ACL_CACHE->fetch($short_hashkey);
        return $cached_answer > 0 if defined $cached_answer;
    }

    {
        my $cached_answer = $_ACL_CACHE->fetch($full_hashkey);
        return $cached_answer > 0 if defined $cached_answer;
    }

    my ( $hitcount, $via_obj ) = $self->_has_right(%args);

    $_ACL_CACHE->set( $full_hashkey => $hitcount ? 1 : -1 );
    $_ACL_CACHE->set( "$self_id;:;$args{'Right'};:;$via_obj" => 1 )
        if $via_obj && $hitcount;

    return ($hitcount);
}

=head2 _has_right

Low level has_right implementation, use has_right method instead.

=cut

sub _has_right {
    my $self = shift;
    {
        my ( $hit, @other ) = $self->_has_group_right(@_);
        return ( $hit, @other ) if $hit;
    }
    {
        my ( $hit, @other ) = $self->_has_role_right(@_);
        return ( $hit, @other ) if $hit;
    }
    return (0);
}

# this method handles role rights partly in situations
# where user plays role X on an object and as well the right is
# assigned to this role X of the object, for example right CommentOnTicket
# is granted to Cc role of a queue and user is in cc list of the queue

sub _has_group_right {
    my $self = shift;
    my %args = (
        Right         => undef,
        equiv_objects => [],
        @_
    );

    return 1 if $self->id == RT->system_user->id;

    my $right = $args{'Right'};

    my $query
        = "SELECT ACL.id, ACL.object_type, ACL.object_id "
        . "FROM ACL, Principals, CachedGroupMembers WHERE "
        .

        # Only find superuser or rights with the name $right
        "(ACL.right_name = 'SuperUser' OR ACL.right_name = '$right') "

        # Never find disabled groups.
        . "AND Principals.id = ACL.principal_id "
        . "AND Principals.principal_type = 'Group' "
        . "AND Principals.disabled = 0 "

# See if the principal is a member of the group recursively or _is the rightholder_
# never find recursively disabled group members
# also, check to see if the right is being granted _directly_ to this principal,
#  as is the case when we want to look up group rights
        . "AND CachedGroupMembers.GroupId  = ACL.principal_id "
        . "AND CachedGroupMembers.GroupId  = Principals.id "
        . "AND CachedGroupMembers.MemberId = "
        . $self->id . " "
        . "AND CachedGroupMembers.disabled = 0 ";
    my @clauses;
    foreach my $obj ( @{ $args{'equiv_objects'} } ) {
        my $type = ref($obj) || $obj;
        my $clause = "ACL.object_type = '$type'";

        if ( ref($obj) && UNIVERSAL::can( $obj, 'id' ) && $obj->id ) {
            $clause .= " AND ACL.object_id = " . $obj->id;
        }
        push @clauses, "($clause)";
    }
    if (@clauses) {
        $query .= " AND (" . join( ' OR ', @clauses ) . ")";
    }

    $self->_handle->apply_limits( \$query, 1 );
    my ( $hit, $obj, $id ) = $self->_handle->fetch_result($query);
    return (0) unless $hit;

    $obj .= "-$id" if $id;
    return ( 1, $obj );
}

sub _has_role_right {
    my $self = shift;
    my %args = (
        Right         => undef,
        equiv_objects => [],
        @_
    );
    my $right = $args{'Right'};

    my $query
        = "SELECT ACL.id "
        . "FROM ACL, Groups, Principals, CachedGroupMembers WHERE "
        .

        # Only find superuser or rights with the name $right
        "(ACL.right_name = 'SuperUser' OR  ACL.right_name = '$right') "

        # Never find disabled things
        . "AND ( Principals.disabled = 0 OR Principals.disabled IS NULL) "
        . "AND (CachedGroupMembers.disabled = 0 OR CachedGroupMembers.disabled IS NULL )"

        # We always grant rights to Groups
        . "AND Principals.id = Groups.id "
        . "AND Principals.principal_type = 'Group' "

# See if the principal is a member of the group recursively or _is the rightholder_
# never find recursively disabled group members
# also, check to see if the right is being granted _directly_ to this principal,
#  as is the case when we want to look up group rights
        . "AND Principals.id = CachedGroupMembers.GroupId "
        . "AND CachedGroupMembers.MemberId = "
        . $self->id . " "
        . "AND ACL.principal_type = Groups.type ";

    my (@object_clauses);
    foreach my $obj ( @{ $args{'equiv_objects'} } ) {
        my $type = ref($obj) ? ref($obj) : $obj;
        my $id;
        $id = $obj->id
            if ref($obj) && UNIVERSAL::can( $obj, 'id' ) && $obj->id;

        my $object_clause = "ACL.object_type = '$type'";
        $object_clause .= " AND ACL.object_id = $id" if $id;
        push @object_clauses, "($object_clause)";
    }

    # find ACLs that are related to our objects only
    $query .= " AND (" . join( ' OR ', @object_clauses ) . ")";

    # because of mysql bug in versions up to 5.0.45 we do one query per object
    # each query should be faster on any DB as it uses indexes more effective
    foreach my $obj ( @{ $args{'equiv_objects'} } ) {
        my $type = ref($obj) ? ref($obj) : $obj;
        my $id;
        $id = $obj->id
            if ref($obj) && UNIVERSAL::can( $obj, 'id' ) && $obj->id;

        my $tmp = $query;
        $tmp .= " AND Groups.domain = '$type-Role'";

        # XXX: Groups.instance is VARCHAR in DB, we should quote value
        # if we want mysql 4.0 use indexes here. we MUST convert that
        # field to integer and drop this quotes.
        $tmp .= " AND Groups.instance = '$id'" if $id;

        $self->_handle->apply_limits( \$tmp, 1 );
        my ($hit) = $self->_handle->fetch_result($tmp);
        return (1) if $hit;
    }
    return 0;
}

# }}}

# }}}

# {{{ ACL caching

# {{{ invalidate_acl_cache

=head2 invalidate_acl_cache

Cleans out and reinitializes the user rights cache

=cut

sub invalidate_acl_cache {
    $_ACL_CACHE = Cache::Simple::TimedExpiry->new();
    my $lifetime;
    $lifetime = $RT::Config->get('ACLCacheLifetime') if $RT::Config;
    $_ACL_CACHE->expire_after( $lifetime || 60 );
}

# }}}

# }}}

# {{{ _get_principal_type_for_acl

=head2 _get_principal_type_for_acl

Gets the principal type. if it's a user, it's a user. if it's a role group and it has a Type, 
return that. if it has no type, return group.

=cut

sub _get_principal_type_for_acl {
    my $self = shift;
    my $type;
    if (   $self->principal_type eq 'Group'
        && $self->object->domain =~ /Role$/ )
    {
        $type = $self->object->type;
    } else {
        $type = $self->principal_type;
    }

    return ($type);
}

# }}}

# {{{ _reference_id

=head2 _reference_id

Returns a list uniquely representing an object or normal scalar.

For scalars, its string value is returned; for objects that has an
id() method, its class name and id are returned as a string separated by a "-".

=cut

sub _reference_id {
    my $scalar = shift;

    # just return the value for non-objects
    return $scalar unless UNIVERSAL::can( $scalar, 'id' );

    return ref($scalar) unless $scalar->id;

    # an object -- return the class and id
    return ( ref($scalar) . "-" . $scalar->id );
}

# }}}

1;

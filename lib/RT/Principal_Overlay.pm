# {{{ BEGIN BPS TAGGED BLOCK
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2004 Best Practical Solutions, LLC 
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
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
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
# }}} END BPS TAGGED BLOCK
use strict;

no warnings qw(redefine);
use vars qw(%_ACL_KEY_CACHE);

use RT::Group;
use RT::User;

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

=cut

sub GrantRight {
    my $self = shift;
    my %args = ( Right => undef,
                Object => undef,
                @_);


    #if we haven't specified any sort of right, we're talking about a global right
    if (!defined $args{'Object'} && !defined $args{'ObjectId'} && !defined $args{'ObjectType'}) {
        $args{'Object'} = $RT::System;
    }

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
    my %args = ( Right      => undef,
                 Object     => undef,
                 EquivObjects    => undef,
                 @_ );

    if ( $self->Disabled ) {
        $RT::Logger->err( "Disabled User:  " . $self->id . " failed access check for " . $args{'Right'} );
        return (undef);
    }

    if ( !defined $args{'Right'} ) {
        require Carp;
        $RT::Logger->debug( Carp::cluck("HasRight called without a right") );
        return (undef);
    }

    if ( defined( $args{'Object'} )) {
        return (undef) unless (UNIVERSAL::can( $args{'Object'}, 'id' ) );
        push(@{$args{'EquivObjects'}}, $args{Object});
    }
    elsif ( $args{'ObjectId'} && $args{'ObjectType'} ) {
        $RT::Logger->crit(Carp::cluck("API not supprted"));
    }
    else {
        $RT::Logger->crit("$self HasRight called with no valid object");
        return (undef);
    }

    # If this object is a ticket, we care about ticket roles and queue roles
    if ( (ref($args{'Object'}) eq 'RT::Ticket') && $args{'Object'}->Id) {
        # this is a little bit hacky, but basically, now that we've done the ticket roles magic, we load the queue object
        # and ask all the rest of our questions about the queue.
        push (@{$args{'EquivObjects'}}, $args{'Object'}->QueueObj);

    }


    # {{{ If we've cached a win or loss for this lookup say so

    # {{{ Construct a hashkey to cache decisions in
    my $hashkey = do {
	no warnings 'uninitialized';
        
	# We don't worry about the hash ordering, as this is only
	# temporarily used; also if the key changes it would be
	# invalidated anyway.
        join (
            ";:;", $self->Id, map {
                $_,                              # the key of each arguments
                ($_ eq 'EquivObjects')           # for object arrayref...
		    ? map(_ReferenceId($_), @{$args{$_}}) # calculate each
                    : _ReferenceId( $args{$_} ) # otherwise just the value
            } keys %args
        );
    };
    # }}}

    #Anything older than 60 seconds needs to be rechecked
    my $cache_timeout = ( time - 60 );

    # {{{ if we've cached a positive result for this query, return 1
    if (    ( defined $self->_ACLCache->{"$hashkey"} )
         && ( $self->_ACLCache->{"$hashkey"}{'val'} == 1 )
         && ( defined $self->_ACLCache->{"$hashkey"}{'set'} )
         && ( $self->_ACLCache->{"$hashkey"}{'set'} > $cache_timeout ) ) {

        #$RT::Logger->debug("Cached ACL win for ".  $args{'Right'}.$args{'Scope'}.  $args{'AppliesTo'}."\n");	    
        return ( 1);
    }
    # }}}

    #  {{{ if we've cached a negative result for this query return undef
    elsif (    ( defined $self->_ACLCache->{"$hashkey"} )
            && ( $self->_ACLCache->{"$hashkey"}{'val'} == -1 )
            && ( defined $self->_ACLCache->{"$hashkey"}{'set'} )
            && ( $self->_ACLCache->{"$hashkey"}{'set'} > $cache_timeout ) ) {

        #$RT::Logger->debug("Cached ACL loss decision for ".  $args{'Right'}.$args{'Scope'}.  $args{'AppliesTo'}."\n");	    

        return (undef);
    }
    # }}}

    # }}}



    #  {{{ Out of date docs
    
    #   We want to grant the right if:


    #    # The user has the right as a member of a system-internal or 
    #    # user-defined group
    #
    #    Find all records from the ACL where they're granted to a group 
    #    of type "UserDefined" or "System"
    #    for the object "System or the object "Queue N" and the group we're looking
    #    at has the recursive member $self->Id
    #
    #    # The user has the right based on a role
    #
    #    Find all the records from ACL where they're granted to the role "foo"
    #    for the object "System" or the object "Queue N" and the group we're looking
    #   at is of domain  ("RT::Queue-Role" and applies to the right queue)
    #                             or ("RT::Ticket-Role" and applies to the right ticket)
    #    and the type is the same as the type of the ACL and the group has
    #    the recursive member $self->Id
    #

    # }}}

    my ( $or_look_at_object_rights, $or_check_roles );
    my $right = $args{'Right'};

    # {{{ Construct Right Match

    # If an object is defined, we want to look at rights for that object
   
    my @look_at_objects;
    push (@look_at_objects, "ACL.ObjectType = 'RT::System'")
        unless $self->can('_IsOverrideGlobalACL') and $self->_IsOverrideGlobalACL($args{Object});



    foreach my $obj (@{$args{'EquivObjects'}}) {
            next unless (UNIVERSAL::can($obj, 'id'));
            my $type = ref($obj);
            my $id = $obj->id;

            unless ($id) {
                use Carp;
		Carp::cluck("Trying to check $type rights for an unspecified $type");
                $RT::Logger->crit("Trying to check $type rights for an unspecified $type");
            }
            push @look_at_objects, "(ACL.ObjectType = '$type' AND ACL.ObjectId = '$id')"; 
            }

     
    # }}}

    # {{{ Build that honkin-big SQL query

    

    my $query_base = "SELECT ACL.id from ACL, Groups, Principals, CachedGroupMembers WHERE  ".
    # Only find superuser or rights with the name $right
   "(ACL.RightName = 'SuperUser' OR  ACL.RightName = '$right') ".
   # Never find disabled groups.
   "AND Principals.Disabled = 0 " .
   "AND CachedGroupMembers.Disabled = 0  ".
    "AND Principals.id = Groups.id " .  # We always grant rights to Groups

    # See if the principal is a member of the group recursively or _is the rightholder_
    # never find recursively disabled group members
    # also, check to see if the right is being granted _directly_ to this principal,
    #  as is the case when we want to look up group rights
    "AND  Principals.id = CachedGroupMembers.GroupId AND CachedGroupMembers.MemberId = '" . $self->Id . "' ".

    # Make sure the rights apply to the entire system or to the object in question
    "AND ( ".join(' OR ', @look_at_objects).") ";



    # The groups query does the query based on group membership and individual user rights

	my $groups_query = $query_base . 

    # limit the result set to groups of types ACLEquivalence (user)  UserDefined, SystemInternal and Personal
    "AND ( (  ACL.PrincipalId = Principals.id AND ACL.PrincipalType = 'Group' AND ".
        "(Groups.Domain = 'SystemInternal' OR Groups.Domain = 'UserDefined' OR Groups.Domain = 'ACLEquivalence' OR Groups.Domain = 'Personal'))".

        " ) ";
        $self->_Handle->ApplyLimits(\$groups_query, 1); #only return one result
        
    my @roles;
    foreach my $object (@{$args{'EquivObjects'}}) { 
          push (@roles, $self->_RolesForObject(ref($object), $object->id));
    }

    # The roles query does the query based on roles
    my $roles_query;
    if (@roles) {
	 $roles_query = $query_base . "AND ".
            " ( (".join (' OR ', @roles)." ) ".  
        " AND Groups.Type = ACL.PrincipalType AND Groups.Id = Principals.id AND Principals.PrincipalType = 'Group') "; 
        $self->_Handle->ApplyLimits(\$roles_query, 1); #only return one result

   }



    # }}}

    # {{{ Actually check the ACL by performing an SQL query
    #   $RT::Logger->debug("Now Trying $groups_query");	
    my $hitcount = $self->_Handle->FetchResult($groups_query);

    # }}}
    
    # {{{ if there's a match, the right is granted 
    if ($hitcount) {

        # Cache a positive hit.
        $self->_ACLCache->{"$hashkey"}{'set'} = time;
        $self->_ACLCache->{"$hashkey"}{'val'} = 1;
        return (1);
    }
    # }}}
    # {{{ If there's no match on groups, try it on roles
    else {   

    	$hitcount = $self->_Handle->FetchResult($roles_query);

        if ($hitcount) {

            # Cache a positive hit.
            $self->_ACLCache->{"$hashkey"}{'set'} = time;
            $self->_ACLCache->{"$hashkey"}{'val'} = 1;
            return (1);
	    }

        else {
            # cache a negative hit
            $self->_ACLCache->{"$hashkey"}{'set'} = time;
            $self->_ACLCache->{"$hashkey"}{'val'} = -1;

            return (undef);
	    }
    }
    # }}}
}

# }}}

# {{{ _RolesForObject



=head2 _RolesForObject( $object_type, $object_id)

Returns an SQL clause finding role groups for Objects

=cut


sub _RolesForObject {
    my $self = shift;
    my $type = shift;
    my $id = shift;

    unless ($id) {
	$id = '0';
   }

   # This should never be true.
   unless ($id =~ /^\d+$/) {
	$RT::Logger->crit("RT::Prinicipal::_RolesForObject called with type $type and a non-integer id: '$id'");
	$id = "'$id'";
   }

    my $clause = "(Groups.Domain = '".$type."-Role' AND Groups.Instance = $id) ";

    return($clause);
}

# }}}

# }}}

# {{{ ACL caching

# {{{ _ACLCache

=head2 _ACLCache

# Function: _ACLCache
# Type    : private instance
# Args    : none
# Lvalue  : hash: ACLCache
# Desc    : Returns a reference to the Key cache hash

=cut

sub _ACLCache {
    return(\%_ACL_KEY_CACHE);
}

# }}}

# {{{ _InvalidateACLCache

=head2 _InvalidateACLCache

Cleans out and reinitializes the user rights key cache

=cut

sub _InvalidateACLCache {
    %_ACL_KEY_CACHE = ();
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

    # an object -- return the class and id
    return(ref($scalar)."-". $scalar->id);
}

# }}}

1;

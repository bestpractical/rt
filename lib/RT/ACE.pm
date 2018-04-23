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

=head1 SYNOPSIS

  use RT::ACE;
  my $ace = RT::ACE->new($CurrentUser);


=head1 DESCRIPTION



=head1 METHODS


=cut


package RT::ACE;
use base 'RT::Record';

sub Table {'ACL'}


use strict;
use warnings;

require RT::Principals;
require RT::Queues;
require RT::Groups;

our %RIGHTS;

my (@_ACL_CACHE_HANDLERS);



=head1 Rights

# Queue rights are the sort of queue rights that can only be granted
# to real people or groups

=cut

=head2 LoadByValues PARAMHASH

Load an ACE by specifying a paramhash with the following fields:

              PrincipalId => undef,
              PrincipalType => undef,
              RightName => undef,

        And either:

              Object => undef,

            OR

              ObjectType => undef,
              ObjectId => undef

=cut

sub LoadByValues {
    my $self = shift;
    my %args = ( PrincipalId   => undef,
                 PrincipalType => undef,
                 RightName     => undef,
                 Object    => undef,
                 ObjectId    => undef,
                 ObjectType    => undef,
                 @_ );

    if ( $args{'RightName'} ) {
        my $canonic_name = $self->CanonicalizeRightName( $args{'RightName'} );
        unless ( $canonic_name ) {
            return wantarray ? ( 0, $self->loc("Invalid right. Couldn't canonicalize right '[_1]'", $args{'RightName'}) ) : 0;
        }
        $args{'RightName'} = $canonic_name;
    }

    my $princ_obj;
    ( $princ_obj, $args{'PrincipalType'} ) =
      $self->_CanonicalizePrincipal( $args{'PrincipalId'},
                                     $args{'PrincipalType'} );

    unless ( $princ_obj->id ) {
        return wantarray ? ( 0,
                 $self->loc( 'Principal [_1] not found.', $args{'PrincipalId'} )
        ) : 0;
    }

    my ($object, $object_type, $object_id) = $self->_ParseObjectArg( %args );
    unless( $object ) {
        return wantarray ? ( 0, $self->loc("System error. Right not granted.")) : 0;
    }

    $self->LoadByCols( PrincipalId   => $princ_obj->Id,
                       PrincipalType => $args{'PrincipalType'},
                       RightName     => $args{'RightName'},
                       ObjectType    => $object_type,
                       ObjectId      => $object_id);

    #If we couldn't load it.
    unless ( $self->Id ) {
        return wantarray ? ( 0, $self->loc("ACE not found") ) : 0;
    }

    # if we could
    return wantarray ? ( $self->Id, $self->loc("Right Loaded") ) : $self->Id;

}



=head2 Create <PARAMS>

PARAMS is a parameter hash with the following elements:

   PrincipalId => The id of an RT::Principal object
   PrincipalType => "User" "Group" or any Role type
   RightName => the name of a right. in any case


    Either:

   Object => An object to create rights for. ususally, an RT::Queue or RT::Group
             This should always be a DBIx::SearchBuilder::Record subclass

        OR

   ObjectType => the type of the object in question (ref ($object))
   ObjectId => the id of the object in question $object->Id



   Returns a tuple of (STATUS, MESSAGE);  If the call succeeded, STATUS is true. Otherwise it's false.



=cut

sub Create {
    my $self = shift;
    my %args = (
        PrincipalId   => undef,
        PrincipalType => undef,
        RightName     => undef,
        Object        => undef,
        @_
    );

    unless ( $args{'RightName'} ) {
        return ( 0, $self->loc('No right specified') );
    }

    #if we haven't specified any sort of right, we're talking about a global right
    if (!defined $args{'Object'} && !defined $args{'ObjectId'} && !defined $args{'ObjectType'}) {
        $args{'Object'} = $RT::System;
    }
    ($args{'Object'}, $args{'ObjectType'}, $args{'ObjectId'}) = $self->_ParseObjectArg( %args );
    unless( $args{'Object'} ) {
        return ( 0, $self->loc("System error. Right not granted.") );
    }

    # Validate the principal
    my $princ_obj;
    ( $princ_obj, $args{'PrincipalType'} ) =
      $self->_CanonicalizePrincipal( $args{'PrincipalId'},
                                     $args{'PrincipalType'} );

    unless ( $princ_obj->id ) {
        return ( 0,
                 $self->loc( 'Principal [_1] not found.', $args{'PrincipalId'} )
        );
    }

    # }}}

    # Check the ACL

    if (ref( $args{'Object'}) eq 'RT::Group' ) {
        unless ( $self->CurrentUser->HasRight( Object => $args{'Object'},
                                                  Right => 'AdminGroup' )
          ) {
            return ( 0, $self->loc('Permission Denied') );
        }
    }

    else {
        unless ( $self->CurrentUser->HasRight( Object => $args{'Object'}, Right => 'ModifyACL' )) {
            return ( 0, $self->loc('Permission Denied') );
        }
    }
    # }}}

    # Canonicalize and check the right name
    my $canonic_name = $self->CanonicalizeRightName( $args{'RightName'} );
    unless ( $canonic_name ) {
        return ( 0, $self->loc("Invalid right. Couldn't canonicalize right '[_1]'", $args{'RightName'}) );
    }
    $args{'RightName'} = $canonic_name;

    #check if it's a valid RightName
    if ( $args{'Object'}->can('AvailableRights') ) {
        my $available = $args{'Object'}->AvailableRights($princ_obj);
        unless ( grep $_ eq $args{'RightName'}, map $self->CanonicalizeRightName( $_ ), keys %$available ) {
            $RT::Logger->warning(
                "Couldn't validate right name '$args{'RightName'}'"
                ." for object of ". ref( $args{'Object'} ) ." class"
            );
            return ( 0, $self->loc('Invalid right') );
        }
    }
    # }}}

    # Make sure the right doesn't already exist.
    $self->LoadByCols( PrincipalId   => $princ_obj->id,
                       PrincipalType => $args{'PrincipalType'},
                       RightName     => $args{'RightName'},
                       ObjectType    => $args{'ObjectType'},
                       ObjectId      => $args{'ObjectId'},
                   );
    if ( $self->Id ) {
        return ( 0, $self->loc('[_1] already has the right [_2] on [_3] [_4]',
                    $princ_obj->DisplayName, $args{'RightName'}, $args{'ObjectType'},  $args{'ObjectId'}) );
    }

    my $id = $self->SUPER::Create( PrincipalId   => $princ_obj->id,
                                   PrincipalType => $args{'PrincipalType'},
                                   RightName     => $args{'RightName'},
                                   ObjectType    => ref( $args{'Object'} ),
                                   ObjectId      => $args{'Object'}->id,
                               );

    if ( $id ) {
        RT::ACE->InvalidateCaches(
            Action      => "Grant",
            RightName   => $self->RightName,
            ACE         => $self,
        );
        return ( $id, $self->loc("Granted right '[_1]' to [_2].", $self->RightName, $princ_obj->DisplayName));
    }
    else {
        return ( 0, $self->loc('System error. Right not granted.') );
    }
}



=head2 Delete { InsideTransaction => undef}

Delete this object. This method should ONLY ever be called from RT::User or RT::Group (or from itself)
If this is being called from within a transaction, specify a true value for the parameter InsideTransaction.
Really, DBIx::SearchBuilder should use and/or fake subtransactions

This routine will also recurse and delete any delegations of this right

=cut

sub Delete {
    my $self = shift;

    unless ( $self->Id ) {
        return ( 0, $self->loc('Right not loaded.') );
    }

    # A user can delete an ACE if the current user has the right to modify it and it's not a delegated ACE
    # or if it's a delegated ACE and it was delegated by the current user
    unless ($self->CurrentUser->HasRight(Right => 'ModifyACL', Object => $self->Object)) {
        return ( 0, $self->loc('Permission Denied') );
    }
    $self->_Delete(@_);
}

# Helper for Delete with no ACL check
sub _Delete {
    my $self = shift;
    my %args = ( InsideTransaction => undef,
                 @_ );

    my $InsideTransaction = $args{'InsideTransaction'};

    $RT::Handle->BeginTransaction() unless $InsideTransaction;

    my $right = $self->RightName;

    my ( $val, $msg ) = $self->SUPER::Delete(@_);

    if ($val) {
        RT::ACE->InvalidateCaches( Action => "Revoke", RightName => $right );
        $RT::Handle->Commit() unless $InsideTransaction;
        return ( $val, $self->loc("Revoked right '[_1]' from [_2].", $right, $self->PrincipalObj->DisplayName));
    }

    $RT::Handle->Rollback() unless $InsideTransaction;
    return ( 0, $self->loc('Right could not be revoked') );
}



=head2 _BootstrapCreate

Grant a right with no error checking and no ACL. this is _only_ for 
installation. If you use this routine without the author's explicit 
written approval, he will hunt you down and make you spend eternity
translating mozilla's code into FORTRAN or intercal.

If you think you need this routine, you've mistaken. 

=cut

sub _BootstrapCreate {
    my $self = shift;
    my %args = (@_);

    # When bootstrapping, make sure we get the _right_ users
    if ( $args{'UserId'} ) {
        my $user = RT::User->new( $self->CurrentUser );
        $user->Load( $args{'UserId'} );
        delete $args{'UserId'};
        $args{'PrincipalId'}   = $user->PrincipalId;
        $args{'PrincipalType'} = 'User';
    }

    my $id = $self->SUPER::Create(%args);

    if ( $id > 0 ) {
        return ($id);
    }
    else {
        $RT::Logger->err('System error. right not granted.');
        return (undef);
    }

}

=head2 InvalidateCaches

Calls any registered ACL cache handlers (see L</RegisterCacheHandler>).

Usually called from L</Create> and L</Delete>.

=cut

sub InvalidateCaches {
    my $class = shift;

    for my $handler (@_ACL_CACHE_HANDLERS) {
        next unless ref($handler) eq "CODE";
        $handler->(@_);
    }
}

=head2 RegisterCacheHandler

Class method.  Takes a coderef and adds it to the ACL cache handlers.  These
handlers are called by L</InvalidateCaches>, usually called itself from
L</Create> and L</Delete>.

The handlers are passed a hash which may contain any (or none) of these
optional keys:

=over

=item Action

A string indicating the action that (may have) invalidated the cache.  Expected
values are currently:

=over

=item Grant

=item Revoke

=back

However, other values may be passed in the future.

=item RightName

The (canonicalized) right being granted or revoked.

=item ACE

The L<RT::ACE> object just created.

=back

Your handler should be flexible enough to account for additional arguments
being passed in the future.

=cut

sub RegisterCacheHandler {
    push @_ACL_CACHE_HANDLERS, $_[1];
}

sub RightName {
    my $self = shift;
    my $val = $self->_Value('RightName');
    return $val unless $val;

    my $available = $self->Object->AvailableRights;
    foreach my $right ( keys %$available ) {
        return $right if $val eq $self->CanonicalizeRightName($right);
    }

    $RT::Logger->error("Invalid right. Couldn't canonicalize right '$val'");
    return $val;
}

=head2 CanonicalizeRightName <RIGHT>

Takes a queue or system right name in any case and returns it in
the correct case. If it's not found, will return undef.

=cut

sub CanonicalizeRightName {
    my $self = shift;
    my $name = shift;
    for my $class (sort keys %RIGHTS) {
        return $RIGHTS{$class}{ lc $name }{Name}
            if $RIGHTS{$class}{ lc $name };
    }
    return undef;
}



=head2 Object

If the object this ACE applies to is a queue, returns the queue object. 
If the object this ACE applies to is a group, returns the group object. 
If it's the system object, returns undef. 

If the user has no rights, returns undef.

=cut




sub Object {
    my $self = shift;

    my $appliesto_obj;

    if ($self->__Value('ObjectType') && $self->__Value('ObjectType')->DOES('RT::Record::Role::Rights') ) {
        $appliesto_obj =  $self->__Value('ObjectType')->new($self->CurrentUser);
        unless (ref( $appliesto_obj) eq $self->__Value('ObjectType')) {
            return undef;
        }
        $appliesto_obj->Load( $self->__Value('ObjectId') );
        return ($appliesto_obj);
     }
    else {
        $RT::Logger->warning( "$self -> Object called for an object "
                              . "of an unknown type:"
                              . $self->__Value('ObjectType') );
        return (undef);
    }
}



=head2 PrincipalObj

Returns the RT::Principal object for this ACE. 

=cut

sub PrincipalObj {
    my $self = shift;

    my $princ_obj = RT::Principal->new( $self->CurrentUser );
    $princ_obj->Load( $self->__Value('PrincipalId') );

    unless ( $princ_obj->Id ) {
        $RT::Logger->err(
                   "ACE " . $self->Id . " couldn't load its principal object" );
    }
    return ($princ_obj);

}




sub _Set {
    my $self = shift;
    return ( 0, $self->loc("ACEs can only be created and deleted.") );
}



sub _Value {
    my $self = shift;

    if ( $self->PrincipalObj->IsGroup
            && $self->PrincipalObj->Object->HasMemberRecursively(
                                                $self->CurrentUser->PrincipalObj
            )
      ) {
        return ( $self->__Value(@_) );
    }
    elsif ( $self->CurrentUser->HasRight(Right => 'ShowACL', Object => $self->Object) ) {
        return ( $self->__Value(@_) );
    }
    else {
        return undef;
    }
}





=head2 _CanonicalizePrincipal (PrincipalId, PrincipalType)

Takes a principal id and a principal type.

If the principal is a user, resolves it to the proper acl equivalence group.
Returns a tuple of  (RT::Principal, PrincipalType)  for the principal we really want to work with

=cut

sub _CanonicalizePrincipal {
    my $self       = shift;
    my $princ_id   = shift;
    my $princ_type = shift || '';

    my $princ_obj = RT::Principal->new(RT->SystemUser);
    $princ_obj->Load($princ_id);

    unless ( $princ_obj->Id ) {
        use Carp;
        $RT::Logger->crit(Carp::longmess);
        $RT::Logger->crit("Can't load a principal for id $princ_id");
        return ( $princ_obj, undef );
    }

    # Rights never get granted to users. they get granted to their 
    # ACL equivalence groups
    if ( $princ_type eq 'User' ) {
        my $equiv_group = RT::Group->new( $self->CurrentUser );
        $equiv_group->LoadACLEquivalenceGroup($princ_obj);
        unless ( $equiv_group->Id ) {
            $RT::Logger->crit( "No ACL equiv group for princ " . $princ_obj->id );
            return ( RT::Principal->new(RT->SystemUser), undef );
        }
        $princ_obj  = $equiv_group->PrincipalObj();
        $princ_type = 'Group';

    }
    return ( $princ_obj, $princ_type );
}

sub _ParseObjectArg {
    my $self = shift;
    my %args = ( Object    => undef,
                 ObjectId    => undef,
                 ObjectType    => undef,
                 @_ );

    if( $args{'Object'} && ($args{'ObjectId'} || $args{'ObjectType'}) ) {
        $RT::Logger->crit( "Method called with an ObjectType or an ObjectId and Object args" );
        return ();
    } elsif( $args{'Object'} && ref($args{'Object'}) &&  !$args{'Object'}->can('id') ) {
        $RT::Logger->crit( "Method called called Object that has no id method" );
        return ();
    } elsif( $args{'Object'} ) {
        my $obj = $args{'Object'};
        return ($obj, ref $obj, $obj->id);
    } elsif ( $args{'ObjectType'} ) {
        my $obj =  $args{'ObjectType'}->new( $self->CurrentUser );
        $obj->Load( $args{'ObjectId'} );
        return ($obj, ref $obj, $obj->id);
    } else {
        $RT::Logger->crit( "Method called with wrong args" );
        return ();
    }
}


# }}}



=head2 id

Returns the current value of id.
(In the database, id is stored as int(11).)


=cut


=head2 PrincipalType

Returns the current value of PrincipalType.
(In the database, PrincipalType is stored as varchar(25).)



=head2 SetPrincipalType VALUE


Set PrincipalType to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, PrincipalType will be stored as a varchar(25).)


=cut


=head2 PrincipalId

Returns the current value of PrincipalId.
(In the database, PrincipalId is stored as int(11).)



=head2 SetPrincipalId VALUE


Set PrincipalId to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, PrincipalId will be stored as a int(11).)


=cut


=head2 RightName

Returns the current value of RightName.
(In the database, RightName is stored as varchar(25).)



=head2 SetRightName VALUE


Set RightName to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, RightName will be stored as a varchar(25).)


=cut


=head2 ObjectType

Returns the current value of ObjectType.
(In the database, ObjectType is stored as varchar(25).)



=head2 SetObjectType VALUE


Set ObjectType to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ObjectType will be stored as a varchar(25).)


=cut


=head2 ObjectId

Returns the current value of ObjectId.
(In the database, ObjectId is stored as int(11).)



=head2 SetObjectId VALUE


Set ObjectId to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ObjectId will be stored as a int(11).)


=cut


=head2 Creator

Returns the current value of Creator.
(In the database, Creator is stored as int(11).)

=cut


=head2 Created

Returns the current value of Created.
(In the database, Created is stored as datetime.)

=cut


=head2 LastUpdatedBy

Returns the current value of LastUpdatedBy.
(In the database, LastUpdatedBy is stored as int(11).)

=cut


=head2 LastUpdated

Returns the current value of LastUpdated.
(In the database, LastUpdated is stored as datetime.)

=cut



sub _CoreAccessible {
    {

        id =>
                {read => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        PrincipalType =>
                {read => 1, write => 1, sql_type => 12, length => 25,  is_blob => 0,  is_numeric => 0,  type => 'varchar(25)', default => ''},
        PrincipalId =>
                {read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        RightName =>
                {read => 1, write => 1, sql_type => 12, length => 25,  is_blob => 0,  is_numeric => 0,  type => 'varchar(25)', default => ''},
        ObjectType =>
                {read => 1, write => 1, sql_type => 12, length => 25,  is_blob => 0,  is_numeric => 0,  type => 'varchar(25)', default => ''},
        ObjectId =>
                {read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        Creator =>
                {read => 1, auto => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        Created =>
                {read => 1, auto => 1, sql_type => 11, length => 0,  is_blob => 0,  is_numeric => 0,  type => 'datetime', default => ''},
        LastUpdatedBy =>
                {read => 1, auto => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        LastUpdated =>
                {read => 1, auto => 1, sql_type => 11, length => 0,  is_blob => 0,  is_numeric => 0,  type => 'datetime', default => ''},

 }
};

sub FindDependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::FindDependencies($walker, $deps);

    $deps->Add( out => $self->PrincipalObj->Object );
    $deps->Add( out => $self->Object );
}

RT::Base->_ImportOverlays();

1;

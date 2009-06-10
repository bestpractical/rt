# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2009 Best Practical Solutions, LLC 
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
=head1 SYNOPSIS

  use RT::ACE;
  my $ace = new RT::ACE($CurrentUser);


=head1 DESCRIPTION



=head1 METHODS

=begin testing

ok(require RT::ACE);

=end testing

=cut


package RT::ACE;

use strict;
no warnings qw(redefine);
use RT::Principals;
use RT::Queues;
use RT::Groups;

use vars qw (
  %LOWERCASERIGHTNAMES
  %OBJECT_TYPES
  %TICKET_METAPRINCIPALS
);


# {{{ Descriptions of rights

=head1 Rights

# Queue rights are the sort of queue rights that can only be granted
# to real people or groups


=begin testing

my $Queue = RT::Queue->new($RT::SystemUser);

is ($Queue->AvailableRights->{'DeleteTicket'} , 'Delete tickets', "Found the delete ticket right");
is ($RT::System->AvailableRights->{'SuperUser'},  'Do anything and everything', "Found the superuser right");


=end testing

=cut




# }}}

# {{{ Descriptions of principals

%TICKET_METAPRINCIPALS = (
    Owner     => 'The owner of a ticket',                             # loc_pair
    Requestor => 'The requestor of a ticket',                         # loc_pair
    Cc        => 'The CC of a ticket',                                # loc_pair
    AdminCc   => 'The administrative CC of a ticket',                 # loc_pair
);

# }}}


# {{{ sub LoadByValues

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

    my $princ_obj;
    ( $princ_obj, $args{'PrincipalType'} ) =
      $self->_CanonicalizePrincipal( $args{'PrincipalId'},
                                     $args{'PrincipalType'} );

    unless ( $princ_obj->id ) {
        return ( 0,
                 $self->loc( 'Principal [_1] not found.', $args{'PrincipalId'} )
        );
    }

    my ($object, $object_type, $object_id) = $self->_ParseObjectArg( %args );
    unless( $object ) {
	return ( 0, $self->loc("System error. Right not granted.") );
    }

    $self->LoadByCols( PrincipalId   => $princ_obj->Id,
                       PrincipalType => $args{'PrincipalType'},
                       RightName     => $args{'RightName'},
                       ObjectType    => $object_type,
                       ObjectId      => $object_id);

    #If we couldn't load it.
    unless ( $self->Id ) {
        return ( 0, $self->loc("ACE not found") );
    }

    # if we could
    return ( $self->Id, $self->loc("Right Loaded") );

}

# }}}

# {{{ sub Create

=head2 Create <PARAMS>

PARAMS is a parameter hash with the following elements:

   PrincipalId => The id of an RT::Principal object
   PrincipalType => "User" "Group" or any Role type
   RightName => the name of a right. in any case
   DelegatedBy => The Principal->Id of the user delegating the right
   DelegatedFrom => The id of the ACE which this new ACE is delegated from


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
    my %args = ( PrincipalId   => undef,
                 PrincipalType => undef,
                 RightName     => undef,
                 Object        => undef,
                 @_ );
    #if we haven't specified any sort of right, we're talking about a global right
    if (!defined $args{'Object'} && !defined $args{'ObjectId'} && !defined $args{'ObjectType'}) {
        $args{'Object'} = $RT::System;
    }
    ($args{'Object'}, $args{'ObjectType'}, $args{'ObjectId'}) = $self->_ParseObjectArg( %args );
    unless( $args{'Object'} ) {
	return ( 0, $self->loc("System error. Right not granted.") );
    }

    # {{{ Validate the principal
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

    # {{{ Check the ACL

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

    # {{{ Canonicalize and check the right name
    unless ( $args{'RightName'} ) {
        return ( 0, $self->loc('Invalid right') );
    }

    $args{'RightName'} = $self->CanonicalizeRightName( $args{'RightName'} );

    #check if it's a valid RightName
    if ( ref ($args{'Object'} eq 'RT::Queue'  )) {
        unless ( exists $args{'Object'}->AvailableRights->{ $args{'RightName'} } ) {
            $RT::Logger->warning("Couldn't validate right name". $args{'RightName'});
            return ( 0, $self->loc('Invalid right') );
        }
    }
    elsif ( ref ($args{'Object'} eq 'RT::Group'  )) {
        unless ( exists $args{'Object'}->AvailableRights->{ $args{'RightName'} } ) {
            $RT::Logger->warning("Couldn't validate group right name". $args{'RightName'});
            return ( 0, $self->loc('Invalid right') );
        }
    }
    elsif ( ref ($args{'Object'} eq 'RT::System'  )) {
        my $q = RT::Queue->new($self->CurrentUser);
        my $g = RT::Group->new($self->CurrentUser);

        unless (( exists $g->AvailableRights->{ $args{'RightName'} } )
        || ( exists $g->AvailableRights->{ $args{'RightName'} } )
        || ( exists $RT::System->AvailableRights->{ $args{'RightName'} } ) ) {
            $RT::Logger->warning("Couldn't validate system right name - ". $args{'RightName'});
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
                       DelegatedBy   => 0,
                       DelegatedFrom => 0 );
    if ( $self->Id ) {
        return ( 0, $self->loc('That principal already has that right') );
    }

    my $id = $self->SUPER::Create( PrincipalId   => $princ_obj->id,
                                   PrincipalType => $args{'PrincipalType'},
                                   RightName     => $args{'RightName'},
                                   ObjectType    => ref( $args{'Object'} ),
                                   ObjectId      => $args{'Object'}->id,
                                   DelegatedBy   => 0,
                                   DelegatedFrom => 0 );

    #Clear the key cache. TODO someday we may want to just clear a little bit of the keycache space. 
    RT::Principal->InvalidateACLCache();

    if ( $id > 0 ) {
        return ( $id, $self->loc('Right Granted') );
    }
    else {
        return ( 0, $self->loc('System error. Right not granted.') );
    }
}

# }}}

# {{{ sub Delegate

=head2 Delegate <PARAMS>

This routine delegates the current ACE to a principal specified by the
B<PrincipalId>  parameter.

Returns an error if the current user doesn't have the right to be delegated
or doesn't have the right to delegate rights.

Always returns a tuple of (ReturnValue, Message)

=begin testing

use_ok(RT::User);
my $user_a = RT::User->new($RT::SystemUser);
$user_a->Create( Name => 'DelegationA', Privileged => 1);
ok ($user_a->Id, "Created delegation user a");

my $user_b = RT::User->new($RT::SystemUser);
$user_b->Create( Name => 'DelegationB', Privileged => 1);
ok ($user_b->Id, "Created delegation user b");


use_ok(RT::Queue);
my $q = RT::Queue->new($RT::SystemUser);
$q->Create(Name =>'DelegationTest');
ok ($q->Id, "Created a delegation test queue");


#------ First, we test whether a user can delegate a right that's been granted to him personally 
my ($val, $msg) = $user_a->PrincipalObj->GrantRight(Object => $RT::System, Right => 'AdminOwnPersonalGroups');
ok($val, $msg);

($val, $msg) = $user_a->PrincipalObj->GrantRight(Object =>$q, Right => 'OwnTicket');
ok($val, $msg);

ok($user_a->HasRight( Object => $RT::System, Right => 'AdminOwnPersonalGroups')    ,"user a has the right 'AdminOwnPersonalGroups' directly");

my $a_delegates = RT::Group->new($user_a);
$a_delegates->CreatePersonalGroup(Name => 'Delegates');
ok( $a_delegates->Id   ,"user a creates a personal group 'Delegates'");
ok( $a_delegates->AddMember($user_b->PrincipalId)   ,"user a adds user b to personal group 'delegates'");

ok( !$user_b->HasRight(Right => 'OwnTicket', Object => $q)    ,"user b does not have the right to OwnTicket' in queue 'DelegationTest'");
ok(  $user_a->HasRight(Right => 'OwnTicket', Object => $q)  ,"user a has the right to 'OwnTicket' in queue 'DelegationTest'");
ok(!$user_a->HasRight( Object => $RT::System, Right => 'DelegateRights')    ,"user a does not have the right 'delegate rights'");


my $own_ticket_ace = RT::ACE->new($user_a);
my $user_a_equiv_group = RT::Group->new($user_a);
$user_a_equiv_group->LoadACLEquivalenceGroup($user_a->PrincipalObj);
ok ($user_a_equiv_group->Id, "Loaded the user A acl equivalence group");
my $user_b_equiv_group = RT::Group->new($user_b);
$user_b_equiv_group->LoadACLEquivalenceGroup($user_b->PrincipalObj);
ok ($user_b_equiv_group->Id, "Loaded the user B acl equivalence group");
$own_ticket_ace->LoadByValues( PrincipalType => 'Group', PrincipalId => $user_a_equiv_group->PrincipalId, Object=>$q, RightName => 'OwnTicket');

ok ($own_ticket_ace->Id, "Found the ACE we want to test with for now");


($val, $msg) = $own_ticket_ace->Delegate(PrincipalId => $a_delegates->PrincipalId)  ;
ok( !$val ,"user a tries and fails to delegate the right 'ownticket' in queue 'DelegationTest' to personal group 'delegates' - $msg");


($val, $msg) = $user_a->PrincipalObj->GrantRight( Right => 'DelegateRights');
ok($val, "user a is granted the right to 'delegate rights' - $msg");

ok($user_a->HasRight( Object => $RT::System, Right => 'DelegateRights')    ,"user a has the right 'AdminOwnPersonalGroups' directly");

($val, $msg) = $own_ticket_ace->Delegate(PrincipalId => $a_delegates->PrincipalId) ;

ok( $val    ,"user a tries and succeeds to delegate the right 'ownticket' in queue 'DelegationTest' to personal group 'delegates' - $msg");
ok(  $user_b->HasRight(Right => 'OwnTicket', Object => $q)  ,"user b has the right to own tickets in queue 'DelegationTest'");
my $delegated_ace = RT::ACE->new($user_a);
$delegated_ace->LoadByValues ( Object => $q, RightName => 'OwnTicket', PrincipalType => 'Group',
PrincipalId => $a_delegates->PrincipalId, DelegatedBy => $user_a->PrincipalId, DelegatedFrom => $own_ticket_ace->Id);
ok ($delegated_ace->Id, "Found the delegated ACE");

ok(    $a_delegates->DeleteMember($user_b->PrincipalId)  ,"user a removes b from pg 'delegates'");
ok(  !$user_b->HasRight(Right => 'OwnTicket', Object => $q)  ,"user b does not have the right to own tickets in queue 'DelegationTest'");
ok(  $a_delegates->AddMember($user_b->PrincipalId)    ,"user a adds user b to personal group 'delegates'");
ok(   $user_b->HasRight(Right => 'OwnTicket', Object=> $q) ,"user b has the right to own tickets in queue 'DelegationTest'");
ok(   $delegated_ace->Delete ,"user a revokes pg 'delegates' right to 'OwnTickets' in queue 'DelegationTest'");
ok( ! $user_b->HasRight(Right => 'OwnTicket', Object => $q)   ,"user b does not have the right to own tickets in queue 'DelegationTest'");

($val, $msg) = $own_ticket_ace->Delegate(PrincipalId => $a_delegates->PrincipalId)  ;
ok(  $val  ,"user a delegates pg 'delegates' right to 'OwnTickets' in queue 'DelegationTest' - $msg");

ok( $user_a->HasRight(Right => 'OwnTicket', Object => $q)    ,"user a does not have the right to own tickets in queue 'DelegationTest'");

($val, $msg) = $user_a->PrincipalObj->RevokeRight(Object=>$q, Right => 'OwnTicket');
ok($val, "Revoked user a's right to own tickets in queue 'DelegationTest". $msg);

ok( !$user_a->HasRight(Right => 'OwnTicket', Object => $q)    ,"user a does not have the right to own tickets in queue 'DelegationTest'");

 ok( !$user_b->HasRight(Right => 'OwnTicket', Object => $q)   ,"user b does not have the right to own tickets in queue 'DelegationTest'");

($val, $msg) = $user_a->PrincipalObj->GrantRight(Object=>$q, Right => 'OwnTicket');
ok($val, $msg);

 ok( $user_a->HasRight(Right => 'OwnTicket', Object => $q)   ,"user a has the right to own tickets in queue 'DelegationTest'");

 ok(  !$user_b->HasRight(Right => 'OwnTicket', Object => $q)  ,"user b does not have the right to own tickets in queue 'DelegationTest'");

# {{{ get back to a known clean state 
($val, $msg) = $user_a->PrincipalObj->RevokeRight( Object => $q, Right => 'OwnTicket');
ok($val, "Revoked user a's right to own tickets in queue 'DelegationTest -". $msg);
ok( !$user_a->HasRight(Right => 'OwnTicket', Object => $q)    ,"make sure that user a can't own tickets in queue 'DelegationTest'");
# }}}


# {{{ Set up some groups and membership
my $del1 = RT::Group->new($RT::SystemUser);
($val, $msg) = $del1->CreateUserDefinedGroup(Name => 'Del1');
ok( $val   ,"create a group del1 - $msg");

my $del2 = RT::Group->new($RT::SystemUser);
($val, $msg) = $del2->CreateUserDefinedGroup(Name => 'Del2');
ok( $val   ,"create a group del2 - $msg");
($val, $msg) = $del1->AddMember($del2->PrincipalId);
ok( $val,"make del2 a member of del1 - $msg");

my $del2a = RT::Group->new($RT::SystemUser);
($val, $msg) = $del2a->CreateUserDefinedGroup(Name => 'Del2a');
ok( $val   ,"create a group del2a - $msg");
($val, $msg) = $del2->AddMember($del2a->PrincipalId);  
ok($val    ,"make del2a a member of del2 - $msg");

my $del2b = RT::Group->new($RT::SystemUser);
($val, $msg) = $del2b->CreateUserDefinedGroup(Name => 'Del2b');
ok( $val   ,"create a group del2b - $msg");
($val, $msg) = $del2->AddMember($del2b->PrincipalId);  
ok($val    ,"make del2b a member of del2 - $msg");

($val, $msg) = $del2->AddMember($user_a->PrincipalId) ;
ok($val,"make 'user a' a member of del2 - $msg");

($val, $msg) = $del2b->AddMember($user_a->PrincipalId) ;
ok($val,"make 'user a' a member of del2b - $msg");

# }}}

# {{{ Grant a right to a group and make sure that a submember can delegate the right and that it does not get yanked
# when a user is removed as a submember, when they're a sumember through another path 
($val, $msg) = $del1->PrincipalObj->GrantRight( Object=> $q, Right => 'OwnTicket');
ok( $val   ,"grant del1  the right to 'OwnTicket' in queue 'DelegationTest' - $msg");

ok(  $user_a->HasRight(Right => 'OwnTicket', Object => $q)  ,"make sure that user a can own tickets in queue 'DelegationTest'");

my $group_ace= RT::ACE->new($user_a);
$group_ace->LoadByValues( PrincipalType => 'Group', PrincipalId => $del1->PrincipalId, Object => $q, RightName => 'OwnTicket');

ok ($group_ace->Id, "Found the ACE we want to test with for now");

($val, $msg) = $group_ace->Delegate(PrincipalId => $a_delegates->PrincipalId);

ok( $val   ,"user a tries and succeeds to delegate the right 'ownticket' in queue 'DelegationTest' to personal group 'delegates' - $msg");
ok(  $user_b->HasRight(Right => 'OwnTicket', Object => $q)  ,"user b has the right to own tickets in queue 'DelegationTest'");


($val, $msg) = $del2b->DeleteMember($user_a->PrincipalId);
ok( $val   ,"remove user a from group del2b - $msg");
ok(  $user_a->HasRight(Right => 'OwnTicket', Object => $q)  ,"user a has the right to own tickets in queue 'DelegationTest'");
ok( $user_b->HasRight(Right => 'OwnTicket', Object => $q)    ,"user b has the right to own tickets in queue 'DelegationTest'");

# }}}

# {{{ When a  user is removed froom a group by the only path they're in there by, make sure the delegations go away
($val, $msg) = $del2->DeleteMember($user_a->PrincipalId);
ok( $val   ,"remove user a from group del2 - $msg");
ok(  !$user_a->HasRight(Right => 'OwnTicket', Object => $q)  ,"user a does not have the right to own tickets in queue 'DelegationTest' ");
ok(  !$user_b->HasRight(Right => 'OwnTicket', Object => $q)  ,"user b does not have the right to own tickets in queue 'DelegationTest' ");
# }}}

($val, $msg) = $del2->AddMember($user_a->PrincipalId);
ok( $val   ,"make user a a member of group del2 - $msg");

($val, $msg) = $del2->PrincipalObj->GrantRight(Object=>$q, Right => 'OwnTicket');
ok($val, "grant the right 'own tickets' in queue 'DelegationTest' to group del2 - $msg");

my $del2_right = RT::ACE->new($user_a);
$del2_right->LoadByValues( PrincipalId => $del2->PrincipalId, PrincipalType => 'Group', Object => $q, RightName => 'OwnTicket');
ok ($del2_right->Id, "Found the right");

($val, $msg) = $del2_right->Delegate(PrincipalId => $a_delegates->PrincipalId);
ok( $val   ,"user a tries and succeeds to delegate the right 'ownticket' in queue 'DelegationTest' gotten via del2 to personal group 'delegates' - $msg");

# They have it via del1 and del2
ok( $user_a->HasRight(Right => 'OwnTicket', Object => $q)   ,"user b has the right to own tickets in queue 'DelegationTest'");


($val, $msg) = $del2->PrincipalObj->RevokeRight(Object=>$q, Right => 'OwnTicket');
ok($val, "revoke the right 'own tickets' in queue 'DelegationTest' to group del2 - $msg");
ok(  $user_a->HasRight(Right => 'OwnTicket', Object => $q)  ,"user a does has the right to own tickets in queue 'DelegationTest' via del1");
ok(  !$user_b->HasRight(Right => 'OwnTicket', Object => $q)   ,"user b does not have the right to own tickets in queue 'DelegationTest'");

($val, $msg) = $del2->PrincipalObj->GrantRight(Object=>$q, Right => 'OwnTicket');
ok($val, "grant the right 'own tickets' in queue 'DelegationTest' to group del2 - $msg");


$group_ace= RT::ACE->new($user_a);
$group_ace->LoadByValues( PrincipalType => 'Group', PrincipalId => $del1->PrincipalId, Object=>$q, RightName => 'OwnTicket');

ok ($group_ace->Id, "Found the ACE we want to test with for now");

($val, $msg) = $group_ace->Delegate(PrincipalId => $a_delegates->PrincipalId);

ok( $val   ,"user a tries and succeeds to delegate the right 'ownticket' in queue 'DelegationTest' to personal group 'delegates' - $msg");

ok( $user_b->HasRight(Right => 'OwnTicket', Object => $q)    ,"user b has the right to own tickets in queue 'DelegationTest'");

($val, $msg) = $del2->DeleteMember($user_a->PrincipalId);
ok( $val   ,"remove user a from group del2 - $msg");

ok(  !$user_a->HasRight(Right => 'OwnTicket', Object => $q)  ,"user a does not have the right to own tickets in queue 'DelegationTest'");

ok(  !$user_b->HasRight(Right => 'OwnTicket', Object => $q)   ,"user b does not have the right to own tickets in queue 'DelegationTest'");



=end testing

=cut

sub Delegate {
    my $self = shift;
    my %args = ( PrincipalId => undef,
                 @_ );

    unless ( $self->Id ) {
        return ( 0, $self->loc("Right not loaded.") );
    }
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

    # {{{ Check the ACL

    # First, we check to se if the user is delegating rights and
    # they have the permission to
    unless ( $self->CurrentUser->HasRight(Right => 'DelegateRights', Object => $self->Object) ) {
        return ( 0, $self->loc("Permission Denied") );
    }

    unless ( $self->PrincipalObj->IsGroup ) {
        return ( 0, $self->loc("System Error") );
    }
    unless ( $self->PrincipalObj->Object->HasMemberRecursively(
                                                $self->CurrentUser->PrincipalObj
             )
      ) {
        return ( 0, $self->loc("Permission Denied") );
    }

    # }}}

    my $concurrency_check = RT::ACE->new($RT::SystemUser);
    $concurrency_check->Load( $self->Id );
    unless ( $concurrency_check->Id ) {
        $RT::Logger->crit(
                   "Trying to delegate a right which had already been deleted");
        return ( 0, $self->loc('Permission Denied') );
    }

    my $delegated_ace = RT::ACE->new( $self->CurrentUser );

    # Make sure the right doesn't already exist.
    $delegated_ace->LoadByCols( PrincipalId   => $princ_obj->Id,
                                PrincipalType => 'Group',
                                RightName     => $self->__Value('RightName'),
                                ObjectType    => $self->__Value('ObjectType'),
                                ObjectId      => $self->__Value('ObjectId'),
                                DelegatedBy => $self->CurrentUser->PrincipalId,
                                DelegatedFrom => $self->id );
    if ( $delegated_ace->Id ) {
        return ( 0, $self->loc('That principal already has that right') );
    }
    my $id = $delegated_ace->SUPER::Create(
        PrincipalId   => $princ_obj->Id,
        PrincipalType => 'Group',          # do we want to hardcode this?
        RightName     => $self->__Value('RightName'),
        ObjectType    => $self->__Value('ObjectType'),
        ObjectId      => $self->__Value('ObjectId'),
        DelegatedBy   => $self->CurrentUser->PrincipalId,
        DelegatedFrom => $self->id );

    #Clear the key cache. TODO someday we may want to just clear a little bit of the keycache space. 
    # TODO what about the groups key cache?
    RT::Principal->InvalidateACLCache();

    if ( $id > 0 ) {
        return ( $id, $self->loc('Right Delegated') );
    }
    else {
        return ( 0, $self->loc('System error. Right not delegated.') );
    }
}

# }}}

# {{{ sub Delete 

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
    unless (
         (    $self->CurrentUser->HasRight(Right => 'ModifyACL', Object => $self->Object)
           && $self->__Value('DelegatedBy') == 0 )
         || ( $self->__Value('DelegatedBy') == $self->CurrentUser->PrincipalId )
      ) {
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

    my $delegated_from_this = RT::ACL->new($RT::SystemUser);
    $delegated_from_this->Limit( FIELD    => 'DelegatedFrom',
                                 OPERATOR => '=',
                                 VALUE    => $self->Id );

    my $delete_succeeded = 1;
    my $submsg;
    while ( my $delegated_ace = $delegated_from_this->Next ) {
        ( $delete_succeeded, $submsg ) =
          $delegated_ace->_Delete( InsideTransaction => 1 );
        last unless ($delete_succeeded);
    }

    unless ($delete_succeeded) {
        $RT::Handle->Rollback() unless $InsideTransaction;
        return ( 0, $self->loc('Right could not be revoked') );
    }

    my ( $val, $msg ) = $self->SUPER::Delete(@_);

    # If we're revoking delegation rights (see above), we may need to
    # revoke all rights delegated by the recipient.
    if ($val and ($self->RightName() eq 'DelegateRights' or
		  $self->RightName() eq 'SuperUser')) {
	$val = $self->PrincipalObj->_CleanupInvalidDelegations( InsideTransaction => 1 );
    }

    if ($val) {
	#Clear the key cache. TODO someday we may want to just clear a little bit of the keycache space. 
	# TODO what about the groups key cache?
	RT::Principal->InvalidateACLCache();
        $RT::Handle->Commit() unless $InsideTransaction;
        return ( $val, $self->loc('Right revoked') );
    }

    $RT::Handle->Rollback() unless $InsideTransaction;
    return ( 0, $self->loc('Right could not be revoked') );
}

# }}}

# {{{ sub _BootstrapCreate 

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

# }}}

# {{{ sub CanonicalizeRightName

=head2 CanonicalizeRightName <RIGHT>

Takes a queue or system right name in any case and returns it in
the correct case. If it's not found, will return undef.

=cut

sub CanonicalizeRightName {
    my $self  = shift;
    my $right = shift;
    $right = lc $right;
    if ( exists $LOWERCASERIGHTNAMES{"$right"} ) {
        return ( $LOWERCASERIGHTNAMES{"$right"} );
    }
    else {
        return (undef);
    }
}

# }}}


# {{{ sub Object

=head2 Object

If the object this ACE applies to is a queue, returns the queue object. 
If the object this ACE applies to is a group, returns the group object. 
If it's the system object, returns undef. 

If the user has no rights, returns undef.

=cut




sub Object {
    my $self = shift;

    my $appliesto_obj;

    if ($self->__Value('ObjectType') && $OBJECT_TYPES{$self->__Value('ObjectType')} ) {
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

# }}}

# {{{ sub PrincipalObj

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

# }}}

# {{{ ACL related methods

# {{{ sub _Set

sub _Set {
    my $self = shift;
    return ( 0, $self->loc("ACEs can only be created and deleted.") );
}

# }}}

# {{{ sub _Value

sub _Value {
    my $self = shift;

    if ( $self->__Value('DelegatedBy') eq $self->CurrentUser->PrincipalId ) {
        return ( $self->__Value(@_) );
    }
    elsif ( $self->PrincipalObj->IsGroup
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

# }}}


# }}}

# {{{ _CanonicalizePrincipal 

=head2 _CanonicalizePrincipal (PrincipalId, PrincipalType)

Takes a principal id and a principal type.

If the principal is a user, resolves it to the proper acl equivalence group.
Returns a tuple of  (RT::Principal, PrincipalType)  for the principal we really want to work with

=cut

sub _CanonicalizePrincipal {
    my $self       = shift;
    my $princ_id   = shift;
    my $princ_type = shift;

    my $princ_obj = RT::Principal->new($RT::SystemUser);
    $princ_obj->Load($princ_id);

    unless ( $princ_obj->Id ) {
        use Carp;
        $RT::Logger->crit(Carp::cluck);
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
            return ( RT::Principal->new($RT::SystemUser), undef );
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
    } elsif( $args{'Object'} && !UNIVERSAL::can($args{'Object'},'id') ) {
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
1;

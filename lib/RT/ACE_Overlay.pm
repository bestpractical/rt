# BEGIN LICENSE BLOCK
# 
# Copyright (c) 1996-2002 Jesse Vincent <jesse@bestpractical.com>
# 
# (Except where explictly superceded by other copyright notices)
# 
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org
# 
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# 
# Unless otherwise specified, all modifications, corrections or
# extensions to this work which alter its source code become the
# property of Best Practical Solutions, LLC when submitted for
# inclusion in the work.
# 
# 
# END LICENSE BLOCK
=head1 SYNOPSIS

  use RT::ACE;
  my $ace = new RT::ACE($CurrentUser);


=head1 DESCRIPTION



=head1 METHODS

=begin testing

ok(require RT::ACE);

=end testing

=cut

no warnings qw(redefine);
use RT::Principals;
use RT::Queues;
use RT::Groups;

use vars qw (%SCOPES
  %QUEUERIGHTS
  %SYSTEMRIGHTS
  %GROUPRIGHTS
  %LOWERCASERIGHTNAMES
);

%SCOPES = (
	   System => 'System-level right',
	   Queue => 'Queue-level right'
	  );

# {{{ Descriptions of rights

# Queue rights are the sort of queue rights that can only be granted
# to real people or groups

# XXX TODO Can't localize these outside of having an object around.
%QUEUERIGHTS = ( 
		SeeQueue => 'Can this principal see this queue',
		AdminQueue => 'Create, delete and modify queues', 
		ShowACL => 'Display Access Control List',
		ModifyACL => 'Modify Access Control List',
		ModifyQueueWatchers => 'Modify the queue watchers',
        AdminCustomFields => 'Create, delete and modify custom fields',
        ModifyTemplate => 'Modify email templates for this queue',
		ShowTemplate => 'Display email templates for this queue',

		ModifyScrips => 'Modify Scrips for this queue',
		ShowScrips => 'Display Scrips for this queue',

		ShowTicket => 'Show ticket summaries',
		ShowTicketComments => 'Show ticket private commentary',

		Watch => 'Sign up as a ticket Requestor or ticket or queue Cc',
		WatchAsAdminCc => 'Sign up as a ticket or queue AdminCc',
		CreateTicket => 'Create tickets in this queue',
		ReplyToTicket => 'Reply to tickets',
		CommentOnTicket => 'Comment on tickets',
		OwnTicket => 'Own tickets',
		ModifyTicket => 'Modify tickets',
		DeleteTicket => 'Delete tickets'

	       );	


# System rights are rights granted to the whole system
# XXX TODO Can't localize these outside of having an object around.
%SYSTEMRIGHTS = (
        SuperUser => 'Do anything and everything',
	AdminAllPersonalGroups => "Create, delete and modify the members of any user's personal groups",
	AdminOwnPersonalGroups => 'Create, delete and modify the members of personal groups',
	    AdminUsers => 'Create, delete and modify users',
		ModifySelf => "Modify one's own RT account",
        DelegateRights => "Delegate specific rights which have been granted to you."
		);

%GROUPRIGHTS = (
       AdminGroup 	=> 'Modify group metadata. Delete group',
       AdminGroupMembership => 'Modify membership roster for this group',
       ModifyOwnMembership => 'Join or leave this group'
);

# }}}

# {{{ Descriptions of principals

%TICKET_METAPRINCIPALS = ( Owner => 'The owner of a ticket',
            			   Requestor => 'The requestor of a ticket',
		            	   Cc => 'The CC of a ticket',
			               AdminCc => 'The administrative CC of a ticket',
			 );

# }}}

# {{{ We need to build a hash of all rights, keyed by lower case names

#since you can't do case insensitive hash lookups

foreach $right (keys %QUEUERIGHTS) {
    $LOWERCASERIGHTNAMES{lc $right}=$right;
}
foreach $right (keys %SYSTEMRIGHTS) {
    $LOWERCASERIGHTNAMES{lc $right}=$right;
}

foreach $right (keys %GROUPRIGHTS) {
    $LOWERCASERIGHTNAMES{lc $right}=$right;
}
# }}}

# {{{ sub LoadByValues

=head2 LoadByValues PARAMHASH

Load an ACE by specifying a paramhash with the following fields:

              PrincipalId => undef,
              PrincipalType => undef,
	      RightName => undef,
	      ObjectType => undef,
	      ObjectId => undef,

=cut

sub LoadByValues {
  my $self = shift;
  my %args = (PrincipalId => undef,
              PrincipalType => undef,
	      RightName => undef,
	      ObjectType => undef,
	      ObjectId => undef,
	      @_);

    my $princ_obj;
    ($princ_obj, $args{'PrincipalType'}) = $self->_CanonicalizePrincipal($args{'PrincipalId'}, $args{'PrincipalType'});

    unless ($princ_obj->id) {
        return ( 0,
            $self->loc( 'Principal [_1] not found.', $args{'PrincipalId'} ) );
    }
  
  $self->LoadByCols (PrincipalId => $princ_obj->Id,
              PrincipalType => $args{'PrincipalType'},
		     RightName => $args{'RightName'},
		     ObjectType => $args{'ObjectType'},
		     ObjectId => $args{'ObjectId'}
		    );
  
  #If we couldn't load it.
  unless ($self->Id) {
      return (0, $self->loc("ACE not found"));
  }
  # if we could
  return ($self->Id, $self->loc("Right Loaded"));
  
}

# }}}

# {{{ sub Create

=head2 Create <PARAMS>

PARAMS is a parameter hash with the following elements:

   PrincipalId => The id of an RT::Principal object
   PrincipalType => "User" "Group" or any Role type
   RightName => the name of a right. in any case
   ObjectType => "System" | "Queue" | "Group"
   ObjectId => a queue id, group id or undef
   DelegatedBy => The Principal->Id of the user delegating the right
   DelegatedFrom => The id of the ACE which this new ACE is delegated from

=cut

sub Create {
    my $self = shift;
    my %args = (
        PrincipalId   => undef,
        PrincipalType => undef,
        RightName     => undef,
        ObjectType    => undef,
        ObjectId      => undef,
        @_
    );

    # {{{ Validate the principal
    my $princ_obj;
    ($princ_obj, $args{'PrincipalType'}) = $self->_CanonicalizePrincipal($args{'PrincipalId'}, $args{'PrincipalType'});

    unless ($princ_obj->id) {
        return ( 0,
            $self->loc( 'Principal [_1] not found.', $args{'PrincipalId'} ) );
    }

    # }}}

    #If it's not a scope we recognise, something scary is happening.
    unless ($args{'ObjectType'} =~ /^(?:Group|Queue|System)$/) {
        $RT::Logger->err(
            "RT::ACE->Create got an object type it didn't recognize: "
              . $args{'ObjectType'}
              . " Bailing. \n" );
        return ( 0, $self->loc("System error. Right not granted.") );
    }

    # {{{ Check the ACL


    if ( $args{'ObjectType'} eq 'System' ) {
        unless ( $self->CurrentUserHasSystemRight('ModifyACL') ) {
            return ( 0, $self->loc("Permission Denied") );
        }
    }

    elsif ( $args{'ObjectType'} eq 'Queue' ) {
        unless (
            $self->CurrentUserHasQueueRight(
                Queue => $args{'ObjectId'},
                Right => 'ModifyACL'
            )
          )
        {
            return ( 0, $self->loc('Permission Denied') );
        }
    }
    elsif ( $args{'ObjectType'} eq 'Group' ) {
        unless (
            $self->CurrentUserHasGroupRight(
                Group => $args{'ObjectId'},
                Right => 'AdminGroup'
            )
          )
        {
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
    if ( $args{'ObjectType'} eq 'Queue' ) {
        unless ( exists $QUEUERIGHTS{ $args{'RightName'} } ) {
            return ( 0, $self->loc('Invalid right') );
        }
    }
    elsif ( $args{ 'ObjectType' eq 'Group' } ) {
        unless ( exists $GROUPRIGHTS{ $args{'RightName'} } ) {
            return ( 0, $self->loc('Invalid right') );
        }
    }
    elsif ( $args{ 'ObjectType' eq 'System' } ) {
        unless ( exists $SYSTEMRIGHTS{ $args{'RightName'} } ) {
            return ( 0, $self->loc('Invalid right') );
        }
    }

    # }}}

    # Make sure the right doesn't already exist.
    $self->LoadByCols(
        PrincipalId   => $princ_obj->id,
        PrincipalType => $args{'PrincipalType'},
        RightName     => $args{'RightName'},
        ObjectType    => $args{'ObjectType'},
        ObjectId      => $args{'ObjectId'},
        DelegatedBy   => 0,
        DelegatedFrom   => 0
    );
    if ( $self->Id ) {
        return ( 0, $self->loc('That user already has that right') );
    }

    my $id = $self->SUPER::Create(
        PrincipalId   => $princ_obj->id,
        PrincipalType => $args{'PrincipalType'},
        RightName     => $args{'RightName'},
        ObjectType    => $args{'ObjectType'},
        ObjectId      => $args{'ObjectId'},
        DelegatedBy   => 0,
        DelegatedFrom   => 0
    );

    #Clear the key cache. TODO someday we may want to just clear a little bit of the keycache space. 
    # TODO what about the groups key cache?
    RT::User->_InvalidateACLCache();

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
my ($val, $msg) = $user_a->PrincipalObj->GrantRight(ObjectType => 'System', Right => 'AdminOwnPersonalGroups');
ok($val, $msg);

($val, $msg) = $user_a->PrincipalObj->GrantRight(ObjectType => 'Queue', ObjectId => $q->Id, Right => 'OwnTicket');
ok($val, $msg);

ok($user_a->HasSystemRight('AdminOwnPersonalGroups')    ,"user a has the right 'AdminOwnPersonalGroups' directly");

my $a_delegates = RT::Group->new($user_a);
$a_delegates->CreatePersonalGroup(Name => 'Delegates');
ok( $a_delegates->Id   ,"user a creates a personal group 'Delegates'");
ok( $a_delegates->AddMember($user_b->PrincipalId)   ,"user a adds user b to personal group 'delegates'");

ok( !$user_b->HasRight(Right => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)    ,"user b does not have the right to OwnTicket' in queue 'DelegationTest'");
ok(  $user_a->HasRight(Right => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)  ,"user a has the right to 'OwnTicket' in queue 'DelegationTest'");
ok(!$user_a->HasSystemRight('DelegateRights')    ,"user a does not have the right 'delegate rights'");


my $own_ticket_ace = RT::ACE->new($user_a);
my $user_a_equiv_group = RT::Group->new($user_a);
$user_a_equiv_group->LoadACLEquivalenceGroup($user_a->PrincipalObj);
ok ($user_a_equiv_group->Id, "Loaded the user A acl equivalence group");
my $user_b_equiv_group = RT::Group->new($user_b);
$user_b_equiv_group->LoadACLEquivalenceGroup($user_b->PrincipalObj);
ok ($user_b_equiv_group->Id, "Loaded the user B acl equivalence group");
$own_ticket_ace->LoadByValues( PrincipalType => 'Group', PrincipalId => $user_a_equiv_group->PrincipalId, ObjectType => 'Queue', ObjectId => $q->Id, RightName => 'OwnTicket');

ok ($own_ticket_ace->Id, "Found the ACE we want to test with for now");


($val, $msg) = $own_ticket_ace->Delegate(PrincipalId => $a_delegates->PrincipalId)  ;
ok( !$val ,"user a tries and fails to delegate the right 'ownticket' in queue 'DelegationTest' to personal group 'delegates' - $msg");


($val, $msg) = $user_a->PrincipalObj->GrantRight(ObjectType => 'System', Right => 'DelegateRights');
ok($val, "user a is granted the right to 'delegate rights' - $msg");

ok($user_a->HasSystemRight('DelegateRights')    ,"user a has the right 'AdminOwnPersonalGroups' directly");

($val, $msg) = $own_ticket_ace->Delegate(PrincipalId => $a_delegates->PrincipalId) ;

ok( $val    ,"user a tries and succeeds to delegate the right 'ownticket' in queue 'DelegationTest' to personal group 'delegates' - $msg");
ok(  $user_b->HasRight(Right => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)  ,"user b has the right to own tickets in queue 'DelegationTest'");
my $delegated_ace = RT::ACE->new($user_a);
$delegated_ace->LoadByValues ( ObjectType => 'Queue', ObjectId => $q->Id, RightName => 'OwnTicket', PrincipalType => 'Group',
PrincipalId => $a_delegates->PrincipalId, DelegatedBy => $user_a->PrincipalId, DelegatedFrom => $own_ticket_ace->Id);
ok ($delegated_ace->Id, "Found the delegated ACE");

ok(    $a_delegates->DeleteMember($user_b->PrincipalId)  ,"user a removes b from pg 'delegates'");
ok(  !$user_b->HasRight(Right => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)  ,"user b does not have the right to own tickets in queue 'DelegationTest'");
ok(  $a_delegates->AddMember($user_b->PrincipalId)    ,"user a adds user b to personal group 'delegates'");
ok(   $user_b->HasRight(Right => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id) ,"user b has the right to own tickets in queue 'DelegationTest'");
ok(   $delegated_ace->Delete ,"user a revokes pg 'delegates' right to 'OwnTickets' in queue 'DelegationTest'");
ok( ! $user_b->HasRight(Right => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)   ,"user b does not have the right to own tickets in queue 'DelegationTest'");

($val, $msg) = $own_ticket_ace->Delegate(PrincipalId => $a_delegates->PrincipalId)  ;
ok(  $val  ,"user a delegates pg 'delegates' right to 'OwnTickets' in queue 'DelegationTest' - $msg");

ok( $user_a->HasRight(Right => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)    ,"user a does not have the right to own tickets in queue 'DelegationTest'");

($val, $msg) = $user_a->PrincipalObj->RevokeRight(ObjectType => 'Queue', ObjectId => $q->Id, Right => 'OwnTicket');
ok($val, "Revoked user a's right to own tickets in queue 'DelegationTest". $msg);

ok( !$user_a->HasRight(Right => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)    ,"user a does not have the right to own tickets in queue 'DelegationTest'");

 ok( !$user_b->HasRight(Right => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)   ,"user b does not have the right to own tickets in queue 'DelegationTest'");

($val, $msg) = $user_a->PrincipalObj->GrantRight(ObjectType => 'Queue', ObjectId => $q->Id, Right => 'OwnTicket');
ok($val, $msg);

 ok( $user_a->HasRight(Right => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)   ,"user a has the right to own tickets in queue 'DelegationTest'");

 ok(  !$user_b->HasRight(Right => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)  ,"user b does not have the right to own tickets in queue 'DelegationTest'");

# {{{ get back to a known clean state 
($val, $msg) = $user_a->PrincipalObj->RevokeRight(ObjectType => 'Queue', ObjectId => $q->Id, Right => 'OwnTicket');
ok($val, "Revoked user a's right to own tickets in queue 'DelegationTest -". $msg);
ok( !$user_a->HasRight(Right => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)    ,"make sure that user a can't own tickets in queue 'DelegationTest'");
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
($val, $msg) = $del1->PrincipalObj->GrantRight(ObjectType => 'Queue', ObjectId => $q->Id, Right => 'OwnTicket');
ok( $val   ,"grant del1  the right to 'OwnTicket' in queue 'DelegationTest' - $msg");

ok(  $user_a->HasRight(Right => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)  ,"make sure that user a can own tickets in queue 'DelegationTest'");

my $group_ace= RT::ACE->new($user_a);
$group_ace->LoadByValues( PrincipalType => 'Group', PrincipalId => $del1->PrincipalId, ObjectType => 'Queue', ObjectId => $q->Id, RightName => 'OwnTicket');

ok ($group_ace->Id, "Found the ACE we want to test with for now");

($val, $msg) = $group_ace->Delegate(PrincipalId => $a_delegates->PrincipalId);

ok( $val   ,"user a tries and succeeds to delegate the right 'ownticket' in queue 'DelegationTest' to personal group 'delegates' - $msg");
ok(  $user_b->HasRight(Right => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)  ,"user b has the right to own tickets in queue 'DelegationTest'");


($val, $msg) = $del2b->DeleteMember($user_a->PrincipalId);
ok( $val   ,"remove user a from group del2b - $msg");
ok(  $user_a->HasRight(Right => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)  ,"user a has the right to own tickets in queue 'DelegationTest'");
ok( $user_b->HasRight(Right => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)    ,"user b has the right to own tickets in queue 'DelegationTest'");

# }}}

# {{{ When a  user is removed froom a group by the only path they're in there by, make sure the delegations go away
($val, $msg) = $del2->DeleteMember($user_a->PrincipalId);
ok( $val   ,"remove user a from group del2 - $msg");
ok(  !$user_a->HasRight(Right => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)  ,"user a does not have the right to own tickets in queue 'DelegationTest' ");
ok(  !$user_b->HasRight(Right => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)  ,"user b does not have the right to own tickets in queue 'DelegationTest' ");
# }}}

($val, $msg) = $del2->AddMember($user_a->PrincipalId);
ok( $val   ,"make user a a member of group del2 - $msg");

($val, $msg) = $del2->PrincipalObj->GrantRight(ObjectType => 'Queue', ObjectId => $q->Id, Right => 'OwnTicket');
ok($val, "grant the right 'own tickets' in queue 'DelegationTest' to group del2 - $msg");

my $del2_right = RT::ACE->new($user_a);
$del2_right->LoadByValues( PrincipalId => $del2->PrincipalId, PrincipalType => 'Group', ObjectType => 'Queue', ObjectId => $q->Id, RightName => 'OwnTicket');
ok ($del2_right->Id, "Found the right");

($val, $msg) = $del2_right->Delegate(PrincipalId => $a_delegates->PrincipalId);
ok( $val   ,"user a tries and succeeds to delegate the right 'ownticket' in queue 'DelegationTest' gotten via del2 to personal group 'delegates' - $msg");

# They have it via del1 and del2
ok( $user_a->HasRight(Right => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)   ,"user b has the right to own tickets in queue 'DelegationTest'");


($val, $msg) = $del2->PrincipalObj->RevokeRight(ObjectType => 'Queue', ObjectId => $q->Id, Right => 'OwnTicket');
ok($val, "revoke the right 'own tickets' in queue 'DelegationTest' to group del2 - $msg");
ok(  $user_a->HasRight(Right => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)  ,"user a does has the right to own tickets in queue 'DelegationTest' via del1");
ok(  !$user_b->HasRight(Right => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)   ,"user b does not have the right to own tickets in queue 'DelegationTest'");

($val, $msg) = $del2->PrincipalObj->GrantRight(ObjectType => 'Queue', ObjectId => $q->Id, Right => 'OwnTicket');
ok($val, "grant the right 'own tickets' in queue 'DelegationTest' to group del2 - $msg");


$group_ace= RT::ACE->new($user_a);
$group_ace->LoadByValues( PrincipalType => 'Group', PrincipalId => $del1->PrincipalId, ObjectType => 'Queue', ObjectId => $q->Id, RightName => 'OwnTicket');

ok ($group_ace->Id, "Found the ACE we want to test with for now");

($val, $msg) = $group_ace->Delegate(PrincipalId => $a_delegates->PrincipalId);

ok( $val   ,"user a tries and succeeds to delegate the right 'ownticket' in queue 'DelegationTest' to personal group 'delegates' - $msg");

ok( $user_b->HasRight(Right => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)    ,"user b has the right to own tickets in queue 'DelegationTest'");

($val, $msg) = $del2->DeleteMember($user_a->PrincipalId);
ok( $val   ,"remove user a from group del2 - $msg");

ok(  !$user_a->HasRight(Right => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)  ,"user a does not have the right to own tickets in queue 'DelegationTest'");

ok(  !$user_b->HasRight(Right => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)   ,"user b does not have the right to own tickets in queue 'DelegationTest'");



=end testing

=cut

sub Delegate {
    my $self = shift;
    my %args = (
        PrincipalId   => undef,
        @_
    );

    unless ($self->Id) {
        return(0, $self->loc("Right not loaded."));
    }
    my $princ_obj;
    ($princ_obj, $args{'PrincipalType'}) = $self->_CanonicalizePrincipal($args{'PrincipalId'}, $args{'PrincipalType'});
    
    unless ($princ_obj->id) {
        return ( 0,
            $self->loc( 'Principal [_1] not found.', $args{'PrincipalId'} ) );
    }

    # }}}

    # {{{ Check the ACL


    # First, we check to se if the user is delegating rights and
    # they have the permission to
    unless($self->CurrentUserHasSystemRight('DelegateRights')) { 
            return ( 0, $self->loc("Permission Denied") );
    }

    unless ($self->PrincipalObj->IsGroup) {
            return ( 0, $self->loc("System Error") );
    }
    unless ( $self->PrincipalObj->Object->HasMemberRecursively($self->CurrentUser->PrincipalObj)) {
            return ( 0, $self->loc("Permission Denied") );
    }

    # }}}

    my $concurrency_check = RT::ACE->new($RT::SystemUser);
    $concurrency_check->Load($self->Id);
    unless ($concurrency_check->Id) {
        $RT::Logger->crit("Trying to delegate a right which had already been deleted");
        return (0, $self->Loc('Permission Denied'));
    }

    my $delegated_ace = RT::ACE->new($self->CurrentUser);

    # Make sure the right doesn't already exist.
    $delegated_ace->LoadByCols(
        PrincipalId   => $princ_obj->Id,
        PrincipalType => 'Group', 
        RightName     => $self->__Value('RightName'),
        ObjectType    => $self->__Value('ObjectType'),
        ObjectId      => $self->__Value('ObjectId'),
        DelegatedBy   => $self->CurrentUser->PrincipalId,
        DelegatedFrom   => $self->id
    );
    if ( $delegated_ace->Id ) {
        return ( 0, $self->loc('That user already has that right') );
    }
    my $id = $delegated_ace->SUPER::Create(
        PrincipalId   => $princ_obj->Id,
        PrincipalType => 'Group',             # do we want to hardcode this?
        RightName     => $self->__Value('RightName'),
        ObjectType    => $self->__Value('ObjectType'),
        ObjectId      => $self->__Value('ObjectId'),
        DelegatedBy   => $self->CurrentUser->PrincipalId,
        DelegatedFrom => $self->id );

    #Clear the key cache. TODO someday we may want to just clear a little bit of the keycache space. 
    # TODO what about the groups key cache?
    RT::User->_InvalidateACLCache();

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

    unless ($self->Id) {
        return (0, $self->loc('Right not loaded.'));
    }

    # A user can delete an ACE if the current user has the right to modify it and it's not a delegated ACE
    # or if it's a delegated ACE and it was delegated by the current user
    unless ( ($self->CurrentUserHasRight('ModifyACL') && $self->__Value('DelegatedBy') == 0) ||
           ($self->__Value('DelegatedBy') == $self->CurrentUser->PrincipalId ) ) {
	    return (0, $self->loc('Permission Denied'));
    }	
    $self->_Delete(@_);
}

# Helper for Delete with no ACL check
sub _Delete {
    my $self = shift;
    my %args = ( InsideTransaction => undef,
                 @_ 
                 );

    my $InsideTransaction = $args{'InsideTransaction'};
    
    $RT::Handle->BeginTransaction() unless $InsideTransaction;

    my $delegated_from_this = RT::ACL->new($RT::SystemUser);
    $delegated_from_this->Limit(FIELD => 'DelegatedFrom',
                                OPERATOR => '=',
                                VALUE => $self->Id);

    my $delete_succeeded = 1;
    my $submsg;
    while (my $delegated_ace = $delegated_from_this->Next)  {
         ($delete_succeeded, $submsg) =  $delegated_ace->_Delete(InsideTransaction => 1);
         last if ($delete_succeeded);
    }

    unless ($delete_succeeded) {
        $RT::Handle->Rollback() unless $InsideTransaction;
        return ( 0, $self->loc('Right could not be revoked') );
    }

    my ($val,$msg) = $self->SUPER::Delete(@_);

    #Clear the key cache. TODO someday we may want to just clear a little bit of the keycache space. 
    # TODO what about the groups key cache?
    RT::User->_InvalidateACLCache();

    if ($val) {
        $RT::Handle->Commit() unless $InsideTransaction;
        return ( $val, $self->loc('Right revoked') );
    }
    else {
        $RT::Handle->Rollback() unless $InsideTransaction;
        return ( 0, $self->loc('Right could not be revoked') );
    }
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
    if ($args{'UserId'} ) {
    my $user = RT::User->new($self->CurrentUser);
    $user->Load($args{'UserId'});
        delete $args{'UserId'};
        $args{'PrincipalId'} = $user->PrincipalId;
        $args{'PrincipalType'} = 'User';
    }

    my $id = $self->SUPER::Create( %args);
    
    if ($id > 0 ) {
	return ($id);
    }
    else {
	    $RT::Logger->err('System error. right not granted.');
	    return(undef);
    }
    
}

# }}}

# {{{ sub CanonicalizeRightName

=head2 CanonicalizeRightName <RIGHT>

Takes a queue or system right name in any case and returns it in
the correct case. If it's not found, will return undef.

=cut

sub CanonicalizeRightName {
    my $self = shift;
    my $right = shift;
    $right = lc $right;
    if (exists $LOWERCASERIGHTNAMES{"$right"}) {
	return ($LOWERCASERIGHTNAMES{"$right"});
    }
    else {
	return (undef);
    }
}

# }}}

# {{{ sub QueueRights

=head2 QueueRights

Returns a hash of all the possible rights at the queue scope

=cut

sub QueueRights {
        return (%QUEUERIGHTS);
}

# }}}

# {{{ sub SystemRights

=head2 SystemRights

Returns a hash of all the possible rights at the system scope

=cut

sub SystemRights {
	return (%SYSTEMRIGHTS);
}


# }}}

# {{{ sub GroupRights

=head2 GroupRights

Returns a hash of all the possible rights at the system scope

=cut

sub GroupRights {
	return (%GROUPRIGHTS);
}


# }}}

# {{{ sub Object

=head2 Object

If the object this ACE applies ot o is a queue, returns the queue object. 
If the object this ACE applies ot o is a group, returns the group object. 
If it's the system object, returns undef. 

If the user has no rights, returns undef.

=cut

sub Object {
    my $self = shift;
    if ($self->ObjectType eq 'Queue') {
	my $appliesto_obj = RT::Queue->new($self->CurrentUser);
	$appliesto_obj->Load($self->ObjectId);
	return($appliesto_obj);
    }
    elsif ($self->ObjectType eq 'Group') {
	my $appliesto_obj = RT::Group->new($self->CurrentUser);
	$appliesto_obj->Load($self->ObjectId);
	return($appliesto_obj);
    }
    elsif ($self->ObjectType eq 'System') {
	return (undef);
    }	
    else {
	$RT::Logger->warning("$self -> Object called for an object ".
			     "of an unknown type:" . $self->ObjectType);
	return(undef);
    }
}	

# }}}

# {{{ sub PrincipalObj

=head2 PrincipalObj

Returns the RT::Principal object for this ACE. 

=cut

sub PrincipalObj {
    my $self = shift;

   	my $princ_obj = RT::Principal->new($self->CurrentUser);
    $princ_obj->Load($self->__Value('PrincipalId'));

    unless ($princ_obj->Id) {
        $RT::Logger->err("ACE ".$self->Id." couldn't load its principal object");
    }
    return($princ_obj);

}	

# }}}

# {{{ ACL related methods

# {{{ sub _Set

sub _Set {
  my $self = shift;
  return (0, $self->loc("ACEs can only be created and deleted."));
}

# }}}

# {{{ sub _Value

sub _Value {
    my $self = shift;

    if ( $self->__Value('DelegatedBy') eq $self->CurrentUser->PrincipalId ) {
        return ( $self->__Value(@_) );
    }
    elsif ($self->PrincipalObj->IsGroup &&
           $self->PrincipalObj->Object->HasMemberRecursively( $self->CurrentUser->PrincipalObj)) {
        return ( $self->__Value(@_) );
    }
    elsif ( $self->CurrentUserHasRight('ShowACL') ) {
        return ( $self->__Value(@_) );
    }
    else {
        return undef;
    }
}

# }}}


# {{{ sub CurrentUserHasGroupRight 

=head2 CurrentUserHasGroupRight ( Group => GROUPID, Right => RIGHTNANAME )

Check to see whether the current user has the specified right for the specified group.

=cut

sub CurrentUserHasGroupRight {
    my $self = shift;
    my %args = (Group => undef,
		Right => undef,
		@_
		);
    return ($self->HasRight( Right => $args{'Right'},
			     Principal => $self->CurrentUser,
			     Group => $args{'Group'}));
}

# }}}

# {{{ sub CurrentUserHasQueueRight 

=head2 CurrentUserHasQueueRight ( Queue => QUEUEID, Right => RIGHTNANAME )

Check to see whether the current user has the specified right for the specified queue.

=cut

sub CurrentUserHasQueueRight {
    my $self = shift;
    my %args = (Queue => undef,
		Right => undef,
		@_
		);
    return ($self->HasRight( Right => $args{'Right'},
			     Principal => $self->CurrentUser,
			     Queue => $args{'Queue'}));
}

# }}}

# {{{ sub CurrentUserHasSystemRight 
=head2 CurrentUserHasSystemRight RIGHTNAME

Check to see whether the current user has the specified right for the 'system' scope.

=cut

sub CurrentUserHasSystemRight {
    my $self = shift;
    my $right = shift;
    return ($self->HasRight( Right => $right,
			     Principal => $self->CurrentUser,
			     System => 1
			   ));
}


# }}}

# {{{ sub CurrentUserHasRight

=item CurrentUserHasRight RIGHT 
Takes a rightname as a string.

Helper menthod for HasRight. Presets Principal to CurrentUser then 
calls HasRight.

=cut

sub CurrentUserHasRight {
    my $self = shift;
    my $right = shift;
    return ($self->HasRight( Principal => $self->CurrentUser,
                             Right => $right,
			   ));
}

# }}}

# {{{ sub HasRight

=item HasRight {Right, Principal, Queue, System }

Takes a param-hash consisting of "Right" and "Principal"  Principal is 
an RT::User object or an RT::CurrentUser object. "Right" is a textual
Right string that applies to the given queue or systemwide,

=cut

sub HasRight {
    my $self = shift;
    my %args = ( Right => undef,
                 Principal => undef,
                 Group => undef,
		 Queue => undef,
		 System => undef,
                 @_ ); 

	# TODO XXXX This code could be refactored to just use ->HasRight
	# and be MUCH cleaner.

    #If we're explicitly specifying a queue, as we need to do on create
    if (defined $args{'Queue'}) {
	return ($args{'Principal'}->HasQueueRight(Right => $args{'Right'},
						  Queue => $args{'Queue'}));
    }
    elsif (defined $args{'Group'}) {
	return ($args{'Principal'}->HasGroupRight(Right => $args{'Right'},
						  Group => $args{'Group'}));
   }	
    #else if we're specifying to check a system right
    elsif ((defined $args{'System'}) and (defined $args{'Right'})) {
        return( $args{'Principal'}->HasSystemRight( $args{'Right'} ));
    }	
    
    elsif ($self->__Value('ObjectType') eq 'System') {
	return $args{'Principal'}->HasSystemRight($args{'Right'});
    }
    elsif ($self->__Value('ObjectType') eq 'Group') {
	return $args{'Principal'}->HasGroupRight( Group => $self->__Value('ObjectId'),
						  Right => $args{'Right'} );
    }	
    elsif ($self->__Value('ObjectType') eq 'Queue') {
	return $args{'Principal'}->HasQueueRight( Queue => $self->__Value('ObjectId'),
						  Right => $args{'Right'} );
    }	
    else {
	Carp;
	$RT::Logger->warning(Carp::cluck("$self: Trying to check an acl for a scope we ".
			     "don't understand:" . $self->__Value('ObjectType') ."\n"));
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
    my $self = shift;
    my $princ_id = shift;
    my $princ_type = shift;

    my $princ_obj = RT::Principal->new($RT::SystemUser);
    $princ_obj->Load( $princ_id );

    unless ($princ_obj->Id) {
        use Carp;
        $RT::Logger->crit(Carp::cluck);
        $RT::Logger->crit("Can't load a principal for id $princ_id");
        return($princ_obj, undef);
    }
    # Rights never get granted to users. they get granted to their 
    # ACL equivalence groups
   if ($princ_type eq 'User') {
        my $equiv_group = RT::Group->new($self->CurrentUser);
        $equiv_group->LoadACLEquivalenceGroup($princ_obj);
        unless ($equiv_group->Id) {
            $RT::Logger->crit("No ACL equiv group for princ ".$self->__Value('ObjectId'));
            return(0,$self->loc('System error. Right not granted.'));
        }
        $princ_obj = $equiv_group->PrincipalObj();
        $princ_type = 'Group';

    }
    return($princ_obj, $princ_type);
}
# }}}
1;

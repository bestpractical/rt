#$Header: /raid/cvsroot/rt/lib/RT/ACE.pm,v 1.3 2001/12/14 19:03:08 jesse Exp $

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
use RT::Principal;


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
  
  $self->LoadByCols (PrincipalId => $args{'PrincipalId'},
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
    my $princ_obj = RT::Principal->new($RT::SystemUser);
    $princ_obj->Load( $args{'PrincipalId'} );

    # Rights never get granted to users. they get granted to their 
    # ACL equivalence groups
   if ($args{'PrincipalType'} eq 'User') {
        my $equiv_group = RT::Group->new($self->CurrentUser);
        $equiv_group->LoadACLEquivalenceGroup($princ_obj);
        unless ($equiv_group->Id) {
            $RT::Logger->crit("No ACL equiv group for princ ".$self->ObjectId);
            return(0,$self->loc('System Error. Right not granted.'));
        }
        $princ_obj = $equiv_group->PrincipalObj();
        $args{'PrincipalType'} = 'Group';

    }

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

my $user_a = RT::User->new($RT::SystemUser);
$user_a->Create( Name => 'DelegationA', Privileged => 1);
ok ($user_a->Id, "Created delegation user a");

my $user_b = RT::User->new($RT::SystemUser);
$user_b->Create( Name => 'DelegationB', Privileged => 1);
ok ($user_b->Id, "Created delegation user b");

my $q = RT::Queue->new($RT::SystemUser);
$q->Create(Name =>'DelegationTest');
ok ($q->Id, "Created a delegation test queue");

#ok($user_a->HasSystemRight('AdminPersonalGroup')    ,"user a has the right 'AdminPersonalGroups' directly");

my $a_delegates = RT::Group->new($user_a);
$a_delegates->CreatePersonalGroup(Name => 'Delegates');
#ok( $a_delegates->Id   ,"user a creates a personal group 'Delegates'");
#ok( $a_delegates->AddMember($user_b->PrincipalId)   ,"user a adds user b to personal group 'delegates'");
ok( !$user_b->HasRight(RightName => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)    ,"user b does not have the right to OwnTicket' in queue 'DelegationTest'");
#ok(  $user_a->HasRight(RightName => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)  ,"user a has the right to 'OwnTicket' in queue 'DelegationTest'");
ok(!$user_a->HasSystemRight('DelegateRights')    ,"user a does not have the right 'delegate rights'");


TODO: {

    local $TODO = "ACL Delegation testing, once we finish implementing ACL delegation";

# ok(    ,"user a tries and fails to delegate the right 'ownticket' in queue 'DelegationTest' to personal group 'delegates'");
# ok(    ,"user a is granted the right to 'delegate rights'");
# ok(    ,"user a tries and succeeds to delegate the right 'ownticket' in queue 'DelegationTest' to personal group 'delegates'");
# ok(  $user_b->HasRight(RightName => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)  ,"user b has the right to own tickets in queue 'DelegationTest'");
# ok(    ,"user a removes b from pg 'delegates'");
# ok(  !$user_b->HasRight(RightName => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)  ,"user b does not have the right to own tickets in queue 'DelegationTest'");
# ok(    ,"user a adds user b to personal group 'delegates'");
# ok(   $user_b>-HasRight(RightName => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id) ,"user b has the right to own tickets in queue 'DelegationTest'");
# ok(    ,"user a revokes pg 'delegates' right to 'OwnTickets' in queue 'DelegationTest'");
# ok( ! $user_b->HasRight(RightName => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)   ,"user b does not have the right to own tickets in queue 'DelegationTest'");
# ok(    ,"user a grants pg 'delegates' right to 'OwnTickets' in queue 'DelegationTest'");

# ok(    ,"rt::system revokes user a's right to 'OwnTickets' in queue 'DelegationTest'");

# ok( !$user_a->HasRight(RightName => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)    ,"user a does not have the right to own tickets in queue 'DelegationTest'");

# ok( !$user_b->HasRight(RightName => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)   ,"user b does not have the right to own tickets in queue 'DelegationTest'");

# ok(    ,"rt::system grants user a's right to 'OwnTickets' in queue 'DelegationTest'");

# ok( $user_a->HasRight(RightName => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)   ,"user a has the right to own tickets in queue 'DelegationTest'");

# ok(  !$user_b->HasRight(RightName => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)  ,"user b does not have the right to own tickets in queue 'DelegationTest'");

# ok(    ,"create a group del1");
# ok(    ,"create a group del2");
# ok(    ,"make del2 a member of del1");
# ok(    ,"create a group del2a");
# ok(    ,"make del2a a member of del2");
# ok(    ,"create a group del2b");
# ok(    ,"make del2b a member of del2");
# ok(    ,"make 'user a' a member of del2b");
# ok(    ,"make 'user a' a member of del2");


# ok(    ,"revoke user a's right to 'OwnTicket' in queue 'DelegationTest'");
# ok( !$user_a->HasRight(RightName => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)    ,"make sure that user a can't own tickets in queue 'DelegationTest'");
# ok(    ,"grant del1  the right to 'OwnTicket' in queue 'DelegationTest'");
# ok(  $user_a->HasRight(RightName => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)  ,"make sure that user a can own tickets in queue 'DelegationTest'");

# ok(    ,"user a tries and succeeds to delegate the right 'ownticket' in queue 'DelegationTest' to personal group 'delegates'");
# ok(  $user_b->HasRight(RightName => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)  ,"user b has the right to own tickets in queue 'DelegationTest'");
# ok(    ,"remove user a from group del2b");
# ok(  $user_a->HasRight(RightName => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)  ,"user a has the right to own tickets in queue 'DelegationTest'");
# ok( $user_b->HasRight(RightName => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)    ,"user b has the right to own tickets in queue 'DelegationTest'");
# ok(    ,"remove user a from group del2");
# ok(  !$user_a->HasRight(RightName => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)  ,"user a does not have the right to own tickets in queue 'DelegationTest' ");
# ok(  !$user_b->HasRight(RightName => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)  ,"user b does not have the right to own tickets in queue 'DelegationTest' ");


# ok(    ,"make user a a member of group del2");
# ok(    ,"grant the right 'own tickets' in queue 'DelegationTest' to group del2");
# ok(    ,"user a tries and succeeds to delegate the right 'ownticket' in queue 'DelegationTest' to personal group 'delegates'");
# ok( $user_a->HasRight(RightName => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)   ,"user b has the right to own tickets in queue 'DelegationTest'");
# ok(    ,"revoke del2's right 'own tickets' in queue 'DelegationTest'");
# ok(  !$user_a->HasRight(RightName => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)  ,"user a does not have the right to own tickets in queue 'DelegationTest'");
# ok(  !$user_b->HasRight(RightName => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)   ,"user b does not have the right to own tickets in queue 'DelegationTest'");
# ok(    ,"grant the right 'own tickets' in queue 'DelegationTest' to group del2");
# ok(    ,"user a tries and succeeds to delegate the right 'ownticket' in queue 'DelegationTest' to personal group 'delegates'");
# ok( $user_b->HasRight(RightName => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)    ,"user b has the right to own tickets in queue 'DelegationTest'");
# ok(    ,"remove user a from group del2");
# ok(  !$user_a->HasRight(RightName => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)  ,"user a does not have the right to own tickets in queue 'DelegationTest'");
# ok(  !$user_b->HasRight(RightName => 'OwnTicket', ObjectType => 'Queue', ObjectId => $q->Id)   ,"user b does not have the right to own tickets in queue 'DelegationTest'");

}


=end testing

=cut

sub Delegate {
    my $self = shift;
    my %args = (
        PrincipalId   => undef,
        @_
    );

    # {{{ Validate the principal
    my $princ_obj = RT::Principal->new($RT::SystemUser);
    $princ_obj->Load( $args{'PrincipalId'} );

    unless ($princ_obj->Id) {
        return ( 0,
            $self->loc( 'Principal [_1] not found.', $args{'PrincipalId'} ) );
    }

    # }}}

    # {{{ Canonicalize and check the right name
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

    # {{{ Check the ACL


    # First, we check to se if the user is delegating rights and
    # they have the permission to
    unless($self->CurrentUserHasSystemRight('DelegateRights')) { 
            return ( 0, $self->loc("Permission Denied") );
    }

    unless ($self->PrincipalObj->IsGroup && 
            $self->PrincipalObj->Object->HasMemberRecursively($self->CurrentUser->PrincipalId)) {
            return ( 0, $self->loc("Permission Denied") );
    }

    # }}}

    # Make sure the right doesn't already exist.
    $self->LoadByCols(
        PrincipalId   => $princ_obj->Id,
        PrincipalType => 'Group', 
        RightName     => $self->RightName,
        ObjectType    => $self->ObjectType,
        ObjectId      => $self->ObjectId,
        DelegatedBy   => $self->CurrentUser->PrincipalId,
        DelegatedFrom   => $self->id
    );
    if ( $self->Id ) {
        return ( 0, $self->loc('That user already has that right') );
    }

    my $id = $self->SUPER::Create(
        PrincipalId   => $princ_obj->Id,
        PrincipalType => 'Group',             # do we want to hardcode this?
        RightName     => $self->RightName,
        ObjectType    => $self->ObjectType,
        ObjectId      => $self->ObjectId,
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
    my %args = ( InsideTransaction => undef,
                 @_ 
                 );

    my $InsideTransaction = $args{'InsideTransaction'};


    unless ($self->Id) {
        return (0, $self->loc('Right not loaded.'));
    }

    # A user can delete an ACE if the current user has the right to modify it and it's not a delegated ACE
    # or if it's a delegated ACE and it was delegated by the current user
    unless ( ($self->CurrentUserHasRight('ModifyACL') && $self->DelegatedBy == 0) ||
           ($self->DelegatedBy == $self->CurrentUser->PrincipalId ) ) {
	    return (0, $self->loc('Permission Denied'));
    }	
    
    $RT::Handle->BeginTransaction() unless $InsideTransaction;

    my $delegated_from_this = RT::ACL->new($RT::SystemUser);
    $delegated_from_this->Limit(FIELD => 'DelegatedFrom',
                                OPERATOR => '=',
                                VALUE => $self->Id);

    my $delete_succeeded = 1;
    my $submsg;
    while (my $delegated_ace = $delegated_from_this->Next && $delete_succeeded) {
         ($delete_succeeded, $submsg) =  $delegated_ace->Delete(InsideTransaction => 1);
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
    $princ_obj->Load($self->PrincipalId);
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

    unless ($self->CurrentUserHasRight('ShowACL')) {
	return (undef);
    }

    return ($self->__Value(@_));
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
			     Principal => $self->CurrentUser->UserObj,
			     Group => $args{'Group'}));
}

# }}}

# {{{ sub CurrentUserHasSystemRight 
=head2 CurrentUserHasSystemRight RIGHTNAME
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
			     Principal => $self->CurrentUser->UserObj,
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
			     Principal => $self->CurrentUser->UserObj,
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
    return ($self->HasRight( Principal => $self->CurrentUser->UserObj,
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

1;

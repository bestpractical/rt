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

use vars qw (%SCOPES
   	     %QUEUERIGHTS
	     %SYSTEMRIGHTS
	     %LOWERCASERIGHTNAMES
	    ); 

%SCOPES = (
	   System => 'System-level right',
	   Queue => 'Queue-level right'
	  );

# {{{ Descriptions of rights

# Queue rights are the sort of queue rights that can only be granted
# to real people or groups
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
%SYSTEMRIGHTS = (
        SuperUser => 'Do anything and everything',
		AdminGroups => 'Create, delete and modify groups',
	    AdminUsers => 'Create, Delete and Modify users',
		ModifySelf => 'Modify one\'s own RT account',

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

# }}}

# {{{ sub _Init
sub _Init  {
  my $self = shift;
  $self->{'table'} = "ACL";
  return($self->SUPER::_Init(@_));
}
# }}}

# {{{ sub LoadByValues

=head2 LoadByValues PARAMHASH

Load an ACE by specifying a paramhash with the following fields:

              PrincipalId => undef,
	      PrincipalType => undef,
	      RightName => undef,
	      RightScope => undef,
	      RightAppliesTo => undef,

=cut

sub LoadByValues {
  my $self = shift;
  my %args = (PrincipalId => undef,
	      PrincipalType => undef,
	      RightName => undef,
	      RightScope => undef,
	      RightAppliesTo => undef,
	      @_);
  
  $self->LoadByCols (PrincipalId => $args{'PrincipalId'},
		     PrincipalType => $args{'PrincipalType'},
		     RightName => $args{'RightName'},
		     RightScope => $args{'RightScope'},
		     RightAppliesTo => $args{'RightAppliesTo'}
		    );
  
  #If we couldn't load it.
  unless ($self->Id) {
      return (0, "ACE not found");
  }
  # if we could
  return ($self->Id, "ACE Loaded");
  
}

# }}}

# {{{ sub Create

=head2 Create <PARAMS>

PARAMS is a parameter hash with the following elements:

   PrincipalType => "Queue"|"User"
   PrincipalId => an intentifier you can use to ->Load a user or group
   RightName => the name of a right. in any case
   RightScope => "System" | "Queue"
   RightAppliesTo => a queue id or undef

=cut

sub Create {
    my $self = shift;
    my %args = ( PrincipalId => undef,
		 PrincipalType => undef,
		 RightName => undef,
		 RightScope => undef,
		 RightAppliesTo => undef,
		 @_
	       );
    
    # {{{ Validate the principal
    my ($princ_obj);
    if ($args{'PrincipalType'} eq 'User') {
	$princ_obj = new RT::User($RT::SystemUser);
	
    }	
    elsif ($args{'PrincipalType'} eq 'Group') {
	require RT::Group;
	$princ_obj = new RT::Group($RT::SystemUser);
    }
    else {
	return (0, 'Principal type '.$args{'PrincipalType'} . ' is invalid.');
    }	
    
    $princ_obj->Load($args{'PrincipalId'});
    my $princ_id = $princ_obj->Id();
    
    unless ($princ_id) {
	return (0, 'Principal '.$args{'PrincipalId'}.' not found.');
    }

    # }}}
    
    #TODO allow loading of queues by name.    
    
    # {{{ Check the ACL
    if ($args{'RightScope'} eq 'System') {
	
	unless ($self->CurrentUserHasSystemRight('ModifyACL')) {
	    $RT::Logger->error("Permission Denied.");
	    return(undef);
	}
    }
    
    elsif ($args{'RightScope'} eq 'Queue') {
	unless ($self->CurrentUserHasQueueRight( Queue => $args{'RightAppliesTo'},
						 Right => 'ModifyACL')) {
	    return (0, 'Permission Denied.');
	}
	
	
	
	
    }
    #If it's not a scope we recognise, something scary is happening.
    else {
	$RT::Logger->err("RT::ACE->Create got a scope it didn't recognize: ".
			 $args{'RightScope'}." Bailing. \n");
	return(0,"System error. Unable to grant rights.");
    }

    # }}}

    # {{{ Canonicalize and check the right name
    $args{'RightName'} = $self->CanonicalizeRightName($args{'RightName'});
    
    #check if it's a valid RightName
    if ($args{'RightScope'} eq 'Queue') {
	unless (exists $QUEUERIGHTS{$args{'RightName'}}) {
	    return(0, 'Invalid right');
	}	
	}	
    elsif ($args{'RightScope' eq 'System'}) {
	unless (exists $SYSTEMRIGHTS{$args{'RightName'}}) {
	    return(0, 'Invalid right');
	}		    
    }	
    # }}}
    
    # Make sure the right doesn't already exist.
    $self->LoadByCols (PrincipalId => $princ_id,
		       PrincipalType => $args{'PrincipalType'},
		       RightName => $args{'RightName'},
		       RightScope => $args {'RightScope'},
		       RightAppliesTo => $args{'RightAppliesTo'}
		      );
    if ($self->Id) {
	return (0, 'That user already has that right');
    }	

    my $id = $self->SUPER::Create( PrincipalId => $princ_id,
				   PrincipalType => $args{'PrincipalType'},
				   RightName => $args{'RightName'},
				   RightScope => $args {'RightScope'},
				   RightAppliesTo => $args{'RightAppliesTo'}
				 );
    
    
    if ($id > 0 ) {
	return ($id, 'Right Granted');
    }
    else {
	$RT::Logger->err('System error. right not granted.');
	return(0, 'System Error. right not granted');
    }
}

# }}}


# {{{ sub Delete 

=head2 Delete

Delete this object.

=cut

sub Delete {
    my $self = shift;
    
    unless ($self->CurrentUserHasRight('ModifyACL')) {
	return (0, 'Permission Denied');
    }	
    
    
    my ($val,$msg) = $self->SUPER::Delete(@_);
    if ($val) {
	return ($val, 'ACE Deleted');
    }	
    else {
	return (0, 'ACE could not be deleted');
    }
}

# }}}

# {{{ sub _BootstrapRight 

=head2 _BootstrapRight

Grant a right with no error checking and no ACL. this is _only_ for 
installation. If you use this routine without jesse@fsck.com's explicit 
written approval, he will hunt you down and make you spend eternity
translating mozilla's code into FORTRAN or intercal.

=cut

sub _BootstrapRight {
    my $self = shift;
    my %args = @_;

    my $id = $self->SUPER::Create( PrincipalId => $args{'PrincipalId'},
				   PrincipalType => $args{'PrincipalType'},
				   RightName => $args{'RightName'},
				   RightScope => $args {'RightScope'},
				   RightAppliesTo => $args{'RightAppliesTo'}
				 );
    
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

# {{{ sub _Accessible 

sub _Accessible  {
  my $self = shift;  
  my %Cols = (
	      PrincipalId => 'read/write',
	      PrincipalType => 'read/write',
	      RightName => 'read/write', 
	      RightScope => 'read/write',
	      RightAppliesTo => 'read/write'
	    );
  return($self->SUPER::_Accessible(@_, %Cols));
}
# }}}

# {{{ sub AppliesToObj

=head2 AppliesToObj

If the AppliesTo is a queue, returns the queue object. If it's 
the system object, returns undef. If the user has no rights, returns undef.

=cut

sub AppliesToObj {
    my $self = shift;
    if ($self->RightScope eq 'Queue') {
	my $appliesto_obj = new RT::Queue($self->CurrentUser);
	$appliesto_obj->Load($self->RightAppliesTo);
	return($appliesto_obj);
    }
    elsif ($self->RightScope eq 'System') {
	return (undef);
    }	
    else {
	$RT::Logger->warning("$self -> AppliesToObj called for an object ".
			     "of an unknown scope:" . $self->RightScope);
	return(undef);
    }
}	

# }}}

# {{{ sub PrincipalObj

=head2 PrincipalObj

If the AppliesTo is a group, returns the group object.
If the AppliesTo is a user, returns the user object.
Otherwise, it logs a warning and returns undef.

=cut

sub PrincipalObj {
    my $self = shift;
    my ($princ_obj);

    if ($self->PrincipalType eq 'Group') {
	use RT::Group;
	$princ_obj = new RT::Group($self->CurrentUser);
    }
    elsif ($self->PrincipalType eq 'User') {
	$princ_obj = new RT::User($self->CurrentUser);
    }
    else {
	$RT::Logger->warning("$self -> PrincipalObj called for an object ".
			     "of an unknown principal type:" . 
			     $self->PrincipalType ."\n");
	return(undef);
    }
    
    $princ_obj->Load($self->PrincipalId);
    return($princ_obj);

}	

# }}}

# {{{ ACL related methods

# {{{ sub _Set

sub _Set {
  my $self = shift;
  return (0, "ACEs can only be created and deleted.");
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

    #If we're explicitly specifying a queue, as we need to do on create
    if (defined $args{'Queue'}) {
	return ($args{'Principal'}->HasQueueRight(Right => $args{'Right'},
						  Queue => $args{'Queue'}));
    }
    #else if we're specifying to check a system right
    elsif ((defined $args{'System'}) and (defined $args{'Right'})) {
        return( $args{'Principal'}->HasSystemRight( $args{'Right'} ));
    }	
    
    elsif ($self->__Value('RightScope') eq 'System') {
	return $args{'Principal'}->HasSystemRight($args{'Right'});
    }
    elsif ($self->__Value('RightScope') eq 'Queue') {
	return $args{'Principal'}->HasQueueRight( Queue => $self->__Value('RightAppliesTo'),
						  Right => $args{'Right'} );
    }	
    else {
	$RT::Logger->warning("$self: Trying to check an acl for a scope we ".
			     "don't understand:" . $self->__Value('RightScope') ."\n");
	return undef;
    }



}
# }}}

# }}}

1;

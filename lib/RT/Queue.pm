# $Header$

=head1 NAME

  RT::Queue - an RT Queue object

=head1 SYNOPSIS

  use RT::Queue;

=head1 DESCRIPTION


=head1 METHODS

=cut

package RT::Queue;
use RT::Record;

@ISA= qw(RT::Record);

# {{{  sub _Init 
sub _Init  {
    my $self = shift;
    $self->{'table'} = "Queues";
    return ($self->SUPER::_Init(@_));
}
# }}}

# {{{ sub _Accessible 

sub _Accessible  {
    my $self = shift;
    my %Cols = ( Name => 'read/write',
		 CorrespondAddress => 'read/write',
		 Description => 'read/write',
		 CommentAddress =>  'read/write',
		 InitialPriority =>  'read/write',
		 FinalPriority =>  'read/write',
		 DefaultDueIn =>  'read/write',
		 Creator => 'read/auto',
		 Created => 'read/auto',
		 LastUpdatedBy => 'read/auto',
		 LastUpdated => 'read/auto',
		 Disabled => 'read/write',
		 
	       );
    return($self->SUPER::_Accessible(@_, %Cols));
}

# }}}

# {{{ sub Create

=head2 Create

Create takes the name of the new queue 
If you pass the ACL check, it creates the queue and returns its queue id.

=cut

sub Create  {
    my $self = shift;
    my %args = ( Name => undef,
		 CorrespondAddress => undef,
		 Description => undef,
		 CommentAddress => undef,
		 InitialPriority => undef,
		 FinalPriority =>  undef,
		 DefaultDueIn =>  undef,
		 @_); 
    
    unless ($self->CurrentUser->HasSystemRight('AdminQueue')) {    #Check them ACLs
	return (0, "No permission to create queues") 
    }

    unless ($self->ValidateName($args{'Name'})) {
	return(0, 'Queue already exists');
    }
    #TODO better input validation
    
    my $id = $self->SUPER::Create(%args);
    unless ($id) {
	return (0, 'Queue could not be created');
    }

    return ($id, "Queue $id created");
}

# }}}

# {{{ sub Delete 

sub Delete {
    my $self = shift;
    return (0, 'Deleting this object would break referential integrity');
}

# }}}

# {{{ sub SetDisabled

=head2 SetDisabled

Takes a boolean.
1 will cause this queue to no longer be avaialble for tickets.
0 will re-enable this queue

=cut

# }}}

# {{{ sub Load 

=head2 Load

Takes either a numerical id or a textual Name and loads the specified queue.
  
=cut

sub Load  {
    my $self = shift;
    
    my $identifier = shift;
    if (!$identifier) {
	return (undef);
    }	    
    
    if ($identifier !~ /\D/) {
	$self->SUPER::LoadById($identifier);
    }
    else {
	$self->LoadByCol("Name", $identifier);
    }

    return ($self->Id);


}
# }}}

# {{{ sub ValidateName

=head2 ValidateName NAME

Takes a queue name. Returns true if it's an ok name for
a new queue. Returns undef if there's already a queue by that name.

=cut

sub ValidateName {
    my $self = shift;
    my $name = shift;
   
    my $tempqueue = new RT::Queue($RT::SystemUser);
    $tempqueue->Load($name);

    #If we couldn't load it :)
    unless ($tempqueue->id()) {
	return(1);
    }

    #If this queue exists, return undef
    #Avoid the ACL check.
    if ($tempqueue->Name()){
        return(undef);
    }

    #If the queue doesn't exist, return 1
    else {
        return(1);
    }

}


# }}}

# {{{ sub Templates

=head2 Templates

Returns an RT::Templates object of all of this queue's templates.

=cut

sub Templates {
    my $self = shift;
    

    my $templates = RT::Templates->new($self->CurrentUser);

    if ($self->CurrentUserHasRight('ShowTemplate')) {
	$templates->LimitToQueue($self->id);
    }
    
    return ($templates); 
}

# }}}

# {{{ Dealing with watchers

# {{{ sub Watchers

=head2

Watchers returns a Watchers object preloaded with this queue\'s watchers.

=cut

sub Watchers {
    my $self = shift;
    
    require RT::Watchers;
    my $watchers =RT::Watchers->new($self->CurrentUser);
    
    if ($self->CurrentUserHasRight('SeeQueue')) {
	$watchers->LimitToQueue($self->id);	
    }	
    
    return($watchers);
}

# }}}

# {{{ sub WatchersAsString
=head2 WatchersAsString

Returns a string of all queue watchers email addresses concatenated with ','s.

=cut

sub WatchersAsString {
    my $self=shift;
    return($self->Watchers->EmailsAsString());
}

# }}}

# {{{ sub AdminCcAsString 

=head2 AdminCcAsString

Takes nothing. returns a string: All Ticket/Queue AdminCcs.

=cut


sub AdminCcAsString {
    my $self=shift;
    
    return($self->AdminCc->EmailsAsString());
  }

# }}}

# {{{ sub CcAsString

=head2 CcAsString

B<Returns> String: All Queue Ccs as a comma delimited set of email addresses.

=cut

sub CcAsString {
    my $self=shift;
    
    return ($self->Cc->EmailsAsString());
}

# }}}

# {{{ sub Cc

=head2 Cc

Takes nothing.
Returns a watchers object which contains this queue\'s Cc watchers

=cut

sub Cc {
    my $self = shift;
    my $cc = $self->Watchers();
    if ($self->CurrentUserHasRight('SeeQueue')) {
	$cc->LimitToCc();
    }
    return ($cc);
}

# A helper function for Cc, so that we can call it from the ACL checks 
# without going through acl checks.

sub _Cc {
    my $self = shift;
    my $cc = $self->Watchers();
    $cc->LimitToCc();
    return($cc);
    
}

# }}}

# {{{ sub AdminCc

=head2 AdminCc

Takes nothing.
Returns this queue's administrative Ccs as an RT::Watchers object

=cut

sub AdminCc {
    my $self = shift;
    my $admin_cc = $self->Watchers();
    if ($self->CurrentUserHasRight('SeeQueue')) {
 	$admin_cc->LimitToAdminCc();
    }
    return($admin_cc);
}

#helper function for AdminCc so we can call it without ACLs
sub _AdminCc {
    my $self = shift;
    my $admin_cc = $self->Watchers();
    $admin_cc->LimitToAdminCc();
    return($admin_cc);
}

# }}}

# {{{ IsWatcher, IsCc, IsAdminCc

# {{{ sub IsWatcher

# a generic routine to be called by IsRequestor, IsCc and IsAdminCc

=head2 IsWatcher

Takes a param hash with the attributes Type and User. User is either a user object or string containing an email address. Returns true if that user or string
is a queue watcher. Returns undef otherwise
=cut

sub IsWatcher {
    my $self = shift;
    
    my %args = ( Type => 'Requestor',
		 Id => undef,
		 Email => undef,
		 @_
	       );
    #ACL check - can't do it. we need this method for ACL checks
    #    unless ($self->CurrentUserHasRight('SeeQueue')) {
    #	return(undef);
    #    }


    my %cols = ('Type' => $args{'Type'},
		'Scope' => 'Queue',
		'Value' => $self->Id
	       );
    if (defined ($args{'Id'})) {
	if (ref($args{'Id'})){ #If it's a ref, assume it's an RT::User object;
	    #Dangerous but ok for now
	    $cols{'Owner'} = $args{'Id'}->Id;
	}
	elsif ($args{'Id'} =~ /^\d+$/) { # if it's an integer, it's an RT::User obj
	    $cols{'Owner'} = $args{'Id'};
	}
	else {
	    $cols{'Email'} = $args{'Id'};
	}	
    }	
    
    if (defined $args{'Email'}) {
	$cols{'Email'} = $args{'Email'};
    }

    my ($description);
    $description = join(":",%cols);
    
    #If we've cached a positive match...
    if (defined $self->{'watchers_cache'}->{"$description"}) {
	if ($self->{'watchers_cache'}->{"$description"} == 1) {
	    return(1);
	}
	#If we've cached a negative match...
	else {
	    return(undef);
	}
    }

    require RT::Watcher;
    my $watcher = new RT::Watcher($self->CurrentUser);
    $watcher->LoadByCols(%cols);
    
    
    if ($watcher->id) {
	$self->{'watchers_cache'}->{"$description"} = 1;
	return(1);
    }	
    else {
	$self->{'watchers_cache'}->{"$description"} = 0;
	return(undef);
    }
    
}

# }}}

# {{{ sub IsCc

=head2 IsCc

Takes a string. Returns true if the string is a Cc watcher of the current queue

=item Bugs

Should also be able to handle an RT::User object

=cut


sub IsCc {
  my $self = shift;
  my $cc = shift;
  
  return ($self->IsWatcher( Type => 'Cc', Id => $cc ));
  
}

# }}}

# {{{ sub IsAdminCc

=head2 IsAdminCc

Takes a string. Returns true if the string is an AdminCc watcher of the current queue

=item Bugs

Should also be able to handle an RT::User object

=cut

sub IsAdminCc {
  my $self = shift;
  my $admincc = shift;
  
  return ($self->IsWatcher( Type => 'AdminCc', Id => $admincc ));
  
}

# }}}

# }}}

# {{{ sub AddWatcher

=head2 AddWatcher

Takes a paramhash of Email, Owner and Type. Type is one of 'Cc' or 'AdminCc',
We need either an Email Address in Email or a userid in Owner

=cut

sub AddWatcher {
    my $self = shift;
    my %args = ( Email => undef,
		 Type => undef,
		 Owner => 0,
		 @_
	       );
    
    # {{{ Check ACLS
    #If the watcher we're trying to add is for the current user
    if ( ( ( defined $args{'Email'})  && 
           ( $args{'Email'} eq $self->CurrentUser->EmailAddress) ) or 
	 ($args{'Owner'} eq $self->CurrentUser->Id)) {
	
	#  If it's an AdminCc and they don't have 
	#   'WatchAsAdminCc' or 'ModifyQueueWatchers', bail
	if ($args{'Type'} eq 'AdminCc') {
	    unless ($self->CurrentUserHasRight('ModifyQueueWatchers') or 
		    $self->CurrentUserHasRight('WatchAsAdminCc')) {
		return(0, 'Permission denied');
	    }
	}

	#  If it's a Requestor or Cc and they don't have
	#   'Watch' or 'ModifyQueueWatchers', bail
	elsif ($args{'Type'} eq 'Cc') {
	    unless ($self->CurrentUserHasRight('ModifyQueueWatchers') or 
		    $self->CurrentUserHasRight('Watch')) {
		return(0, 'Permission denied');
	    }
	}
	else {
	    $RT::Logger->warn("$self -> AddWatcher hit code".
			      " it never should. We got passed ".
			      " a type of ". $args{'Type'});
	    return (0,'Error in parameters to $self AddWatcher');
	}
    }
    # If the watcher isn't the current user 
    # and the current user  doesn't have 'ModifyQueueWatchers'
    # bail
    else {
	unless ($self->CurrentUserHasRight('ModifyQueueWatchers')) {
	    return (0, "Permission Denied");
	}
    }
    # }}}
        
    require RT::Watcher;
    my $Watcher = new RT::Watcher ($self->CurrentUser);
    return ($Watcher->Create(Scope => 'Queue', 
			     Value => $self->Id,
			     Email => $args{'Email'},
			     Type => $args{'Type'},
			     Owner => $args{'Owner'}
			    ));
}

# }}}

# {{{ sub AddCc

=head2 AddCc

Add a Cc to this queue.
Takes a paramhash of Email and Owner. 
We need either an Email Address in Email or a userid in Owner

=cut


sub AddCc {
    my $self = shift;
    return ($self->AddWatcher( Type => 'Cc', @_));
}
# }}}

# {{{ sub AddAdminCc

=head2 AddAdminCc

Add an Administrative Cc to this queue.
Takes a paramhash of Email and Owner. 
We need either an Email Address in Email or a userid in Owner

=cut

sub AddAdminCc {
    my $self = shift;
    return ($self->AddWatcher( Type => 'AdminCc', @_));
}
# }}}

# {{{ sub DeleteWatcher

=head2 DeleteWatcher id [type]

DeleteWatcher takes a single argument which is either an email address 
or a watcher id.  
If the first argument is an email address, you need to specify the watcher type you're talking
about as the second argument. Valid values are 'Cc' or 'AdminCc'.
It removes that watcher from this Queue\'s list of watchers.


=cut


sub DeleteWatcher {
    my $self = shift;
    my $id = shift;
    
    my $type;
    
    $type = shift if (@_);
    

    require RT::Watcher;
    my $Watcher = new RT::Watcher($self->CurrentUser);
    
    #If it\'s a numeric watcherid
    if ($id =~ /^(\d*)$/) {
	$Watcher->Load($id);
    }
    
    #Otherwise, we'll assume it's an email address
    elsif ($type) {
	my ($result, $msg) = 
	  $Watcher->LoadByValue( Email => $id,
				 Scope => 'Queue',
				 Value => $self->id,
				 Type => $type);
	return (0,$msg) unless ($result);
    }
    
    else {
	return(0,"Can\'t delete a watcher by email address without specifying a type");
    }
    
    # {{{ Check ACLS 

    #If the watcher we're trying to delete is for the current user
    if ($Watcher->Email eq $self->CurrentUser->EmailAddress) {
		
	#  If it's an AdminCc and they don't have 
	#   'WatchAsAdminCc' or 'ModifyQueueWatchers', bail
	if ($Watcher->Type eq 'AdminCc') {
	    unless ($self->CurrentUserHasRight('ModifyQueueWatchers') or 
		    $self->CurrentUserHasRight('WatchAsAdminCc')) {
		return(0, 'Permission denied');
	    }
	}

	#  If it's a  Cc and they don't have
	#   'Watch' or 'ModifyQueueWatchers', bail
	elsif ($Watcher->Type eq 'Cc') {
	    unless ($self->CurrentUserHasRight('ModifyQueueWatchers') or 
		    $self->CurrentUserHasRight('Watch')) {
		return(0, 'Permission denied');
	    }
	}
	else {
	    $RT::Logger->warn("$self -> DeleteWatcher hit code".
			      " it never should. We got passed ".
			      " a type of ". $args{'Type'});
	    return (0,'Error in parameters to $self DeleteWatcher');
	}
    }
    # If the watcher isn't the current user 
    # and the current user  doesn't have 'ModifyQueueWatchers'
    # bail
    else {
	unless ($self->CurrentUserHasRight('ModifyQueueWatchers')) {
	    return (0, "Permission Denied");
	}
    }

    # }}}
    
    unless (($Watcher->Scope eq 'Queue') and
	    ($Watcher->Value == $self->id) ) {
	return (0, "Not a watcher for this queue");
    }
    

    #Clear out the watchers hash.
    $self->{'watchers'} = undef;
    
    my $retval = $Watcher->Delete();
    
    unless ($retval) {
	return(0,"Watcher could not be deleted.");
    }
    
    return(1, "Watcher deleted");
}

# {{{ sub DeleteCc

=head2 DeleteCc EMAIL

Takes an email address. It calls DeleteWatcher with a preset 
type of 'Cc'


=cut

sub DeleteCc {
   my $self = shift;
   my $id = shift;
   return ($self->DeleteWatcher ($id, 'Cc'))
}

# }}}

# {{{ sub DeleteAdminCc

=head2 DeleteAdminCc EMAIL

Takes an email address. It calls DeleteWatcher with a preset 
type of 'AdminCc'


=cut

sub DeleteAdminCc {
   my $self = shift;
   my $id = shift;
   return ($self->DeleteWatcher ($id, 'AdminCc'))
}

# }}}


# }}}

# }}}

# {{{ Dealing with keyword selects

# {{{ sub AddKeywordSelect

=head2 AddKeywordSelect

Takes a paramhash of Name, Keyword, Depth and Single.  Adds a new KeywordSelect for 
this queue with those attributes.

=cut


sub AddKeywordSelect {
    my $self = shift;
    my %args = ( Keyword => undef,
		 Depth => undef,
		 Single => undef,
		 Name => undef,
		 @_);
    
    #ACLS get handled in KeywordSelect
    my $NewKeywordSelect = new RT::KeywordSelect($self->CurrentUser);
    
    return ($NewKeywordSelect->Create (Keyword => $args{'Keyword'},
			       Depth => $args{'Depth'},
			       Name => $args{'Name'},
			       Single => $args{'Single'},
			       ObjectType => 'Ticket',
			       ObjectField => 'Queue',
			       ObjectValue => $self->Id()
			      )	);
}

# }}}

# {{{ sub KeywordSelect

=head2 KeywordSelect([NAME])

Takes the name of a keyword select for this queue or that's global.
Returns the relevant KeywordSelect object.  Prefers a keywordselect that's 
specific to this queue over a global one.  If it can't find the proper
Keword select or the user doesn't have permission, returns an empty 
KeywordSelect object

=cut

sub KeywordSelect {
    my $self = shift;
    my $name = shift;
    
    require RT::KeywordSelect;

    my $select = RT::KeywordSelect->new($self->CurrentUser);
    if ($self->CurrentUserHasRight('SeeQueue')) {
	$select->LoadByName( Name => $name, Queue => $self->Id);
    }
    return ($select);
}


# }}}

# {{{ sub KeywordSelects

=head2 KeywordSelects

Returns an B<RT::KeywordSelects> object containing the collection of
B<RT::KeywordSelect> objects which apply to this queue. (Both queue specific keyword selects
and global keyword selects.

=cut

sub KeywordSelects {
  my $self = shift;


  use RT::KeywordSelects;
  my $KeywordSelects = new RT::KeywordSelects($self->CurrentUser);

  if ($self->CurrentUserHasRight('SeeQueue')) {
      $KeywordSelects->LimitToQueue($self->id);
      $KeywordSelects->IncludeGlobals();
  }
  return ($KeywordSelects);
}
# }}}

# }}}

# {{{ ACCESS CONTROL

# {{{ sub ACL 

=head2 ACL

#Returns an RT::ACL object of ACEs everyone who has anything to do with this queue.

=cut

sub ACL  {
    my $self = shift;
    
    use RT::ACL;
    my $acl = new RT::ACL($self->CurrentUser);
    
    if ($self->CurrentUserHasRight('ShowACL')) {
	$acl->LimitToQueue($self->Id);
    }
    
    return ($acl);
}

# }}}

# {{{ sub _Set
sub _Set {
    my $self = shift;

    unless ($self->CurrentUserHasRight('AdminQueue')) {
	return(0, 'Permission denied');
    }	
    return ($self->SUPER::_Set(@_));
}
# }}}

# {{{ sub _Value

sub _Value {
    my $self = shift;

    unless ($self->CurrentUserHasRight('SeeQueue')) {
	return (undef);
    }

    return ($self->__Value(@_));
}

# }}}

# {{{ sub CurrentUserHasRight

=head2 CurrentUserHasRight

Takes one argument. A textual string with the name of the right we want to check.
Returns true if the current user has that right for this queue.
Returns undef otherwise.

=cut

sub CurrentUserHasRight {
  my $self = shift;
  my $right = shift;

  return ($self->HasRight( Principal=> $self->CurrentUser,
                            Right => "$right"));

}

# }}}

# {{{ sub HasRight

=head2 HasRight

Takes a param hash with the fields 'Right' and 'Principal'.
Principal defaults to the current user.
Returns true if the principal has that right for this queue.
Returns undef otherwise.

=cut

# TAKES: Right and optional "Principal" which defaults to the current user
sub HasRight {
    my $self = shift;
        my %args = ( Right => undef,
                     Principal => $self->CurrentUser,
                     @_);
        unless(defined $args{'Principal'}) {
                $RT::Logger->debug("Principal undefined in Queue::HasRight");

        }
        return($args{'Principal'}->HasQueueRight(QueueObj => $self,
          Right => $args{'Right'}));
}
# }}}

# }}}

1;

# $Header$
# (c) 1996-2000 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL


package RT::User;
use RT::Record;
@ISA= qw(RT::Record);

# {{{ sub _Init
sub _Init  {
    my $self = shift;
    $self->{'table'} = "Users";
    return($self->SUPER::_Init(@_));
}
# }}}

# {{{ sub _Accessible 
sub _Accessible  {
  my $self = shift;
  my %Cols = (
	      # {{{ Core RT info
	      UserId => 'read/write',
	      Password => 'write',
	      Comments => 'read/write',
	      Signature => 'read/write',
	      EmailAddress => 'read/write',
	      FreeformContactInfo => 'read/write',
	      Organization => 'read/write',
	      Disabled => 'read', #To modify this attribute, we have helper
				  #methods
	      Privileged => 'read/write',
	      # }}}
	      
	      # {{{ Names
	      
	      RealName => 'read/write',
	      NickName => 'read/write',
	      # }}}
	      	      
	      # {{{ Localization and Internationalization
	      Lang => 'read/write',
	      EmailEncoding => 'read/write',
	      WebEncoding => 'read/write',
	      # }}}
	      
	      # {{{ External ContactInfo Linkage
	      ExternalContactInfoId => 'read/write',
	      ContactInfoSystem => 'read/write',
	      # }}}
	      
	      # {{{ User Authentication identifier
	      ExternalAuthId => 'read/write',
	      #Authentication system used for user 
	      AuthSystem => 'read/write',
	      Gecos => 'read/write', #Gecos is the name of the fields in a unix passwd file. In this case, it refers to "Unix Username"
	      # }}}
	      
	      # {{{ Telephone numbers
	      HomePhone =>  'read/write',
	      WorkPhone => 'read/write',
	      MobilePhone => 'read/write',
	      PagerPhone => 'read/write',
	      # }}}
	      
	      # {{{ Paper Address
	      Address1 => 'read/write',
	      Address2 => 'read/write',
	      City => 'read/write',
	      State => 'read/write',
	      Zip => 'read/write',
	      Country => 'read/write',
	      # }}}
	      
	      # {{{ Core DBIx::Record Attributes
	      Creator => 'read/auto',
	      Created => 'read/auto',
	      LastUpdatedBy => 'read/auto',
	      LastUpdated => 'read/auto'
	      # }}}
	     );
  return($self->SUPER::_Accessible(@_, %Cols));
}
# }}}

# {{{ sub Create 

sub Create  {
    my $self = shift;
    my %args = (
		Privileged => 0,
		@_ # get the real argumentlist
	       );
    
    #TODO: insert argument list +++
    ##TODO: unless defined $args{'Password'}, make a random password.
    
    #Todo we shouldn't do anything if we have no password to start.
    #return (0,"That password is too short") if length($args{'Password'}) < $RT::user_passwd_min;
    
    #TODO Specify some sensible defaults.
    #TODO check ACLs
    
    my $id = $self->SUPER::Create(%args);
    
    #If the create failed.
    return (undef) if ($id == 0);
    
    $self->Load($id);
    
    #TODO: this is horrificially wasteful. we shouldn't commit 
    # to the db and then instantly turn around and load the same data
    
    
    if ($args{'SendWelcomeMessage'}) {
	#TODO: Check if the email exists and looks valid
	#TODO: Send the user a "welcome message"  see [fsck.com #290]
    }
    
    return ($id);
}

# }}}

# {{{ sub Delete 

#This should probably not ever exist. deleting users 
#would hose the schema.
sub Delete  {
    my $self = shift;
    
    die "User->Delete not implemented";
    
    my $new_owner = shift;
  
    #TODO: check ACLS  
    #TODO: Here, we should take all this admin's tickets that
    #      are stalled or open and reassign them to $new_owner;
    #      additionally, we should nuke this user's acls
    
    
    
    my ($query_string,$update_clause, $user_id);
    
    #TODO Handle User->Delete
    
    $user_id=$self->_Handle->quote($self->UserId);
    
    if ($self->CurrentUser->IsAdministrator) {
	
	if ($self->UserId  ne $self->CurrentUser) {
	    $query_string = "DELETE FROM users WHERE UserId = $user_id";
	    $query_string = "DELETE FROM queue_acl WHERE UserId = $user_id";
	    return ("User deleted.");
	    
	}
	else {
	    return("You may not delete yourself. (Do you know why?)");
	}
    }
    else {
	return("You do not have the privileges to delete that user.");
    }
    
}

# }}}

# {{{ sub Load 

=head2 Load

Load a user object from the database. Takes a single argument.
If the argument is numerical, load by the column 'id'. Otherwise, load by
the "UserId" column which is the user's textual username.

=cut

sub Load  {
    my $self = shift;
    my $identifier = shift || return undef;
    
    #if it's an int, load by id. otherwise, load by name.
    if ($identifier !~ /\D/) {
	$self->SUPER::LoadById($identifier);
    }
    else {
	$self->LoadByCol("UserId",$identifier);
    }
}
# }}}

# {{{ sub LoadByEmail

=head2 LoadByEmail

Tries to load this user object from the database by the user's email address.


=cut

sub LoadByEmail {
    my $self=shift;
    # TODO: check the "AlternateEmails" table if this fails.
    # TODO +++ canonicalize the email address

    return $self->LoadByCol("EmailAddress", @_);
}
# }}}

# {{{ sub IsPassword

=head2 IsPassword

Returns true if the passed in value is this user's password.
Returns undef otherwise.

=cut

sub IsPassword { 
    my $self = shift;
    my $value = shift;
    
    $RT::Logger->debug($self->UserId." attempting to authenticate with password '$value'\n");
    # RT does not allow null passwords 
    if ((!defined ($value)) or ($value eq '')) {
	return(undef);
    } 
    if ($self->Disabled) {
  	$RT::Logger->info("Disabled user ".$self->UserId." tried to log in");
	return(undef);
    }
    if ($value eq $self->_Value('Password')) {
	return (1);
    }
    else {
	return (undef);
    }
}
# }}}

# {{{ sub Disable

=head2 Sub Disable

Disable takes no arguments and returns 1 on success and undef on failure.
It causes this user to have his/her disable flag set.  If this flag is
set, all password checks for this user will fail. All ACL checks for this
user will fail.

=cut 

sub Disable {
    my $self = shift;
    if ($self->CurrentUser->HasSystemRight('AdminUsers')) {
	return($self->_Set(Field => 'Disabled', Value => 1));
    }
}

# }}}

# {{{ sub Enable

=head2 Sub Enable

Disable takes no arguments and returns 1 on success and undef on failure.
It causes this user to have his/her disable flag unset.  see sub Disable
for a fuller treatment of this

=cut 

sub Enable {
    my $self = shift;
    
    if ($self->CurrentUser->HasSystemRight('AdminUsers')) {
	return($self->_Set(Field => 'Disabled', Value => 0));
    }
}

# }}}

# {{{ ACL Related routines

# {{{ GrantQueueRight

=head2 GrantQueueRight

Grant a queue right to this user.  Takes a paramhash of which the elements
RightAppliesTo and RightName are important.

=cut

sub GrantQueueRight {
    
    my $self = shift;
    my %args = ( RightScope => 'Queue',
		 RightName => undef,
		 RightAppliesTo => undef,
		 PrincipalType => 'User',
		 PrincipalId => $self->Id,
		 @_);
   
    require RT::ACE;

    $RT::Logger->debug("$self ->GrantQueueRight right:". $args{'RightName'} .
		       " applies to queue ".$args{'RightAppliesTo'}."\n");
    
    my $ace = new RT::ACE($self->CurrentUser);
    
    return ($ace->Create(%args));
}

# }}}

# {{{ GrantSystemRight

=head2 GrantSystemRight

Grant a system right to this user. 
The only element that's important to set is RightName.

=cut
sub GrantSystemRight {
    
    my $self = shift;
    my %args = ( RightScope => 'System',
		 RightName => undef,
		 RightAppliesTo => 0,
		 PrincipalType => 'User',
		 PrincipalId => $self->Id,
		 @_);
   
    require RT::ACE;
    
    $RT::Logger->debug("$self ->GrantSystemRight ". join(@_)."\n");
    
    my $ace = new RT::ACE($self->CurrentUser);
    
    return ($ace->Create(%args));
}


# }}}

# {{{ sub HasQueueRight

=head2 HasQueueRight

Takes a paramhash which can contain
three items:
    TicketObj => RT::Ticket or QueueObj => RT::Queue
    and Right => 'Right' 


Returns 1 if this user has the right specified in the paramhash. for the queue
passed in.

Returns undef if they don't

=cut

sub HasQueueRight {
    my $self = shift;
    my %args = ( TicketObj => undef,
                 QueueObj => undef,
		 Right => undef,
		 @_);
    
    my ($QueueId);
    
    #Check to make sure that the ticketobj is really a ticketobject	
    if (defined $args{'QueueObj'}) {
        $QueueId = $args{'QueueObj'}->Id;
    } 
    elsif (defined $args{'TicketObj'}) {
        $QueueId = $args{'TicketObj'}->QueueObj->Id,
    }
    else {
	use Carp;
	Carp::Confess();
	$RT::Logger->debug("$self ->HasQueueRight found no valid queue id.");
    }
    
    my $retval = $self->_HasRight(Scope => 'Queue',
				  AppliesTo => $QueueId,
				  Right => "$args{'Right'}");
    if (defined $retval) {
	return ($retval);
    }
    #if they don't have the queue right, see if they have the system right.
    else {
        $retval = $self->HasSystemRight( Right => "$args{'Right'}");
        return ($retval);
    }
    
}

# }}}

# {{{ sub HasSystemRight

=head2 HasSystemRight ( Right => 'right')

Returns 1 if this user has the listed 'right'. Returns undef if this user doesn't.

=cut

sub HasSystemRight {
    my $self = shift;
    my %args = ( Right => 'undef',
		 @_);
    
    if (!defined $args{'Right'}) {
	$RT::Logger->debug("RT::User::HasSystemRight was passed in no right.");
	return(undef);
    }	
    return ( $self->_HasRight ( Scope => 'System',
				AppliesTo => 0,
				Right => $args{'Right'})
	   );
    
}

# }}}

# {{{ sub _HasRight

=head2 sub _HasRight (Right => 'right', Scope => 'scope',  AppliesTo => int,
					  ExtendedPrincipals => SQL)

_HasRight is a private helper method for checking a user's rights. It takes
several options:

=item Right is a textual right name

=item Scope is a textual scope name. (As of July these were Queue, Ticket and System

=item AppliesTo is the numerical Id of the object identified in the scope. For tickets, this is the queue #. for queues, this is the queue #

=item ExtendedPrincipals is an  SQL select clause which assumes that the only
table in play is ACL.  It's used by HasQueueRight to pass in which 
metaprincipals apply. Actually, it's probably obsolete. TODO: remove it.

Returns 1 if a matching ACE was found.

Returns undef if no ACE was found.

=cut


sub _HasRight {
    
    my $self = shift;
    my %args = ( Right => undef,
		 Scope => undef,
		 AppliesTo => undef,
		 ExtendedPrincipals => undef,
		 @_);
    
    if ($self->Disabled) {
	$RT::Logger->debug ("Disabled User:  ".$self->UserId.
			    " failed access check for ".$args{'Right'}.
			    " to object ".$args{'Scope'}."/".
			    $args{'AppliesTo'}."\n");
	return (undef);
    }
    
    if (!defined $args{'Right'}) {
    	$RT::Logger->debug("_HasRight called without a right\n");
    	return(0);
    }
    elsif (!defined $args{'Scope'}) {
    	$RT::Logger->debug("_HasRight called without a scope\n");
    	return(0)
    }
    elsif (!defined $args{'AppliesTo'}) {
    	$RT::Logger->debug("_HasRight called without an AppliesTo object\n");
    	return(0)
    }
    
    #If we've cached a win or loss for this lookup say so
    #TODO Security +++ check to make sure this is complete and right
    
    if (defined ($self->{'rights'}{"$args{'Right'}"}{"$args{'Scope'}"}{"$args{'AppliesTo'}"})) {
	$RT::Logger->debug("Got a cached ACL decision for ". 
			   $args{'Right'}.$args{'Scope'}.
			   $args{'AppliesTo'}."\n");	    
	return ($self->{'rights'}{"$args{'Right'}"}{"$args{'Scope'}"}{"$args{'AppliesTo'}"});
    }
    
    my $RightClause = "(RightName = '$args{'Right'}')";
    my $ScopeClause = "(RightScope = '$args{'Scope'}')";
    
    #If an AppliesTo was passed in, we should pay attention to it.
    #otherwise, none is needed
    
    $ScopeClause = "($ScopeClause AND (RightAppliesTo = $args{'AppliesTo'}))"
      if ($args{'AppliesTo'});
    
    
    # The generic principals clause looks for users with my id
    # and Rights that apply to _everyone_
    my $PrincipalsClause =  "( (PrincipalType = 'Everyone') OR ".
      "((PrincipalType = 'User') AND (PrincipalId = ".$self->Id.")))";
    
    
    # If the user is the superuser, grant them the damn right ;)
    my $SuperUserClause = 
      "(RightName = 'SuperUser') AND ".
	" (RightScope = 'System') AND ".
	  " (RightAppliesTo = 0)";
    
    # If we've been passed in an extended principals clause, we should lump it
    # on to the existing principals clause. it'll make life easier
    if ($args{'ExtendedPrincipals'}) {
	$PrincipalsClause = "(($PrincipalsClause) OR ".
	  "($args{'ExtendedPrincipalsClause'}))";
    }
    
    my $GroupPrincipalsClause = "((PrincipalType = 'Group') AND ".
      "(PrincipalId = GroupMembers.Id) AND ".
	" (GroupMembers.UserId = ".$self->Id."))";
    
    
    # This query checks to se whether the user has the right as a member of a
    # group
    my $query_string_1 = "SELECT COUNT(ACL.id) FROM ACL, GroupMembers WHERE ".
      " (((($ScopeClause) AND ($RightClause)) OR ($SuperUserClause)) ".
	" AND ($GroupPrincipalsClause))";    
    
    
    
    my ($hitcount);
    
    # {{{ deal with checking if the user has a right as a member of a group

    $RT::Logger->debug("Now Trying $query_string_1\n");	
    $hitcount = $self->_Handle->FetchResult($query_string_1);
    
    #if there's a match, the right is granted
    if ($hitcount) {
	$self->{'rights'}{"$args{'Right'}"}{"$args{'Scope'}"}{"$args{'AppliesTo'}"}=1;
	return (1);
    }
    
    $RT::Logger->debug("No ACL matched $query_string_1\n");	
    
    # }}}

    # {{{ Check to see whether the user has a right as an individual
    
    # This query checks to see whether the current user has the right directly
    my $query_string_2 = "SELECT COUNT(ACL.id) FROM ACL WHERE ".
      " (((($ScopeClause) AND ($RightClause)) OR ($SuperUserClause)) " .
	" AND ($PrincipalsClause))";

    
    $hitcount = $self->_Handle->FetchResult($query_string_2);
    
    if ($hitcount) {
	$self->{'rights'}{"$args{'Right'}"}{"$args{'Scope'}"}{"$args{'AppliesTo'}"}=1;
	return (1);
    }
    
    $RT::Logger->debug("No ACL matched $query_string_2\n");

    # }}}


    #If nothing matched, return 0.
    $self->{'rights'}{"$args{'Right'}"}{"$args{'Scope'}"}{"$args{'AppliesTo'}"}= 0;
    
    return (0);
}

# }}}

# }}}
1;
 

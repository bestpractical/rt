# $Header$
# (c) 1996-2000 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL

=head1 NAME

  RT::User - RT User object

=head1 SYNOPSIS

  use RT::User;

=head1 DESCRIPTION


=head1 METHODS

=cut


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
	      UserId => 'public/read/write',
	      Password => 'write',
	      Comments => 'read/write',
	      Signature => 'read/write',
	      EmailAddress => 'public/read/write',
	      FreeformContactInfo => 'read/write',
	      Organization => 'public/read/write',
	      Disabled => 'public/read', #To modify this attribute, we have helper
	      #methods
	      Privileged => 'read/write', # 0=no 1=user 2=system
	      # }}}
	      
	      # {{{ Names
	      
	      RealName => 'public/read/write',
	      NickName => 'public/read/write',
	      # }}}
	      	      
	      # {{{ Localization and Internationalization
	      Lang => 'public/read/write',
	      EmailEncoding => 'public/read/write',
	      WebEncoding => 'public/read/write',
	      # }}}
	      
	      # {{{ External ContactInfo Linkage
	      ExternalContactInfoId => 'public/read/write',
	      ContactInfoSystem => 'public/read/write',
	      # }}}
	      
	      # {{{ User Authentication identifier
	      ExternalAuthId => 'public/read/write',
	      #Authentication system used for user 
	      AuthSystem => 'public/read/write',
	      Gecos => 'public/read/write', #Gecos is the name of the fields in a unix passwd file. In this case, it refers to "Unix Username"
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
    my %args = (Privileged => 0,
		@_ # get the real argumentlist
	       );

    #TODO check for duplicate emails and userid +++

    if (! $args{'Password'})  {
        return(0, "No password set");
    }
    elsif (length($args{'Password'}) < $RT::MinimumPasswordLength) {
        return(0,"Password too short");
    }
    else {
        my $salt = join '', ('.','/',0..9,'A'..'Z','a'..'z')[rand 64, rand 64];
        $args{'Password'} = crypt($args{'Password'}, $salt);     
    }   
        
    #TODO Specify some sensible defaults.
    #TODO check ACLs
    
    my $id = $self->SUPER::Create(%args);
    
    #If the create failed.
    return (undef) if ($id == 0);
    
    #TODO post 2.0
    #if ($args{'SendWelcomeMessage'}) {
    #	#TODO: Check if the email exists and looks valid
    #	#TODO: Send the user a "welcome message"  see [fsck.com #290]
    #}
    
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


# {{{ sub SetPassword

=head2 SetPassword

Takes a string. Checks the string's length and sets this user's password 
to that string.

=cut

sub SetPassword {
    my $self = shift;
    my $password = shift;
    
    unless ($self->CurrentUserCanModify) {
	return(0, 'Permission Denied');
    }
    
    if (! $password)  {
        return(0, "No password set");
    }
    elsif (length($password) < $RT::MinimumPasswordLength) {
        return(0,"Password too short");
    }
    else {
        my $salt = join '', ('.','/',0..9,'A'..'Z','a'..'z')[rand 64, rand 64];
        return ( $self->SUPER::SetPassword(crypt($password, $salt)) );
    }   
    
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
    
    #TODO +++ ACL this

    $RT::Logger->debug($self->UserId." attempting to authenticate with password '$value'\n");
    # RT does not allow null passwords 
    if ((!defined ($value)) or ($value eq '')) {
	return(undef);
    } 
    if ($self->Disabled) {
  	$RT::Logger->info("Disabled user ".$self->UserId." tried to log in");
	return(undef);
    }
    if ($self->__Value('Password') eq crypt($value, $self->__Value('Password'))) {
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

#    $RT::Logger->debug("$self ->GrantQueueRight right:". $args{'RightName'} .
#		       " applies to queue ".$args{'RightAppliesTo'}."\n");
    
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
    
#    $RT::Logger->debug("$self ->GrantSystemRight ". join(@_)."\n");
    
    my $ace = new RT::ACE($self->CurrentUser);
    
    return ($ace->Create(%args));
}


# }}}

# {{{ sub HasQueueRight

=head2 HasQueueRight

Takes a paramhash which can contain
these items:
    TicketObj => RT::Ticket or QueueObj => RT::Queue or Queue => integer
    IsRequestor => undef, (for bootstrapping create)
    Right => 'Right' 


Returns 1 if this user has the right specified in the paramhash. for the queue
passed in.

Returns undef if they don't

=cut

sub HasQueueRight {
    my $self = shift;
    my %args = ( TicketObj => undef,
                 QueueObj => undef,
		 Queue => undef,
		 IsRequestor => undef,
		 Right => undef,
		 @_);
    
    my ($QueueId, $Requestor, $Cc, $AdminCc);
    

    if (defined $args{'Queue'}) {
	$args{'QueueObj'} = new RT::Queue($self->CurrentUser);
	$args{'QueueObj'}->Load($args{'Queue'});
    }


    if (defined $args{'QueueObj'}) {
	$QueueId = $args{'QueueObj'}->Id;
	
	if ($args{'QueueObj'}->IsCc($self)) { #If user is a cc
	    $IsCc = 1;
	}
	if ($args{'QueueObj'}->IsAdminCc($self)) { #If user is an admin cc
	    $IsAdminCc = 1;
	}
	
    } 
    elsif (defined $args{'TicketObj'}) {

	$QueueId = $args{'TicketObj'}->QueueObj->Id;
	

	if ($args{'TicketObj'}->IsRequestor($self)) {#user is requestor
	    $IsRequestor = 1;
	}	
	if ($args{'TicketObj'}->IsCc($self)) { #If user is a cc
	    $IsCc = 1;
	}
	if ($args{'TicketObj'}->IsAdminCc($self)) { #If user is an admin cc
	    $IsAdminCc = 1;
	}	
	
	if ($args{'TicketObj'}->IsOwner($self)) { #If user is an owner
	    $IsOwner = 1;
	}
    }

    else {
    	use Carp;
	Carp::confess();
	$RT::Logger->debug("$self ->HasQueueRight found no valid queue id.");
    }


    #we use this so that "CreateTicket" rights can be granted to the requestor
    if ($args{'IsRequestor'}) {
	$IsRequestor=1;
	$RT::Logger->debug("The user in question is the requestor\n");
	
    }	
    

    
    my $retval = $self->_HasRight(Scope => 'Queue',
				  AppliesTo => $QueueId,
				  Right => $args{'Right'},
				  IsOwner => $IsOwner,
				  IsCc => $IsCc,
				  IsAdminCc => $IsAdminCc,
				  IsRequestor => $IsRequestor
				 );
    if (defined $retval) {
	#	$RT::Logger->debug("Got a return value: $retval\n");
	return ($retval);
    }
    #if they don't have the queue right, see if they have the system right.
    else {
        $retval = $self->HasSystemRight( $args{'Right'},
					 (
					  IsOwner => $IsOwner,
					  IsCc => $IsCc,
					  IsAdminCc => $IsAdminCc,
					  IsRequestor => $IsRequestor
					  )
				       );
        return ($retval);
    }
    
}

# }}}
  
# {{{ sub HasSystemRight

=head2 HasSystemRight

takes an array of a single value and a paramhash.
The single argument is the right being passed in.
the param hash is some additional data. (IsCc, IsOwner, IsAdminCc and IsRequestor)

Returns 1 if this user has the listed 'right'. Returns undef if this user doesn't.

=cut

sub HasSystemRight {
    my $self = shift;
    my $right = shift;

    my %args = ( IsOwner => undef,
		 IsCc => undef,
		 IsAdminCc => undef,
		 IsRequestor => undef,
		 @_);
    
    if (!defined $right) {
	$RT::Logger->debug("RT::User::HasSystemRight was passed in no right.");
	return(undef);
    }	
    return ( $self->_HasRight ( Scope => 'System',
				AppliesTo => '0',
				Right => $right,
				IsOwner => $args{'IsOwner'},
				IsCc => $args{'IsCc'},
				IsAdminCc => $args{'IsAdminCc'},
				IsRequestor => $args{'IsRequestor'},
				
			      )
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
		 IsRequestor => undef,
		 IsCc => undef,
		 IsAdminCc => undef,
		 IsOwner => undef,
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
    	return(undef);
    }
    elsif (!defined $args{'Scope'}) {
    	$RT::Logger->debug("_HasRight called without a scope\n");
    	return(undef);
    }
    elsif (!defined $args{'AppliesTo'}) {
        use Carp;
        $RT::Logger->debug(Carp::cluck."\n");
    	$RT::Logger->debug("_HasRight called without an AppliesTo object\n");
    	return(undef);
    }
    
    #If we've cached a win or loss for this lookup say so
    
    #TODO Security +++ check to make sure this is complete and right
    
    #Construct a hashkey to cache decisions in
    my ($hashkey);
    { #it's ugly, but we need to turn off warning, cuz we're joining nulls.
	local $^W=0;
	$hashkey =join(':',%args);
	#    my $hashkey = "Right:".$args{'Right'}."-".
	#      "AppliesTo:".$args{'AppliesTo'} ."-".
	#	"Scope:".$args{'Scope'};
    }	
    
  # $RT::Logger->debug($hashkey."\n");
    
    #Anything older than two minutes needs to be rechecked
    my $cache_timeout = (time - 120);
    
    
    if ((defined $self->{'rights'}{"$hashkey"}) &&
	    ($self->{'rights'}{"$hashkey"} == 1 ) &&
        (defined $self->{'rights'}{"$hashkey"}{'set'} ) &&
	    ($self->{'rights'}{"$hashkey"}{'set'} > $cache_timeout)) {
	#  $RT::Logger->debug("Got a cached positive ACL decision for ". 
	#			       $args{'Right'}.$args{'Scope'}.
	#		       $args{'AppliesTo'}."\n");	    
	return ($self->{'rights'}{"$hashkey"});
    }
    elsif ((defined $self->{'rights'}{"$hashkey"}) &&
	       ($self->{'rights'}{"$hashkey"} == -1)  &&
           (defined $self->{'rights'}{"$hashkey"}{'set'}) &&
	       ($self->{'rights'}{"$hashkey"}{'set'} > $cache_timeout)) {
	
	#   $RT::Logger->debug("Got a cached negative ACL decision for ". 
	#		       $args{'Right'}.$args{'Scope'}.
	#	       $args{'AppliesTo'}."\n");	    
	
	return(undef);
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
    
    


    # {{{ A bunch of magic statements that make the metagroups listed
    # work. basically, we if the user falls into the right group,
    # we add the type of ACL check needed
    my (@MetaPrincipalsSubClauses, $MetaPrincipalsClause);
    

    if ($args{'IsAdminCc'}) {
	push (@MetaPrincipalsSubClauses,  "((Groups.Name = 'AdminCc') AND 
                                       (PrincipalType = 'Group') AND 
                                       (Groups.Id = PrincipalId))");
    }
    if ($args{'IsCc'}) {
	push (@MetaPrincipalsSubClauses, " ((Groups.Name = 'Cc') AND 
                                       (PrincipalType = 'Group') AND 
                                       (Groups.Id = PrincipalId))");
    }
    if ($args{'IsRequestor'}) {
	push (@MetaPrincipalsSubClauses,  " ((Groups.Name = 'Requestor') AND 
                                       (PrincipalType = 'Group') AND 
                                       (Groups.Id = PrincipalId))");
    }
    if ($args{'IsOwner'}) {
	
	push (@MetaPrincipalsSubClauses, " ((Groups.Name = 'Owner') AND 
                                       (PrincipalType = 'Group') AND 
                                       (Groups.Id = PrincipalId))");
    }

    # }}}

    my ($GroupRightsQuery, $MetaGroupRightsQuery, $IndividualRightsQuery, $hitcount);

    # {{{ If there are any metaprincipals to be checked
    if (@MetaPrincipalsSubClauses) {
	#chop off the leading or
	#TODO redo this with an array and a join
	$MetaPrincipalsClause = join (" OR ", @MetaPrincipalsSubClauses);
	
	$MetaGroupRightsQuery =  "SELECT COUNT(ACL.id) FROM ACL, Groups".
	  " WHERE " .
	    " ($ScopeClause) AND ($RightClause) AND ($MetaPrincipalsClause)";
	
	# {{{ deal with checking if the user has a right as a member of a metagroup
    
    #  $RT::Logger->debug("Now Trying $GroupRightsQuery\n");	
    $hitcount = $self->_Handle->FetchResult($MetaGroupRightsQuery);
    
    #if there's a match, the right is granted
    if ($hitcount) {
	$self->{'rights'}{"$hashkey"}{'set'} = time;
	$self->{'rights'}{"$hashkey"} = 1;
	return (1);
    }
    
    #$RT::Logger->debug("No ACL matched $MetaGroupRightsQuery\n");	
    
    # }}}    
	
    }
    # }}}

    # {{{ deal with checking if the user has a right as a member of a group
    # This query checks to se whether the user has the right as a member of a
    # group
    $GroupRightsQuery = "SELECT COUNT(ACL.id) FROM ACL, GroupMembers, Groups".
      " WHERE " .
	" (((($ScopeClause) AND ($RightClause)) OR ($SuperUserClause)) ".
	  " AND ($GroupPrincipalsClause))";    
    
    #  $RT::Logger->debug("Now Trying $GroupRightsQuery\n");	
    $hitcount = $self->_Handle->FetchResult($GroupRightsQuery);
    
    #if there's a match, the right is granted
    if ($hitcount) {
	$self->{'rights'}{"$hashkey"}{'set'} = time;
	$self->{'rights'}{"$hashkey"} = 1;
	return (1);
    }
    
    #$RT::Logger->debug("No ACL matched $GroupRightsQuery\n");	
    
    # }}}

    # {{{ Check to see whether the user has a right as an individual
    
    # This query checks to see whether the current user has the right directly
    $IndividualRightsQuery = "SELECT COUNT(ACL.id) FROM ACL WHERE ".
      " ((($ScopeClause) AND ($RightClause)) OR ($SuperUserClause)) " .
	" AND ($PrincipalsClause)";

    
    $hitcount = $self->_Handle->FetchResult($IndividualRightsQuery);
    
    if ($hitcount) {
	$self->{'rights'}{"$hashkey"}{'set'} = time;
	$self->{'rights'}{"$hashkey"} = 1;
	return (1);
    }
    # }}}

    else { #If the user just doesn't have the right
	
	#$RT::Logger->debug("No ACL matched $IndividualRightsQuery\n");
	
	#If nothing matched, return 0.
	$self->{'rights'}{"$hashkey"}{'set'} = time;
	$self->{'rights'}{"$hashkey"} = -1;

	
	return (undef);
    }
}

# }}}

# {{{ sub CurrentUserCanModify

=head2 CurrentUserCanModify

If the user has rights for this object, either because
he has 'AdminUsers' or (if he's trying to edit himself) 'ModifySelf',
return 1. otherwise, return undef.

=cut

sub CurrentUserCanModify {
    my $self = shift;
    my $right = shift;

    if ($self->CurrentUser->HasSystemRight('AdminUsers')) {
	return (1);
    }
    #If the current user is trying to modify themselves
    elsif ( ($self->id == $self->CurrentUser->id)  and
	    ($self->CurrentUser->HasSystemRight('ModifySelf'))) {
	

	return(1);
    }
    else {
	return(undef);
    }	
    
}


# }}}

# {{{ sub CurrentUserHasSystemRight

=head2
  
  Takes a single argument. returns 1 if $Self->CurrentUser
  has the requested right. returns undef otherwise

=cut

sub CurrentUserHasRight {
    my $self = shift;
    my $right = shift;
    
    return ($self->CurrentUser->HasSystemRight($right));
}

# }}}


# {{{ sub _Set

sub _Set {
  my $self = shift;
  
  my %args = (Field => undef,
	      Value => undef,
	      @_
	     );

  unless ($self->CurrentUserCanModify) {
      return (0, "Permission Denied");
  }
  
  #Set the new value
  my ($ret, $msg)=$self->SUPER::_Set(Field => $args{'Field'}, 
				     Value=> $args{'Value'});
  
    return ($ret, $msg);
}

# }}}

# {{{ sub _Value 

=head2 _Value

Takes the name of a table column.
Returns its value as a string, if the user passes an ACL check

=cut

sub _Value  {

  my $self = shift;
  my $field = shift;
  
  #If the current user doesn't have ACLs, don't let em at it.  
  
  my @PublicFields = qw( UserId EmailAddress Organization Disabled
			 RealName NickName Gecos ExternalAuthId 
			 AuthSystem ExternalContactInfoId 
			 ContactInfoSystem );

  #if the field is public, return it.
  if ($self->_Accessible($field, 'public')) {
      return($self->SUPER::_Value($field));
      
  }
  #If the user has admin users, return the field
  elsif ($self->CurrentUserHasRight('AdminUsers')) {
      return($self->SUPER::_Value($field));
  }
  #If the user wants to see their own values, let them
  
  elsif ($self->CurrentUser->Id == $self->Id) {	
      return($self->SUPER::_Value($field));
  }

}
  
# }}}

# }}}
1;
 

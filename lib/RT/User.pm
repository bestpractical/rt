# $Header$
# (c) 1996-1999 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL
#


package RT::User;
use RT::Record;
@ISA= qw(RT::Record);

# {{{ sub new 
sub new  {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $self->{'table'} = "Users";
  $self->_Init(@_);

  return($self);
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
	      CanManipulate => 'read/write',
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
  my %args = (#TODO: insert argument list 
	      @_ # get the real argumentlist
	     );
  
  
  #Todo we shouldn't do anything if we have no password to start.
  #return (0,"That password is too short") if length($args{'Password'}) < $RT::user_passwd_min;
  
  #TODO Specify some sensible defaults.
  #TODO check ACLs

  my $id = $self->SUPER::Create(%args);
  $self->Load($id);
  
  #TODO: this is horrificially wasteful. we shouldn't commit 
  # to the db and then instantly turn around and load the same data
  
  #TODO: send a welcome message to the user if they should 
  # get mail and we should send welcome messages at all
  #TODO: Send the user a "welcome message"  see [fsck.com #290]


  return (1,"User created");
}
# }}}

# {{{ sub Delete 
sub Delete  {
  my $self = shift;

  my $new_owner = shift;

  #TODO: check ACLS  
  #TODO: Here, we should take all this admin's tickets that
  #      are stalled or open and reassign them to $new_owner;
  #      additionally, we should nuke this user's acls



  my ($query_string,$update_clause, $user_id);
  
  #TODO Handle User->Delete
  die "User->Delete not implemented";
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
sub LoadByEmail {
    my $self=shift;
    # TODO: check the "AlternateEmails" table if this fails.
    return $self->LoadByCol("EmailAddress", @_);
}
# }}}

#used to check if a password is correct
# {{{ sub IsPassword

sub IsPassword { 
  my $self = shift;
  my $value = shift;
  if ($value == $self->_Value('Password')) {
    return (1);
  }
  else {
    return (undef);
  }
}
# }}}

# {{{ sub DisplayPermitted 
sub DisplayPermitted  {
  my $self = shift;
  #TODO: Implement
  return(1);
}
# }}}

# {{{ sub ModifyPermitted 
sub ModifyPermitted  {
  my $self = shift;
  #TODO: Implement
  return(1);
}
# }}}

# {{{ sub Signature 
sub Signature {
    my $self=shift;
    return ($self->SUPER::Signature);
    
    ## TODO: The stuff below might be a nice feature, but since we don't need it
    ## at the moment, it's left out.

    if (0) {
	my @entry=getpwnam($self->Gecos || $self->UserId);
	my $home=$entry[7];
## TODO: Check if the commented out line might work better
#       for my $trythis (@RT::signature) {
	for my $trythis ("$home/.signature", "$home/pc/sign.txt", "$home/pc/sign") {
	    if (-r $trythis) {
		local($/);
		undef $/;
		open(SIGNATURE, "<$trythis"); 
		$signature=<SIGNATURE>;
		close(SIGNATURE);
		return $signature;
	    }
	}
	return undef;
    }
}
# }}}


# {{{ sub HasSystemRight
sub HasSystemRight {
  my $self = shift;
  my $right = shift;

  my $RightClause = "(Right = '$right') OR (Right = 'SuperUser')";
  my $ScopeClause = "(Scope = 'System')";
  my $PrincipalsClause =   "(PrincipalType = 'User') AND ((PrincipalId = $actor) OR (PrincipalId = 0))";
    
  $GroupPrincipalsClause = "((PrincipalType = 'Group') AND (PrincipalId = GroupMembers.Id) AND (GroupMembers.UserId = $actor))";
  
  my $query_string_1 = "SELECT COUNT(ACL.id) FROM ACL, GroupMembers WHERE (($ScopeClause) AND ($RightClause) AND ($GroupPrincipalsClause))";    
  
  my $query_string_2 = "SELECT COUNT(ACL.id) FROM ACL WHERE (($ScopeClause) AND ($RightClause) AND ($PrincipalsClause))";
  
  my ($hitcount);
  
  $hitcount = $self->{'DBIxHandle'}->FetchResult($query_string_1);
  
  #if there's a match, the right is granted
  return (1) if ($hitcount);
  
  $hitcount = $self->{'DBIxHandle'}->FetchResult($query_string_2);
  return (1) if ($hitcount);
  
  return(0);
}

# }}}

1;
 

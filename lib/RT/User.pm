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
	      UserId => 'read/write',
	      Gecos => 'read/write',
	      RealName => 'read/write',
	      Password => 'write',
	      ExternalId => 'read/write',
	      EmailAddress => 'read/write',
	      HomePhone => 'read/write',
	      WorkPhone => 'read/write',
	      Address1 => 'read/write',
	      Address2 => 'read/write',
	      City => 'read/write',
	      State => 'read/write',
	      Zip => 'read/write',
	      Country => 'read/write',
	      Comments => 'read/write',
	      CanManipulate => 'read/write',
	      IsAdministrator => 'read/write',
	      Creator => 'read/auto',
	      Created => 'read/auto',
	      LastUpdatedBy => 'read/auto',
	      LastUpdated => 'read/auto'
	     );
  return($self->SUPER::_Accessible(@_, %Cols));
}
# }}}

# {{{ sub Create 
sub Create  {
  my $self = shift;
  my %args = (
	      UserId => undef,
	      Password => undef,
	      Gecos => undef,
	      RealName => undef,
	      Password => undef,
	      ExternalId => undef,
	      
	      EmailAddress => undef,
	      HomePhone => undef,
	      WorkPhone => undef,
	      Address1 => undef,
	      Address2 => undef,
	      City => undef,
	      State => undef,
	      Zip => undef,
	      Country => undef,
	      Comments => undef,
	      CanManipulate => undef,
	      IsAdministrator => undef,
	      @_ # get the real argumentlist
	     );
  
  
  #Todo we shouldn't do anything if we have no password to start.
  #return (0,"That password is too short") if length($args{'Password'}) < $RT::user_passwd_min;
  
  my $id = $self->SUPER::Create(%args);
  $self->Load($id);
  
  #TODO: this is horrificially wasteful. we shouldn't commit 
  # to the db and then instantly turn around and load the same data
  
  return (1,"User created");
}
# }}}

# {{{ sub Delete 
sub Delete  {
  my $self = shift;
  my $new_owner = shift;
  
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

sub LoadByEmail {
    my $self=shift;
    # TODO: check the "AlternateEmails" table first.
    return $self->LoadByCol("EmailAddress", @_);
}

#used to check if a password is correct
# {{{ sub IsPassword

sub IsPassword { 
  my $self = shift;
  my $value = shift;
  if ($value = $self->_Value('Password')) {
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

1;
 

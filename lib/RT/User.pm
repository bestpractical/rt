# $Header$
# (c) 1996-1999 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL
#


package RT::User;
use RT::Record;
@ISA= qw(RT::Record);

sub new {
  print STDERR "entering new User\n";
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $self->{'table'} = "users";
  $self->{'user'} = shift;
  
  $self->_init(@_);

  return($self);
}

sub create {
  my $self = shift;
  my %args = (
	      UserId => undef,
	      Password => undef,
	      EmailAddress => undef,
	      Phone => undef,
	      Office => undef, 
	      Comments => undef,
	      IsAdministrator => '0',
	      @_ # get the real argumentlist
	     );
  
  
  
  return (0,"That password is too short") if length($args{'Password'}) < $RT::user_passwd_min;
  
  my $id = $self->SUPER::Create(%args);
  $self->load_by_reference($id);

  #TODO: this is horrificially wasteful. we shouldn't commit 
  # to the db and then instantly turn around and load the same data
  
  #sub create is handled by the baseclass. we should be calling it like this:
  #$id = $article->create( title => "This is a a title",
  #		  mimetype => "text/plain",
  #		  author => "jesse@arepa.com",
  #		  summary => "this article explains how to from a widget",
  #		  content => "lots and lots of content goes here. it doesn't 
  #                              need to be preqoted");
  # TODO: created is not autoset
  

}
 
sub delete {
  my $self = shift;
  my $new_owner = shift;
  
  #TODO: Here, we should take all this admin's tickets that
  #      are stalled or open and reassign them to $new_owner;
  #      additionally, we should nuke this user's acls

  

  my ($query_string,$update_clause, $user_id);
  
  
  
  $user_id=$self->_Handle->quote($self->UserId);
  
  if ($self->CurrentUser->IsAdministrator) {
    
    if ($self->UserId  ne $self->CurrentUser) {
      $query_string = "DELETE FROM users WHERE UserId = $user_id";
      $sth = $self->_Handle->prepare($query_string) or 
	return ("[delete_user] prepare had some problem: $self->_Handle->errstr\n$query_string\n");
      $sth->execute or 
	return ("[delete_user] execute had some problem: $self->_Handle->errstr\n$query_string\n");
      $query_string = "DELETE FROM queue_acl WHERE UserId = $user_id";
      $sth = $self->_Handle->prepare($query_string) or 
	return ("[delete_user] Query had some problem: $self->_Handle->errstr\n$query_string\n");
      $sth->execute or
	return ("[delete_user] Query had some problem: $self->_Handle->errstr\n$query_string\n");  
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

sub load {
  my $self = shift;
  my $identifier = shift;
  #TODO i'm blanking on the is an int function
  if ($identifier eq int($identifier)) {
    $self->SUPER::load($identifier);
  }
  else {
    print STDERR "loading UserId = $identifier \n";
    $self->LoadByCol("UserId",$identifier);
  }
}

sub UserId { 
  my $self = shift;
  $self->_set_and_return('UserId',@_);
 }
sub Password { 
my $self = shift;
  $self->_set_and_return('Password',@_);

}
sub RealName { 
my $self = shift;
  $self->_set_and_return('RealName',@_);

}

#used to check if a password is correct
sub IsPassword { 
  my $self = shift;
  my $value = shift;
  if ($value = $self->Password) {
    return (1);
  }
  else {
    return (undef);
  }
}

sub EmailAddress { 
my $self = shift;
  $self->_set_and_return('EmailAddress',@_);

}
sub Phone  { 
my $self = shift;
  $self->_set_and_return('Phone',@_);

}
sub Office { 
my $self = shift;
  $self->_set_and_return('Office',@_);

}
sub Comments {
  my $self = shift;
  $self->_set_and_return('Comments',@_);

}
sub IsAdministrator {
  my $self = shift;
  #todo validate input
  
  $self->_set_and_return('IsAdministrator',@_);
};


sub DisplayPermitted {
  my $self = shift;
  #TODO: Implement
  return(1);
}

sub ModifyPermitted {
  my $self = shift;
  #TODO: Implement
  return(1);
}

1;
 

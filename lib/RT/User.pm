# $Header$
# (c) 1996-1999 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL
#


package RT::User;
use RT::Record;
@ISA= qw(RT::Record);



sub new {
    my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $self->{'table'} = "users";
  $self->{'user'} = shift;
  
  $self->_init(@_);

  return($self);
}
sub _Accessible {
  my $self = shift;  
  my %Cols = (
	     UserId => 'read/write',
	     Gecos => 'read/write',
	     RealName=> 'read/write',
	     Password=> 'write',
	     EmailAddress=> 'read/write',
	     Phone=> 'read/write',
	     Office=> 'read/write',
	     Comments=> 'read/write',
	     IsAdministrator => 'read/write'
	    );
  return($self->SUPER::_Accessible(@_, %Cols));
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

sub Load {
  my $self = shift;
  return ($self->load(@_));
}
sub load {
  my $self = shift;
  my $identifier = shift;

  #if it's an int, load by id. otherwise, load by name.
  if ($identifier !~ /\D/) {
    $self->SUPER::load($identifier);
  }
  else {

   $self->LoadByCol("UserId",$identifier);
  }
}

#used to check if a password is correct
sub IsPassword { 
  my $self = shift;
  my $value = shift;
  if ($value = $self->_Get('Password')) {
    return (1);
  }
  else {
    return (undef);
  }
}

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
 

# $Header$
# (c) 1996-1999 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL
#


package RT::Watcher;
use RT::Record;
@ISA= qw(RT::Record);



# {{{ sub new 
sub new  {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $self->{'table'} = "Watchers";
  $self->_Init(@_);

  return($self);
}
# }}}

# {{{ sub Create 
sub Create  {
  my $self = shift;
  my %args = (
	      Email => undef,
	      Value => undef,
	      Scope => undef,
	      Type => undef,
	      Owner => 0,
	      Quiet => 0,
	      @_ # get the real argumentlist
	     );
  
  

  my $id = $self->SUPER::Create(%args);
  $self->Load($id);
  
  #TODO: this is horrificially wasteful. we shouldn't commit 
  # to the db and then instantly turn around and load the same data
  
  return (1,"Interest noted");
}
# }}}
 
# {{{ sub Load 
sub Load  {
  my $self = shift;
  my $identifier = shift;
  
  if ($identifier !~ /\D/) {
    $self->SUPER::LoadById($identifier);
  }
  else {
	return (0, "That's not a numerical id");
  }
}
# }}}

# {{{ sub UserObj 
sub UserObj  {
  my $self = shift;
  if (!defined $self->{'UserObj'}) {
    require RT::User;
    $self->{'UserObj'} = new RT::User($self->CurrentUser);
    #If we don't have an Email attribute, load the Owner Object
    
    if (!defined($self->SUPER::Email)) { #the SUPER is so we don't get in a loop
                                         #with $self->Email
      $self->{'UserObj'}->Load($self->Owner);
    }
    else {
      $self->{'UserObj'}->Load($self->Email);
    }
  }
  return ($self->{'UserObj'});
}
# }}}

# {{{ sub OwnerObj
sub OwnerObj {
  my $self = shift;
  return ($self->UserObj);
}
# }}}

# {{{ sub Email
sub Email {
  my $self = shift;

  # IF Email is defined, return that. Otherwise, return the Owner's email address
  if (defined($self->SUPER::Email)) {
    return ($self->SUPER::Email);
  }
  else {
    return ($self->{'OwnerObj'}->EmailAddress);
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

# {{{ sub _Accessible 
sub _Accessible  {
  my $self = shift;
  my %Cols = (
	      Email => 'read/write',
	      Scope => 'read/write',
	      Value => 'read/write',
	      Type => 'read/write',
	      Quiet => 'read/write',
	      Owner => 'read/write'	      
	     );
  return($self->SUPER::_Accessible(@_, %Cols));
}
# }}}

1;
 

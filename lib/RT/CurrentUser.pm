# $Header$
# (c) 1996-1999 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL
#


package RT::CurrentUser;
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

#The basic idea here is that $self->CurrentUser is always supposed
# to be a CurrentUser object. but that's hard to do when we're trying to load
# the CurrentUser object
# {{{ sub _Init 
sub _Init  {
  my $self = shift;
  my $UserId = shift;
  $self->_MyHandle;
  if (defined($UserId)) {
    $self->Load($UserId);
  }
  $self->_MyCurrentUser($self);
  
}
# }}}

# {{{ sub _Accessible 
sub _Accessible  {
  my $self = shift;
  my %Cols = (
	      UserId => 'read',
	      Gecos => 'read',
	      RealName => 'read',
	      Password => 'write',
	      EmailAddress => 'read',
	      CanManipulate => 'read',
	      IsAdministrator => 'read'
	     );
  return($self->SUPER::_Accessible(@_, %Cols));
}
# }}}

# {{{ sub Load 
sub Load  {
  my $self = shift;
  my $identifier = shift;

  #if it's an int, load by id. otherwise, load by name.
  if ($identifier !~ /\D/) {
    $self->SUPER::LoadById($identifier);
  }
  elsif ($identifier =~ /\@/) {
    $self->LoadByCol("EmailAddress",$identifier);
  }
  else {
    $self->LoadByCol("UserId",$identifier);
  }
}
# }}}

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
 

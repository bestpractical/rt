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
  if (defined($UserId)) {
    $self->Load($UserId);
  }
  $self->_MyCurrentUser($self);
  
}
# }}}

# {{{ sub UserObj
sub UserObj {
  my $self = shift;
  
  unless ($self->{'UserObj'}) {
    $self->{'UserObj'} = RT::User->new($self);
    $self->{'UserObj'}->Load($self->Id)
      || die "Couldn't find myself in the user db?";
  }
  return ($self->{'UserObj'});
}
# }}}

# {{{ sub _Accessible 
sub _Accessible  {
  my $self = shift;
  my %Cols = (
	      UserId => 'read',
	      Gecos => 'read',
	      RealName => 'read',
	      Password => 'neither',
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
    # This is a bit dangerous, we might get false authen if somebody
    # uses ambigous userids or real names:
    $self->LoadByCol("UserId",$identifier);
  }
}
# }}}


# {{{ sub IsPassword

=head2 IsPassword

Takes a password as a string.  Passes it off to IsPassword in this
user's UserObj.  If it is the user's password and the user isn't
disabled, returns 1.

Otherwise, returns undef.

=cut

sub IsPassword { 
  my $self = shift;
  my $value = shift;
  
  return ($self->UserObj->IsPassword($value)); 
}
# }}}

# {{{ Convenient ACL methods

=head2 HasTicketRight

calls $self->UserObj->HasTicketRight with the arguments passed in

=cut

sub HasTicketRight {
	my $self = shift;
	return ($self->UserObj->HasTicketRight(@_));
}




=head2 HasQueueRight

calls $self->UserObj->HasQueueRight with the arguments passed in

=cut

sub HasQueueRight {
	my $self = shift;
	return ($self->UserObj->HasQueueRight(@_));
}

=head2 HasSystemRight

calls $self->UserObj->HasSystemRight with the arguments passed in

=cut


sub HasSystemRight {
	my $self = shift;
	return ($self->UserObj->HasSystemRight(@_));
}
# }}}

# {{{ sub HasRight
sub HasRight {
  my $self = shift;
  my %args = ( Scope => undef,
	       AppliesTo => undef,
	       Right => undef,
	       @_);
  # TODO: Something is obviously missing here.
  return 1;
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
 

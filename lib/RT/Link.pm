# $Header$
# (c) 1996-1999 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL
#


package RT::Link;
use RT::Record;
@ISA= qw(RT::Record);



# {{{ sub new 
sub new  {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $self->{'table'} = "Link";
  $self->_Init(@_);

  return($self);
}
# }}}

# {{{ sub Create 
sub Create  {
  my $self = shift;
  my %args = (
	      Base => undef,
	      Target => undef,
	      Type => undef,
	      @_ # get the real argumentlist
	     );
  
  

  my $id = $self->SUPER::Create(%args);
  $self->Load($id);
  
  #TODO: this is horrificially wasteful. we shouldn't commit 
  # to the db and then instantly turn around and load the same data
  
  return (1,"Link created");
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

# {{{ sub _Accessible 
sub _Accessible  {
  my $self = shift;
  my %Cols = (
	      Base => 'read/write',
	      Target => 'read/write',
	      Type => 'read/write',
	     );
  return($self->SUPER::_Accessible(@_, %Cols));
}
# }}}

1;
 

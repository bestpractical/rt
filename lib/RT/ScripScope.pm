#$Header$

package RT::ScripScope;
use RT::Record;
@ISA= qw(RT::Record);

# {{{ sub new 
sub new  {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $self->{'table'} = "ScripScope";
  $self->_Init(@_);
  return ($self);
}
# }}}

# {{{ sub _Accessible 
sub _Accessible  {
  my $self = shift;
  my %Cols = ( Scrip  => 'read/write',
	    	Queue => 'read/write', 
	  	Template => 'read/write',
	     );
  return($self->SUPER::_Accessible(@_, %Cols));
}
# }}}

# {{{ sub Create 
sub Create  {
  my $self = shift;
  die "RT::Scrip->create stubbed\n";
  my $id = $self->SUPER::Create(Name => @_);
  $self->LoadById($id);
  
}
# }}}


# {{{ sub delete 
sub delete  {
  my $self = shift;
  my ($query_string,$update_clause);
  
  die ("ScripScope->Delete not implemented yet");
}
# }}}


# {{{ sub Load 
sub Load  {
  my $self = shift;
  
  my $identifier = shift;
  if (!$identifier) {
    return (undef);
  }	    

  if ($identifier !~ /\D/) {
    $self->SUPER::LoadById($identifier);
  }
  else {
    die "This code is never reached ;)";  
  }

  $self
  
 
}
# }}}



# {{{ sub ScripObj
sub ScripObj {
  my $self = shift;
  if (!$self->{'ScripObj'})  {
    require RT::Scrip;
    $self->{'ScripObj'} = RT::ScripObj->new($self->CurrentUser);
    $self->{'ScripObj'}->load($self->_Value('Scrip'), $self->_Value('Template'));
  }
  return ($self->{'ScripObj'});
}

# }}}
#
# ACCESS CONTROL
# 

# {{{ sub DisplayPermitted 
sub DisplayPermitted  {
  my $self = shift;

  my $actor = shift;
  if (!$actor) {
   my $actor = $self->CurrentUser;
 }
#  if ($self->Queue->DisplayPermitted($actor)) {
 if (1){   
    return(1);
  }
  else {
    #if it's not permitted,
    return(0);
  }
}
# }}}
# {{{ sub ModifyPermitted 
sub ModifyPermitted  {
  my $self = shift;
  my $actor = shift;
  if (!$actor) {
    my $actor = $self->CurrentUser;
  }
#  if ($self->Queue->ModifyPermitted($actor)) {
 if (1) {   
    return(1);
  }
  else {
    #if it's not permitted,
    return(0);
  }
}
# }}}

# {{{ sub AdminPermitted 
sub AdminPermitted  {
  my $self = shift;
  my $actor = shift;
  if (!$actor) {
    my $actor = $self->CurrentUser;
  }


#  if ($self->ACL->AdminPermitted($actor)) {
 if (1) {   
    return(1);
  }
  else {
    #if it's not permitted,
    return(0);
  }
}
# }}}


1;



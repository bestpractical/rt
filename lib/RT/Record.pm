#$Header$

package RT::Record;
use DBIx::Record;
@ISA= qw(DBIx::Record);

# {{{ sub new 

sub new  {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  return $self;
}

# }}}

# {{{ sub _Init 

sub _Init  {
  my $self = shift;
  $self->_Handle();
  $self->_MyCurrentUser(@_);
  
}

# }}}

# {{{ sub _MyCurrentUser 

sub _MyCurrentUser  {
  my $self = shift;
  
  $self->{'user'} = shift;
  
  if(!defined($self->CurrentUser)) {
    my ($package, $filename, $line) = caller;
    return(0);
  }
}

# }}}

# {{{ sub _Handle 
sub _Handle  {
  my $self = shift;
  $self->SUPER::_Handle( $RT::Handle );
}
# }}}

# {{{ sub Create 
sub Create  {
  my $self = shift;
  push @_, 'Creator', $self->{'user'}->id
	if $self->_Accessible('Creator', 'auto');
  #  print STDERR "In RT::Record->create\n";
  my $id = $self->SUPER::Create(@_);
  #  print STDERR "RT::Record->create Loading by Ref $id\n";
  return($id);

}
# }}}



# {{{ sub _Set 
sub _Set  {
  my $self = shift;
  my $field = shift;
  #if the user is trying to modify the record
  
  $self->SUPER::_Set('LastUpdatedBy', $self->{'user'}->id)
    if ($self->_Accessible('LastUpdatedBy','auto'));
  $self->SUPER::_Set($field, @_);
  
  
}
# }}}

# {{{ sub Creator 
sub Creator  {
  my $self = shift;
  if (!$self->{'creator'}) {
    use RT::User;
    $self->{'creator'} = RT::User->new($self->CurrentUser);
    $self->{'creator'}->Load($self->_Value('Creator'));
  }
  return($self->{'creator'});
}
# }}}

# {{{ sub CurrentUser 
sub CurrentUser  {
  my $self = shift;
  return ($self->{'user'});
}
# }}}


1;

#$Header$

package RT::Record;
use DBIx::Record;
@ISA= qw(DBIx::Record);

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  return $self;
}

sub _Init {
  my $self = shift;
  $self->_MyHandle();
  $self->_MyCurrentUser(@_);
  
}


sub _MyCurrentUser {
  my $self = shift;
  $self->{'user'} = shift;
  
  if(!defined($self->CurrentUser)) {
    my ($package, $filename, $line) = caller;
    
    return(0);
  }
}

sub _MyHandle {
  my $self = shift;
  
  $self->SUPER::_MyHandle( 'Handle' => $RT::Handle );
}

sub Create {
  my $self = shift;
  my @args = (Creator => $self->CurrentUser->Id,
	      @_);
  #  print STDERR "In RT::Record->create\n";
  my $id = $self->SUPER::Create(@args);
  #  print STDERR "RT::Record->create Loading by Ref $id\n";
  return($id);

}


sub _Value {

  my $self = shift;
  my $field = shift;
  my ($package, $filename, $line) = caller;
#  print STDERR "DBIx::Record->_Value called from $package, line $line with arguments (",@_,")\n";
#  print STDERR "Determining value of $field\n";
  #if the user is trying to display only {
  if ($self->DisplayPermitted) {
    #if the user doesn't have display permission, return an error
    return($self->SUPER::_Value($field));
  }
  else {
    return(0, "Permission Denied");
  }
}

sub _Set {
  my $self = shift;
  my $field = shift;
  #if the user is trying to modify the record
  if ($self->ModifyPermitted) {
    $self->SUPER::_Set($field, @_);
  }
  else {
    return (0, "Permission Denied");
  }
  
}

sub Creator {
  my $self = shift;
  if (!$self->{'creator'}) {
    use RT::User;
    $self->{'creator'} = RT::User->new($self->CurrentUser);
    $self->{'creator'}->Load($self->_Value('Creator'));
  }
  return($self->{'creator'});
}

sub CurrentUser {
  my $self = shift;
  return ($self->{'user'});
}
    

1;



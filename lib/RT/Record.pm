#$Header$

package RT::Record;
use DBIx::Record;
@ISA= qw(DBIx::Record);

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  #  $self->{'table'} = "each_req";
  #$self->{'user'} = shift;
  return $self;
}


sub Create {
  my $self = shift;
  print STDERR "In RT::Record->create\n";
  my $id = $self->SUPER::Create(@_);
  print STDERR "RT::Record->create Loading by Ref $id\n";
  return($id);

}


sub _set_and_return {
  my $self = shift;
  my $field = shift;
  #if the user is trying to display only {
  if (@_ == undef) {
    
    if ($self->DisplayPermitted) {
      #if the user doesn't have display permission, return an error
      $self->SUPER::_set_and_return($field);
    }
    else {
      return(0, "Permission Denied");
    }
  }
  #if the user is trying to modify the record
  else {
    if ($self->ModifyPermitted) {
      #instantiate a transaction 
      #record what's being done in the transaction
 
      $self->SUPER::_set_and_return($field, @_);
    }
    else {
      return (0, "Permission Denied");
    }
  }
  
}

sub CurrentUser {
  my $self = shift;
  return ($self->{'user'});
}
    

1;



#$Header$

package RT::ACE;
use RT::Record;
@ISA= qw(RT::Record);

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $self->{'table'} = "queue_acls";
  $self->{'user'} = shift;
  $self->_init(@_);
  return ($self);
}

sub User {
  my $self = shift;
  $self->_set_and_return('user_id',@_);
}


sub Queue {
 my $self = shift;
  $self->_set_and_return('queue_id',@_);

}

sub Display {
 my $self = shift;
  $self->_set_and_return('display',@_);

}

sub Modify {
 my $self = shift;
  $self->_set_and_return('modify',@_);

}

sub Admin {
 my $self = shift;
  $self->_set_and_return('admin',@_);
}

#$Header$

package RT::ACE;
use RT::Record;
@ISA= qw(RT::Record);

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $self->{'table'} = "ACL";
  $self->_Init(@_);
  return ($self);
}

sub _Accessible {
  my $self = shift;  
  my %Cols = (
	     User => 'read/write',
	     Queue => 'read/write',
	     Display => 'read/write',
	     Manipulate => 'write',
	     Admin => 'read/write',
	    );
  return($self->SUPER::_Accessible(@_, %Cols));
}


1;

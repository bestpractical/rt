#$Header$

package RT::EasySearch;
use DBIx::EasySearch;
@ISA= qw(DBIx::EasySearch);

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $self->_Init(@_);
  return $self;
}

sub _Init {
  my $self = shift;

 $self->{'user'} = shift;

  $self->SUPER::_Init( 'Handle' => $RT::Handle);
}

sub CurrentUser {
  my $self = shift;
  return ($self->{'user'});
}
    

1;



# $Header$
package RT::Templates;
use RT::EasySearch;
@ISA= qw(DBIx::EasySearch);


# {{{ sub new 
sub new  {
  my $pkg= shift;
  my $self = SUPER::new $pkg;
  
  $self->{'table'} = "Templates";
  $self->{'primary_key'} = "id";
  return($self);
}
# }}}

1;


#$Header$

package RT::Groups;
use RT::EasySearch;
@ISA= qw(RT::EasySearch);


#instantiate a new object.
# {{{ sub new 
sub new  {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $self->_Init(@_);
  return ($self)
}
# }}}


# {{{ sub _Init
sub _Init { 
  my $self = shift;
  $self->{'table'} = "Groups";
  $self->{'primary_key'} = "id";
  $self->SUPER::_Init(@_);
}
# }}}

# {{{ sub Limit 
sub Limit  {
  my $self = shift;
  my %args = ( ENTRYAGGREGATOR => 'AND',
	       @_);
  $self->SUPER::Limit(%args);
}
# }}}

# {{{ sub NewItem 
sub NewItem  {
  my $self = shift;
  my $item;

  use RT::Group;
  $item = new RT::Group($self->CurrentUser);
  return($item);
}
# }}}


1;


#$Header$

package RT::Queues;
use RT::EasySearch;
@ISA= qw(RT::EasySearch);


# {{{ sub _Init
sub _Init { 
  my $self = shift;
  $self->{'table'} = "Queues";
  $self->{'primary_key'} = "id";
  return ($self->SUPER::_Init(@_));
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

  use RT::Queue;
  $item = new RT::Queue($self->CurrentUser);
  return($item);
}
# }}}


1;


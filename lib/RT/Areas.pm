#$Header$
package RT::Areas;
use DBIx::EasySearch;
@ISA= qw(DBIx::EasySearch);


# {{{ sub new 
sub new  {
  my $pkg= shift;
  my $self = SUPER::new $pkg;
  
  $self->{'table'} = "queue_area";
  $self->{'primary_key'} = "id";
  return($self);
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
  my $Handle = shift;
  my $item;
  $item = new RT::Area($self->{'user'}, $Handle);
  return($item);
}
# }}}
  1;


#$Header$

package RT::Links;
use RT::EasySearch;

@ISA= qw(RT::EasySearch);


# {{{ sub _Init  
sub _Init   {
  my $self = shift;
 
  $self->{'table'} = "Links";
  $self->{'primary_key'} = "id";
  $self->SUPER::_Init(@_);
}
# }}}

# {{{ sub Limit 
sub Limit  {
  my $self = shift;
my %args = ( ENTRYAGGREGATOR => 'AND',
             OPERATOR => '=',
             @_);

  #if someone's trying to search for tickets, try to resolve the uris for searching.

  if (  ( $args{'OPERATOR'} eq '=') and
        ( $args{'FIELD'}  eq 'Base') or ($args{'FIELD'} eq 'Target')
     ) {
   my $dummy = $self->NewItem;
   $uri = $dummy->CanonicalizeURI($args{'VALUE'})

  $self->SUPER::Limit(%args);
}
# }}}

# {{{ sub NewItem 
sub NewItem  {
  my $self = shift;
  my $item;

  use RT::Link;
  $item = new RT::Link($self->CurrentUser);
  return($item);
}
# }}}
  1;


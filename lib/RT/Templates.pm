# $Header$
package RT::Templates;
use RT::EasySearch;
@ISA= qw(RT::EasySearch);


# {{{ sub _Init

=head2 _Init

  Returns RT::Templates specific init info like table and primary key names

=cut

sub _Init {
    
    my $self = shift;
    $self->{'table'} = "Templates";
    $self->{'primary_key'} = "id";
    $self->SUPER::_Init(@_);
}
# }}}



# {{{ sub NewItem 

=head2 NewItem

Returns a new empty Template object

=cut

sub NewItem  {
  my $self = shift;
  my $Handle = shift;
  my $item;
  use RT::Template;
  $item = new RT::Template($self->CurrentUser);
  return($item);
}
# }}}

1;


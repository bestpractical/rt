#$Header$

package RT::GroupMembers;
use RT::EasySearch;

@ISA= qw(RT::EasySearch);


# {{{ sub _Init  
sub _Init   {
  my $self = shift;
 
  $self->{'table'} = "GroupMembers";
  $self->{'primary_key'} = "id";
  return ( $self->SUPER::_Init(@_) );
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

  use RT::GroupMember;
  $item = new RT::GroupMember($self->CurrentUser);
  return($item);
}
# }}}
  1;

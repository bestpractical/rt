#$Header$

=head1 NAME

  RT::Transactions - a collection of RT Transaction objects

=head1 SYNOPSIS

  use RT::Transactions;


=head1 DESCRIPTION


=head1 METHODS

=cut

package RT::Transactions;
use RT::EasySearch;

@ISA= qw(RT::EasySearch);


# {{{ sub _Init  
sub _Init   {
  my $self = shift;
 
  $self->{'table'} = "Transactions";
  $self->{'primary_key'} = "id";
  return ( $self->SUPER::_Init(@_));
}
# }}}

# {{{ sub NewItem 
sub NewItem  {
  my $self = shift;

  use RT::Transaction;
  my $item = RT::Transaction->new($self->CurrentUser);
  return($item);
}
# }}}
  1;


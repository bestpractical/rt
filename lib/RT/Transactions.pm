#$Header$

package RT::Transactions;
use RT::EasySearch;

@ISA= qw(RT::EasySearch);


sub _Init  {
  my $self = shift;
 
  $self->{'table'} = "Transactions";
  $self->{'primary_key'} = "id";
  $self->SUPER::_Init(@_);
}

sub Limit {
  my $self = shift;
my %args = ( ENTRYAGGREGATOR => 'AND',
             @_);

  $self->SUPER::Limit(%args);
}

sub NewItem {
  my $self = shift;
  my $Handle = shift;
  my $item;

  use RT::Transaction;
  $item = new RT::Transaction($self->{'user'});
  return($item);
}
  1;


package RT::Articles;
use DBIx::EasySearch;
@ISA= qw(DBIx::EasySearch);


sub new {
  my $pkg= shift;
  my $self = SUPER::new $pkg;
  
  $self->{'table'} = "ACL";
  $self->{'primary_key'} = "id";
  return($self);
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
  $item = new RT::ACE($self->{'user'}, $Handle);
  return($item);
}
  1;


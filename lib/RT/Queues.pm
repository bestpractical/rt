package RT::Articles;
@ISA= qw(DBIx::EasySearch);


sub new {
  my $pkg= shift;
  my $self = SUPER::new $pkg;
  
  $self->{'table'} = "queues";
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
  my $item;
  $item = new RT::Queue($self->{'user'});
  return($item);
}
  1;


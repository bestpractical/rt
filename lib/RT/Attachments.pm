#$Header$
package RT::Transactions;

use DBIx::EasySearch;

@ISA= qw(DBIx::EasySearch);


sub new {
  my $pkg= shift;
  my $self = SUPER::new $pkg;
  
  $self->{'table'} = "Attachments";
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
  use RT::Attachment;
  $item = new RT::Attachment($self->{'user'});
  return($item);
}
  1;


#$Header$

package RT::Queues;
use RT::EasySearch;
@ISA= qw(RT::EasySearch);


#instantiate a new object.
sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $self->_Init(@_);
  return ($self)
}

sub _Init { 
  my $self = shift;
  $self->{'table'} = "queues";
  $self->{'primary_key'} = "id";
 # print "Now initting with ",@_,"\n";
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
  my $item;
  use RT::Queue;
#  print STDERR "Loading a new queue\n";
  $item = new RT::Queue($self->{'user'});
  return($item);
}


1;


#$Header$

package RT::ScripScopes;
use RT::EasySearch;
@ISA= qw(RT::EasySearch);

# Removed the new() method.  It's redundant, we'll use
# RT::EasySearch::new instead.

# {{{ sub _Init
sub _Init { 
  my $self = shift;
  $self->{'table'} = "ScripScope";
  $self->{'primary_key'} = "id";
  $self->SUPER::_Init(@_);
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

# {{{ sub LimitToQueue 
sub LimitToQueue  {
  my $self = shift;
  my $queue = shift;
  $self->Limit (ENTRYAGGREGATOR => 'OR',
		FIELD => 'Queue',
		VALUE => "$queue")
      if defined $queue;
  $self->Limit (ENTRYAGGREGATOR => 'OR',
		FIELD => 'Queue',
		VALUE => 0);
  
}
# }}}

# What do we need this one for?  Shouldn't it essentially be the same
# to call $object->new() as $object->NewItem() ?  Or do we plan to
# subclass this class without overriding this method?

# {{{ sub NewItem 
sub NewItem  {
  my $self = shift;
  my $item;

  use RT::ScripScope;
  $item = new RT::ScripScope();
  return($item);
}
# }}}


1;


#$Header$

package RT::Scrips;
use RT::EasySearch;
@ISA= qw(RT::EasySearch);


# Removed the new() method.  It's redundant, we'll use
# RT::EasySearch::new instead.

# {{{ sub _Init
sub _Init { 
  my $self = shift;
  $self->{'table'} = "Scrips";
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

# {{{ sub LimitToType 
sub LimitToType  {
  my $self = shift;
  my $type = shift;
  $self->Limit (ENTRYAGGREGATOR => 'OR',
		FIELD => 'Type',
		VALUE => "$type")
      if defined $type;
  $self->Limit (ENTRYAGGREGATOR => 'OR',
		FIELD => 'Type',
		VALUE => "Correspond")
      if $type eq "Create";
  $self->Limit (ENTRYAGGREGATOR => 'OR',
		FIELD => 'Type',
		VALUE => 'any');
  
}
# }}}

# What do we need this one for?  Shouldn't it essentially be the same
# to call $object->new() as $object->NewItem() ?  Or do we plan to
# subclass this class without overriding this method?

# {{{ sub NewItem 
sub NewItem  {
  my $self = shift;
  my $item;

  use RT::Scrip;
  $item = new RT::Scrip($self->CurrentUser);
  return($item);
}
# }}}


1;


#$Header$
=head1 NAME

  RT::Scrips - Collection of Scrip objects

=head1 SYNOPSIS

  use RT::Scrips;


=head1 DESCRIPTION


=head1 METHODS

=cut

package RT::Scrips;
use RT::EasySearch;
@ISA= qw(RT::EasySearch);

# {{{ sub _Init
sub _Init { 
  my $self = shift;
  $self->{'table'} = "Scrips";
  $self->{'primary_key'} = "id";
  return ( $self->SUPER::_Init(@_));
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


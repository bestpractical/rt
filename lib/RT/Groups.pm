#$Header$

=head1 NAME

  RT::Groups - a collection of RT::Group objects

=head1 SYNOPSIS

  use RT::Groups;

=head1 DESCRIPTION


=head1 METHODS

=cut

package RT::Groups;
use RT::EasySearch;
@ISA= qw(RT::EasySearch);

# {{{ sub _Init
sub _Init { 
  my $self = shift;
  $self->{'table'} = "Groups";
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

# {{{ sub NewItem 
sub NewItem  {
  my $self = shift;
  my $item;

  use RT::Group;
  $item = new RT::Group($self->CurrentUser);
  return($item);
}
# }}}


1;


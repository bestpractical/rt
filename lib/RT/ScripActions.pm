#$Header$

=head1 NAME

  RT::ScripActions - Collection of Action objects

=head1 SYNOPSIS

  use RT::ScripActions;


=head1 DESCRIPTION


=begin testing

ok (require RT::TestHarness);
ok (require RT::ScripActions);

=end testing

=head1 METHODS

=cut

package RT::ScripActions;
use RT::EasySearch;
use RT::ScripAction;

@ISA= qw(RT::EasySearch);

# {{{ sub _Init
sub _Init { 
  my $self = shift;
  $self->{'table'} = "ScripActions";
  $self->{'primary_key'} = "id";
  return ( $self->SUPER::_Init(@_));
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
  return(RT::ScripAction->new($self->CurrentUser));

}
# }}}


1;


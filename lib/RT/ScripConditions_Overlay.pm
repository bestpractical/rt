#$Header: /raid/cvsroot/rt/lib/RT/ScripConditions.pm,v 1.2 2001/11/06 23:04:14 jesse Exp $

=head1 NAME

  RT::ScripConditions - Collection of Action objects

=head1 SYNOPSIS

  use RT::ScripConditions;


=head1 DESCRIPTION



=begin testing

ok (require RT::ScripConditions);

=end testing

=head1 METHODS

=cut

no warnings qw(redefine);

# {{{ sub _Init
sub _Init { 
  my $self = shift;
  $self->{'table'} = "ScripConditions";
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
  return(RT::ScripCondition->new($self->CurrentUser));
}
# }}}


1;



use strict;
no warnings qw/redefine/;

sub _Init { 
  my $self = shift;
  $self->{'table'} = "FM_Transactions";
  $self->{'primary_key'} = "id";
  
  $self->OrderBy( ALIAS => 'main',
          FIELD => 'Created',
          ORDER => 'ASC');


  return ( $self->SUPER::_Init(@_));
}


1;

#$Header$

package RT::Keywords;

use strict;
use vars qw( @ISA );
use RT::EasySearch;
use RT::Keyword;

@ISA = qw( RT::EasySearch );

sub _Init {
  my $self = shift;
  $self->{'table'} = 'Keywords';
  $self->{'primary_key'} = 'id';
  return ($self->SUPER::_Init(@_));
}

sub NewItem {
  my $self = shift;
  #my $Handle = shift;
  new RT::Keyword $self->CurrentUser;
}

#sub DEBUG { 1; }

1;


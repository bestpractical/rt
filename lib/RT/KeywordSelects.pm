#$Header$

package RT::KeywordSelects;

use strict;
use vars qw( @ISA );
use RT::EasySearch;
use RT::KeywordSelect;

@ISA = qw( RT::EasySearch );

sub _Init {
  my $self = shift;
  $self->{'table'} = 'KeywordSelects';
  $self->{'primary_key'} = 'id';
  return ($self->SUPER::_Init(@_));
}

sub NewItem {
  my $self = shift;
  #my $Handle = shift;
  new RT::KeywordSelect $self->CurrentUser;
}

1;


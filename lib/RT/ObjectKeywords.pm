#$Header$

package RT::ObjectKeywords;

use strict;
use vars qw( @ISA );
use RT::EasySearch;
use RT::ObjectKeyword;
@ISA = qw( RT::EasySearch );

sub _Init {
  my $self = shift;
  $self->{'table'} = 'ObjectKeywords';
  $self->{'primary_key'} = 'id';
  return ($self->SUPER::_Init(@_));
}

sub NewItem {
  my $self = shift;
  new RT::ObjectKeyword $self->CurrentUser;
}

1;


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
    return (new RT::Keyword ($self->CurrentUser));
}

=head2 LimitToParent

Takes a parent id and limits the returned keywords to children of that parent.

=cut

sub LimitToParent {
    my $self = shift;
    my $parent = shift;
    $self->Limit( FIELD => 'Parent',
		  VALUE => $parent,
		  OPERATOR => '=',
		  ENTRYAGGREGATOR => 'OR' );
}	

#sub DEBUG { 1; }

1;


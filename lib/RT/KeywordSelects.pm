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

=head2 LimitToQueue 

Takes a queue id. Limits the returned set to KeywordSelects for that queue.
Repeated calls will be OR'd together.

=cut

sub LimitToQueue {
    my $self = shift;
    my $queue = shift;

    $self->Limit( FIELD => 'ObjectValue',
		  VALUE => $queue,
		  OPERATOR => '=',
		  ENTRYAGGREGATOR => 'OR'
		);

    $self->Limit( FIELD => 'ObjectType',
		  VALUE => 'Ticket',
		  OPERATOR => '=');

    $self->Limit( FIELD => 'ObjectField',
		  VALUE => 'Queue',
		  OPERATOR => '=');

    
}

=head2 LimitToGlobals

Limits the returned set to KeywordSelects for all queues.
Repeated calls will be OR'd together.

=cut

sub LimitToGlobals {
    my $self = shift;

    $self->Limit( FIELD => 'ObjectType',
		  VALUE => 'Ticket',
		  OPERATOR => '=');

    $self->Limit( FIELD => 'ObjectField',
		  VALUE => 'Queue',
		  OPERATOR => '=');

    $self->Limit( FIELD => 'ObjectValue',
		  VALUE => '0',
		  OPERATOR => '=',
		  ENTRYAGGREGATOR => 'OR'
		);
    
}


# {{{ sub IncludeGlobals
=head2 IncludeGlobals

Include KeywordSelects which apply globally in the set of returned results

=cut


sub IncludeGlobals {
    my $self = shift;
    $self->Limit( FIELD => 'ObjectValue',
		  VALUE => '0',
		  OPERATOR => '=',
		  ENTRYAGGREGATOR => 'OR'
		);
    

}
# }}}

# {{{ sub NewItem
sub NewItem {
    my $self = shift;
    #my $Handle = shift;
    return (new RT::KeywordSelect($self->CurrentUser));
}
# }}}
1;


# $Header$
package RT::Templates;
use RT::EasySearch;
@ISA= qw(RT::EasySearch);


# {{{ sub _Init

=head2 _Init

  Returns RT::Templates specific init info like table and primary key names

=cut

sub _Init {
    
    my $self = shift;
    $self->{'table'} = "Templates";
    $self->{'primary_key'} = "id";
    return ($self->SUPER::_Init(@_));
}
# }}}

# {{{ LimitToNotInQueue

=head2 LimitToNotInQueue

Takes a queue id # and limits the returned set of templates to those which 
aren't that queue's templates.

=cut

sub LimitToNotInQueue {
    my $self = shift;
    my $queue_id = shift;
    $self->Limit(FIELD => 'Queue',
                 VALUE => "$queue_id",
                 OPERATOR => '!='
                );
}
# }}}

# {{{ LimitToQueue

=head2 LimitToQueue

Takes a queue id # and limits the returned set of templates to that queue's
templates

=cut

sub LimitToQueue {
    my $self = shift;
    my $queue_id = shift;
    $self->Limit(FIELD => 'Queue',
                 VALUE => "$queue_id",
                 OPERATOR => '='
                );
}
# }}}

# {{{ sub NewItem 

=head2 NewItem

Returns a new empty Template object

=cut

sub NewItem  {
  my $self = shift;
  my $Handle = shift;
  my $item;
  use RT::Template;
  $item = new RT::Template($self->CurrentUser);
  return($item);
}
# }}}

1;


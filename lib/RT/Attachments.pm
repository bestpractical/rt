#$Header$

=head1 NAME

  RT::Attachments - a collection of RT::Attachment objects

=head1 SYNOPSIS

  use RT::Attachments;

=head1 DESCRIPTION

This module should never be called directly by client code. it's an internal module which
should only be accessed through exported APIs in Ticket, Queue and other similar objects.


=head1 METHODS

=cut

package RT::Attachments;

use RT::EasySearch;

@ISA= qw(RT::EasySearch);

# {{{ sub _Init  
sub _Init   {
  my $self = shift;
 
  $self->{'table'} = "Attachments";
  $self->{'primary_key'} = "id";
  return ( $self->SUPER::_Init(@_));
}
# }}}


# {{{ sub ContentType

=head2 ContentType (VALUE => 'text/plain', ENTRYAGGREGATOR => 'OR', OPERATOR => '=' ) 

Limit result set to attachments of ContentType 'TYPE'...

=cut


sub ContentType  {
  my $self = shift;
  my %args = ( VALUE => 'text/plain',
	       OPERATOR => '=',
	       ENTRYAGGREGATOR => 'OR',
	       @_);

  $self->Limit ( FIELD => 'ContentType',
		 VALUE => $args{'VALUE'},
		 OPERATOR => $args{'OPERATOR'},
		 ENTRYAGGREGATOR => $args{'ENTRYAGGREGATOR'});
}
# }}}

# {{{ sub ChildrenOf 

=head2 ChildrenOf ID

Limit result set to children of Attachment ID

=cut


sub ChildrenOf  {
  my $self = shift;
  my $attachment = shift;
  $self->Limit ( FIELD => 'Parent',
		 VALUE => $attachment);
}
# }}}

# {{{ sub NewItem 
sub NewItem  {
  my $self = shift;

  use RT::Attachment;
  my $item = new RT::Attachment($self->CurrentUser);
  return($item);
}
# }}}
  1;





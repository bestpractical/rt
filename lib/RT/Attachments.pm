#$Header$

package RT::Attachments;

use RT::EasySearch;

@ISA= qw(RT::EasySearch);


# {{{ sub _Init  
sub _Init   {
  my $self = shift;
 
  $self->{'table'} = "Attachments";
  $self->{'primary_key'} = "id";
  $self->SUPER::_Init(@_);
}
# }}}


# {{{ sub Limit 
sub Limit  {
  my $self = shift;
my %args = ( ENTRYAGGREGATOR => 'AND',
             @_);

  $self->SUPER::Limit(%args);
}
# }}}

# {{{ sub ChildrenOf 
sub ChildrenOf  {
  my $self = shift;
  my $attachment = shift;
  $self->Limit ( Field => 'Parent',
		 Value => "$attachment");
}
# }}}


# {{{ sub NewItem 
sub NewItem  {
  my $self = shift;
  my $Handle = shift;
  my $item;
  use RT::Attachment;
  $item = new RT::Attachment($self->{'user'});
  return($item);
}
# }}}
  1;





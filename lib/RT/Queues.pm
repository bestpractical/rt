#$Header$

=head1 NAME

  RT::Queues - a collection of RT::Queue objects

=head1 SYNOPSIS

  use RT::Queues;

=head1 DESCRIPTION


=head1 METHODS

=cut

package RT::Queues;
use RT::EasySearch;
@ISA= qw(RT::EasySearch);


# {{{ sub _Init
sub _Init { 
  my $self = shift;
  $self->{'table'} = "Queues";
  $self->{'primary_key'} = "id";
  return ($self->SUPER::_Init(@_));
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

# {{{ sub NewItem 
sub NewItem  {
  my $self = shift;
  my $item;

  use RT::Queue;
  $item = new RT::Queue($self->CurrentUser);
  return($item);
}
# }}}

# {{{ sub Next 

=head2 Next

Returns the next queue that this user can see.

=cut
  
sub Next {
    my $self = shift;
    
    
    my $Queue = $self->SUPER::Next();
    if ((defined($Queue)) and (ref($Queue))) {

	if ($Queue->CurrentUserHasRight('SeeQueue')) {
	    return($Queue);
	}
	
	#If the user doesn't have the right to show this queue
	else {	
	    return($self->Next());
	}
    }
    #if there never was any queue
    else {
	return(undef);
    }	
    
}
# }}}

1;


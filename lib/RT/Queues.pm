#$Header: /raid/cvsroot/rt/lib/RT/Queues.pm,v 1.2 2001/11/06 23:04:14 jesse Exp $

=head1 NAME

  RT::Queues - a collection of RT::Queue objects

=head1 SYNOPSIS

  use RT::Queues;

=head1 DESCRIPTION


=head1 METHODS


=begin testing

ok (require RT::TestHarness);
ok (require RT::Queues);

=end testing

=cut

package RT::Queues;
use RT::EasySearch;
@ISA= qw(RT::EasySearch);


# {{{ sub _Init
sub _Init { 
  my $self = shift;
  $self->{'table'} = "Queues";
  $self->{'primary_key'} = "id";

  # By default, order by name
  $self->OrderBy( ALIAS => 'main',
		  FIELD => 'Name',
		  ORDER => 'ASC');

  return ($self->SUPER::_Init(@_));
}
# }}}

# {{{ sub _DoSearch 

=head2 _DoSearch

  A subclass of DBIx::SearchBuilder::_DoSearch that makes sure that _Disabled rows never get seen unless
we're explicitly trying to see them.

=cut

sub _DoSearch {
    my $self = shift;
    
    #unless we really want to find disabled rows, make sure we\'re only finding enabled ones.
    unless($self->{'find_disabled_rows'}) {
	$self->LimitToEnabled();
    }
    
    return($self->SUPER::_DoSearch(@_));
    
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


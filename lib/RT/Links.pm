#$Header$
=head1 NAME

  RT::Links - A collection of Link objects

=head1 SYNOPSIS

  use RT::Links;
  my $links = new RT::Links($CurrentUser);

=head1 DESCRIPTION


=head1 METHODS

=cut
package RT::Links;
use RT::EasySearch;
use RT::Link;

@ISA= qw(RT::EasySearch);

# {{{ sub _Init  
sub _Init   {
  my $self = shift;
 
  $self->{'table'} = "Links";
  $self->{'primary_key'} = "id";


  return ( $self->SUPER::_Init(@_));
}
# }}}

# {{{ sub Limit 
sub Limit  {
    my $self = shift;
    my %args = ( ENTRYAGGREGATOR => 'AND',
		 OPERATOR => '=',
		 @_);
    
    #if someone's trying to search for tickets, try to resolve the uris for searching.
    
    if (  ( $args{'OPERATOR'} eq '=') and
	  ( $args{'FIELD'}  eq 'Base') or ($args{'FIELD'} eq 'Target')
       ) {
	my $dummy = $self->NewItem();
	  $uri = $dummy->CanonicalizeURI($args{'VALUE'});
    }


    # If we're limiting by target, order by base
    # (Order by the thing that's changing)

    if ( ($args{'FIELD'} eq 'Target') or 
	 ($args{'FIELD'} eq 'LocalTarget') ) {
	$self->OrderBy (ALIAS => 'main',
			FIELD => 'Base',
			ORDER => 'ASC');
    }
    elsif ( ($args{'FIELD'} eq 'Base') or 
	    ($args{'FIELD'} eq 'LocalBase') ) {
	$self->OrderBy (ALIAS => 'main',
			FIELD => 'Target',
			ORDER => 'ASC');
    }
    

    $self->SUPER::Limit(%args);
}
# }}}

# {{{ sub NewItem 
sub NewItem  {
    my $self = shift;
    return(RT::Link->new($self->CurrentUser));
}
# }}}
  1;


#$Header$
=head1 NAME

  RT::Keywords - a collection of RT::Keyword objects

=head1 SYNOPSIS

  use RT::Keywords;
  my $keywords = RT::Keywords->new($user);
  $keywords->LimitToParent(0);
  while my ($keyword = $keywords->Next()) {
     print $keyword->Name ."\n";
  }


=head1 DESCRIPTION


=head1 METHODS

=begin testing

ok (require RT::TestHarness);
ok (require RT::Keywords);

=end testing

=cut

package RT::Keywords;

use strict;
use vars qw( @ISA );
use RT::EasySearch;
use RT::Keyword;

@ISA = qw( RT::EasySearch );


# {{{ sub _Init

sub _Init {
    my $self = shift;
    $self->{'table'} = 'Keywords';
    $self->{'primary_key'} = 'id';

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

# {{{ sub NewItem 
sub NewItem {
    my $self = shift;
    return (RT::Keyword->new($self->CurrentUser));
}
# }}}

# {{{ sub LimitToParent

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
# }}}

1;


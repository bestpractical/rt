# BEGIN LICENSE BLOCK
# 
# Copyright (c) 1996-2003 Jesse Vincent <jesse@bestpractical.com>
# 
# (Except where explictly superceded by other copyright notices)
# 
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
# 
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# Unless otherwise specified, all modifications, corrections or
# extensions to this work which alter its source code become the
# property of Best Practical Solutions, LLC when submitted for
# inclusion in the work.
# 
# 
# END LICENSE BLOCK
=head1 NAME

  RT::Queues - a collection of RT::Queue objects

=head1 SYNOPSIS

  use RT::Queues;

=head1 DESCRIPTION


=head1 METHODS


=begin testing

ok (require RT::Queues);

=end testing

=cut

use strict;
no warnings qw(redefine);

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


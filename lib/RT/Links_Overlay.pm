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

  RT::Links - A collection of Link objects

=head1 SYNOPSIS

  use RT::Links;
  my $links = new RT::Links($CurrentUser);

=head1 DESCRIPTION


=head1 METHODS


=begin testing

ok (require RT::Links);

=end testing

=cut

use strict;
no warnings qw(redefine);
use RT::URI;

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
	  my $dummy = RT::URI->new($self->CurrentUser);
	   $dummy->FromURI($args{'VALUE'});
	   # $uri = $dummy->URI;
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

# {{{ LimitRefersTo 

=head2 LimitRefersTo URI

find all things that refer to URI

=cut

sub LimitRefersTo {
    my $self = shift;
    my $URI = shift;

    $self->Limit(FIELD => 'Type', VALUE => 'RefersTo');
    $self->Limit(FIELD => 'Target', VALUE => $URI);
}

# }}}
# {{{ LimitReferredToBy

=head2 LimitReferredToBy URI

find all things that URI refers to

=cut

sub LimitReferredToBy {
    my $self = shift;
    my $URI = shift;

    $self->Limit(FIELD => 'Type', VALUE => 'RefersTo');
    $self->Limit(FIELD => 'Base', VALUE => $URI);
}

# }}}
1;


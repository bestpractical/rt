# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2009 Best Practical Solutions, LLC 
#                                          <jesse@bestpractical.com>
# 
# (Except where explicitly superseded by other copyright notices)
# 
# 
# LICENSE:
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
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
# 
# 
# CONTRIBUTION SUBMISSION POLICY:
# 
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
# 
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
# 
# END BPS TAGGED BLOCK }}}
=head1 NAME

  RT::CustomFields - a collection of RT CustomField objects

=head1 SYNOPSIS

  use RT::CustomFields;

=head1 DESCRIPTION

=head1 METHODS


=begin testing

ok (require RT::CustomFields);

=end testing

=cut


package RT::CustomFields;

use strict;
no warnings qw(redefine);
use DBIx::SearchBuilder::Unique;


sub _OCFAlias {
    my $self = shift;
    unless ($self->{_sql_ocfalias}) {

        $self->{'_sql_ocfalias'} = $self->NewAlias('ObjectCustomFields');
    $self->Join( ALIAS1 => 'main',
                FIELD1 => 'id',
                ALIAS2 => $self->_OCFAlias,
                FIELD2 => 'CustomField' );
    }
    return($self->{_sql_ocfalias});
}


# {{{ sub LimitToGlobalOrQueue 

=head2 LimitToGlobalOrQueue QUEUEID

Limits the set of custom fields found to global custom fields or those tied to the queue with ID QUEUEID 

=cut

sub LimitToGlobalOrQueue {
    my $self = shift;
    my $queue = shift;
    $self->LimitToGlobalOrObjectId( $queue );
    $self->LimitToLookupType( 'RT::Queue-RT::Ticket' );
}

# }}}

# {{{ sub LimitToQueue 

=head2 LimitToQueue QUEUEID

Takes a queue id (numerical) as its only argument. Makes sure that 
Scopes it pulls out apply to this queue (or another that you've selected with
another call to this method

=cut

sub LimitToQueue  {
   my $self = shift;
  my $queue = shift;
 
  $self->Limit (ALIAS => $self->_OCFAlias,
                ENTRYAGGREGATOR => 'OR',
		FIELD => 'ObjectId',
		VALUE => "$queue")
      if defined $queue;
  $self->LimitToLookupType( 'RT::Queue-RT::Ticket' );
}
# }}}

# {{{ sub LimitToGlobal

=head2 LimitToGlobal

Makes sure that 
Scopes it pulls out apply to all queues (or another that you've selected with
another call to this method or LimitToQueue

=cut


sub LimitToGlobal  {
   my $self = shift;
 
  $self->Limit (ALIAS => $self->_OCFAlias,
                ENTRYAGGREGATOR => 'OR',
		FIELD => 'ObjectId',
		VALUE => 0);
  $self->LimitToLookupType( 'RT::Queue-RT::Ticket' );
}
# }}}


# {{{ sub _DoSearch 

=head2 _DoSearch

A subclass of DBIx::SearchBuilder::_DoSearch that makes sure that 
 _Disabled rows never get seen unless we're explicitly trying to see 
them.

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

# {{{ sub Next 

=head2 Next

Returns the next custom field that this user can see.

=cut
  
sub Next {
    my $self = shift;
    
    
    my $CF = $self->SUPER::Next();
    if ((defined($CF)) and (ref($CF))) {

	if ($CF->CurrentUserHasRight('SeeCustomField')) {
	    return($CF);
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

sub LimitToLookupType  {
    my $self = shift;
    my $lookup = shift;
 
    $self->Limit( FIELD => 'LookupType', VALUE => "$lookup" );
}

sub LimitToChildType  {
    my $self = shift;
    my $lookup = shift;
 
    $self->Limit( FIELD => 'LookupType', VALUE => "$lookup" );
    $self->Limit( FIELD => 'LookupType', ENDSWITH => "$lookup" );
}

sub LimitToParentType  {
    my $self = shift;
    my $lookup = shift;
 
    $self->Limit( FIELD => 'LookupType', VALUE => "$lookup" );
    $self->Limit( FIELD => 'LookupType', STARTSWITH => "$lookup" );
}

sub LimitToGlobalOrObjectId {
    my $self = shift;
    my $global_only = 1;


    foreach my $id (@_) {
	$self->Limit( ALIAS           => $self->_OCFAlias,
		    FIELD           => 'ObjectId',
		    OPERATOR        => '=',
		    VALUE           => $id || 0,
		    ENTRYAGGREGATOR => 'OR' );
	$global_only = 0 if $id;
    }

    $self->Limit( ALIAS           => $self->_OCFAlias,
                 FIELD           => 'ObjectId',
                 OPERATOR        => '=',
                 VALUE           => 0,
                 ENTRYAGGREGATOR => 'OR' ) unless $global_only;

    $self->OrderByCols(
	{ ALIAS => $self->_OCFAlias, FIELD => 'ObjectId' },
	{ ALIAS => $self->_OCFAlias, FIELD => 'SortOrder' },
    );
    
    # This doesn't work on postgres. 
    #$self->OrderBy( ALIAS => $class_cfs , FIELD => "SortOrder", ORDER => 'ASC');

}
  
1;


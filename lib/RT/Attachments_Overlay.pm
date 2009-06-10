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

  RT::Attachments - a collection of RT::Attachment objects

=head1 SYNOPSIS

  use RT::Attachments;

=head1 DESCRIPTION

This module should never be called directly by client code. it's an internal module which
should only be accessed through exported APIs in Ticket, Queue and other similar objects.


=head1 METHODS


=begin testing

ok (require RT::Attachments);

=end testing

=cut


package RT::Attachments;

use strict;
no warnings qw(redefine);

# {{{ sub _Init  
sub _Init   {
  my $self = shift;
 
  $self->{'table'} = "Attachments";
  $self->{'primary_key'} = "id";
  $self->OrderBy ( FIELD => 'id',
                   ORDER => 'ASC');
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

# {{{ sub Next
sub Next {
    my $self = shift;
 	
    my $Attachment = $self->SUPER::Next();
    if ((defined($Attachment)) and (ref($Attachment))) {
	if ($Attachment->TransactionObj->__Value('Type') =~ /^Comment/ && 
	    $Attachment->TransactionObj->TicketObj->CurrentUserHasRight('ShowTicketComments')) {
	    return($Attachment);
	} elsif ($Attachment->TransactionObj->__Value('Type') !~ /^Comment/ && 
		 $Attachment->TransactionObj->TicketObj->CurrentUserHasRight('ShowTicket')) {
	    return($Attachment);
	}

	#If the user doesn't have the right to show this ticket
	else {	
	    return($self->Next());
	}
    }

    #if there never was any ticket
    else {
	return(undef);
    }	
}
# }}}

  1;





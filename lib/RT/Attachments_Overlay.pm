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

use strict;
no warnings qw(redefine);

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





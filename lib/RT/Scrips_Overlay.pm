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

  RT::Scrips - a collection of RT Scrip objects

=head1 SYNOPSIS

  use RT::Scrips;

=head1 DESCRIPTION


=head1 METHODS


=begin testing

ok (require RT::Scrips);

=end testing

=cut

use strict;
no warnings qw(redefine);

# {{{ sub LimitToQueue 

=head2 LimitToQueue

Takes a queue id (numerical) as its only argument. Makes sure that 
Scopes it pulls out apply to this queue (or another that you've selected with
another call to this method

=cut

sub LimitToQueue  {
   my $self = shift;
  my $queue = shift;
 
  $self->Limit (ENTRYAGGREGATOR => 'OR',
		FIELD => 'Queue',
		VALUE => "$queue")
      if defined $queue;
  
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
 
  $self->Limit (ENTRYAGGREGATOR => 'OR',
		FIELD => 'Queue',
		VALUE => 0);
  
}
# }}}

# {{{ sub NewItem 
sub NewItem  {
  my $self = shift;
  
  return(new RT::Scrip($self->CurrentUser));
}
# }}}

# {{{ sub Next 

=head2 Next

Returns the next scrip that this user can see.

=cut
  
sub Next {
    my $self = shift;
    
    
    my $Scrip = $self->SUPER::Next();
    if ((defined($Scrip)) and (ref($Scrip))) {

	if ($Scrip->CurrentUserHasRight('ShowScrips')) {
	    return($Scrip);
	}
	
	#If the user doesn't have the right to show this scrip
	else {	
	    return($self->Next());
	}
    }
    #if there never was any scrip
    else {
	return(undef);
    }	
    
}
# }}}

1;


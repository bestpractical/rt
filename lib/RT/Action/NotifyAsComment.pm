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
package RT::Action::NotifyAsComment;
require RT::Action::Notify;

use strict;
use vars qw/@ISA/;
@ISA = qw(RT::Action::Notify);


=head2 SetReturnAddress

Tell SendEmail that this message should come out as a comment. 
Calls SUPER::SetReturnAddress.

=cut

sub SetReturnAddress {
	my $self = shift;
	
	# Tell RT::Action::SendEmail that this should come 
	# from the relevant comment email address.
	$self->{'comment'} = 1;
	
	return($self->SUPER::SetReturnAddress(is_comment => 1));
}

eval "require RT::Action::NotifyAsComment_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Action/NotifyAsComment_Vendor.pm});
eval "require RT::Action::NotifyAsComment_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Action/NotifyAsComment_Local.pm});

1;


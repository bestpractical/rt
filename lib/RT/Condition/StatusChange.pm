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
 


package RT::Condition::StatusChange;
require RT::Condition::Generic;

use strict;
use vars qw/@ISA/;
@ISA = qw(RT::Condition::Generic);


=head2 IsApplicable

If the argument passed in is equivalent to the new value of
the Status Obj

=cut

sub IsApplicable {
    my $self = shift;
    if (($self->TransactionObj->Field eq 'Status') and 
    ($self->Argument eq $self->TransactionObj->NewValue())) {
	return(1);
    } 
    else {
	return(undef);
    }
}

eval "require RT::Condition::StatusChange_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Condition/StatusChange_Vendor.pm});
eval "require RT::Condition::StatusChange_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Condition/StatusChange_Local.pm});

1;


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
 

package RT::Condition::UserDefined;

use RT::Condition::Generic;

use strict;
use vars qw/@ISA/;
@ISA = qw(RT::Condition::Generic);


=head2 IsApplicable

This happens on every transaction. it's always applicable

=cut

sub IsApplicable {
    my $self = shift;
    my $retval = eval $self->ScripObj->CustomIsApplicableCode;
    if ($@) {
        $RT::Logger->error("Scrip ".$self->ScripObj->Id. " IsApplicable failed: ".$@);
        return (undef);
    }
    return ($retval);
}

eval "require RT::Condition::UserDefined_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Condition/UserDefined_Vendor.pm});
eval "require RT::Condition::UserDefined_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Condition/UserDefined_Local.pm});

1;


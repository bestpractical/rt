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
 

package RT::Action::UserDefined;
use RT::Action::Generic;

use strict;
use vars qw/@ISA/;
@ISA = qw(RT::Action::Generic);

=head2 Prepare

This happens on every transaction. it's always applicable

=cut

sub Prepare {
    my $self = shift;
    my $retval = eval $self->ScripObj->CustomPrepareCode;
    if ($@) {
        $RT::Logger->error("Scrip ".$self->ScripObj->Id. " Prepare failed: ".$@);
        return (undef);
    }
    return ($retval);
}

=head2 Commit

This happens on every transaction. it's always applicable

=cut

sub Commit {
    my $self = shift;
    my $retval = eval $self->ScripObj->CustomCommitCode;
    if ($@) {
        $RT::Logger->error("Scrip ".$self->ScripObj->Id. " Commit failed: ".$@);
        return (undef);
    }
    return ($retval);
}

eval "require RT::Action::UserDefined_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Action/UserDefined_Vendor.pm});
eval "require RT::Action::UserDefined_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Action/UserDefined_Local.pm});

1;


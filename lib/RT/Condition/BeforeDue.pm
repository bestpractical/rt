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
package RT::Condition::BeforeDue;
require RT::Condition::Generic;

use RT::Date;

use strict;
use vars qw/@ISA/;
@ISA = qw(RT::Condition::Generic);


sub IsApplicable {
    my $self = shift;

    # Parse date string.  Format is "1d2h3m4s" for 1 day and 2 hours
    # and 3 minutes and 4 seconds.
    my %e;
    foreach (qw(d h m s)) {
	my @vals = $self->Argument =~ m/(\d+)$_/;
	$e{$_} = pop @vals || 0;
    }
    my $elapse = $e{'d'} * 24*60*60 + $e{'h'} * 60*60 + $e{'m'} * 60 + $e{'s'};

    my $cur = new RT::Date( $RT::SystemUser );
    $cur->SetToNow();
    my $due = $self->TicketObj->DueObj;
    return (undef) if $due->Unix <= 0;

    my $diff = $due->Diff($cur);
    if ( $diff >= 0 and $diff <= $elapse ) {
        return(1);
    } else {
        return(undef);
    }
}

eval "require RT::Condition::BeforeDue_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Condition/BeforeDue_Vendor.pm});
eval "require RT::Condition::BeforeDue_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Condition/BeforeDue_Local.pm});

1;

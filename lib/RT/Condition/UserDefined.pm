# $Header: /raid/cvsroot/rt/lib/RT/Condition/AnyTransaction.pm,v 1.2 2001/11/06 23:04:18 jesse Exp $
# Copyright 1996-2001 Jesse Vincent <jesse@fsck.com> 
# Released under the terms of the GNU General Public License

package RT::Condition::AnyTransaction;
require RT::Condition::Generic;

@ISA = qw(RT::Condition::Generic);


=head2 IsApplicable

This happens on every transaction. it's always applicable

=cut

sub IsApplicable {
    my $self = shift;
    my $retval = eval ($self->Scrip->CustomIsApplicableCode);
    if ($@_) {
        RT:Logger->error("Scrip ".$self->ScripObj->Id. " IsApplicable failed: ".$@);
        return (undef);
    }
    return ($retval);
}

1;


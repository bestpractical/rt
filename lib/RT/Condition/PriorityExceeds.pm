# $Header: /raid/cvsroot/rt-addons/ScripConditions/IfTicketPriorityExceeds/PriorityExceeds.pm,v 1.2 2001/06/24 20:04:44 jesse Exp $
# Copyright 1996-2001 Jesse Vincent <jesse@fsck.com> 
# Released under the terms of the GNU General Public License

package RT::Condition::PriorityExceeds;
require RT::Condition::Generic;

@ISA = qw(RT::Condition::Generic);


=head2 IsApplicable

If the priority exceeds the argument value

=cut

sub IsApplicable {
    my $self = shift;
    if ($self->TicketObj->Priority > $self->Argument)  {
	return(1);
    } 
    else {
	return(undef);
    }
}

1;


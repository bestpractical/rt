# $Header: /raid/cvsroot/rt-addons/ScripConditions/IfTicketPriorityExceeds/PriorityExceeds.pm,v 1.2 2001/06/24 20:04:44 jesse Exp $
# Copyright 1996-2001 Jesse Vincent <jesse@fsck.com> 
# Released under the terms of the GNU General Public License

=head1 NAME

RT::Condition::Overdue

=head1 DESCRIPTION

Returns true if the ticket we're operating on is overdue

=cut

package RT::Condition::Overdue;
require RT::Condition::Generic;

@ISA = qw(RT::Condition::Generic);


=head2 IsApplicable

If the due date is before "now" return true

=cut

sub IsApplicable {
    my $self = shift;
    if ($self->TicketObj->DueObj->Unix < time())  {
	return(1);
    } 
    else {
	return(undef);
    }
}

1;


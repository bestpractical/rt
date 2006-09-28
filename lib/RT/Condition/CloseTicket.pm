package RT::Condition::CloseTicket;

use strict;
use warnings;

use base 'RT::Condition::Generic';


=head2 IsApplicable

If the ticket was closed, ie status was changed from any active status to
an inactive. See F<RT_Config.pm> for C<ActiveStatuses> and C<InactiveStatuses>
options.

=cut

sub IsApplicable {
    my $self = shift;

    my $txn = $self->TransactionObj;
    return 0 unless $txn->Type eq "Status" ||
        ( $txn->Type eq "Set" && $txn->Field eq "Status" );

    my $queue = $self->TicketObj->QueueObj;
    return 0 unless $queue->IsActiveStatus( $txn->OldValue );
    return 0 unless $queue->IsInactiveStatus( $txn->NewValue );

    return 1;
}

eval "require RT::Condition::CloseTicket_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Condition/CloseTicket_Vendor.pm});
eval "require RT::Condition::CloseTicket_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Condition/CloseTicket_Local.pm});

1;

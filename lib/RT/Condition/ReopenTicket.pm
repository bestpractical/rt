package RT::Condition::ReopenTicket;

use strict;
use warnings;

use base 'RT::Condition::Generic';


=head2 IsApplicable

If the ticket was repopened, ie status was changed from any inactive status to
an active. See F<RT_Config.pm> for C<ActiveStatuses> and C<InactiveStatuses>
options.

=cut

sub IsApplicable {
    my $self = shift;

    my $txn = $self->TransactionObj;
    return 0 unless $txn->Type eq "Status" ||
        ( $txn->Type eq "Set" && $txn->Field eq "Status" );

    my $queue = $self->TicketObj->QueueObj;
    return 0 unless $queue->IsInactiveStatus( $txn->OldValue );
    return 0 unless $queue->IsActiveStatus( $txn->NewValue );

    $RT::Logger->debug("Condition 'On Reopen' triggered "
        ."for ticket #". $self->TicketObj->id
        ." transaction #". $txn->id
    );

    return 1;
}

eval "require RT::Condition::ReopenTicket_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Condition/ReopenTicket_Vendor.pm});
eval "require RT::Condition::ReopenTicket_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Condition/ReopenTicket_Local.pm});

1;

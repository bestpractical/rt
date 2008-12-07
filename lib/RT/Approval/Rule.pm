package RT::Approval::Rule;
use strict;
use warnings;

use base 'RT::Rule';

use constant _Queue => '___Approvals';

sub Prepare {
    my $self = shift;
    return unless $self->SUPER::Prepare();
    $self->TicketObj->Type eq 'approval';
}

1;


package RT::Approval::Rule::NewPending;
use strict;
use warnings;
use base 'RT::Approval::Rule';

use constant Description => "When an approval ticket is created, notify the Owner and AdminCc of the item awaiting their approval"; # loc

sub Prepare {
    my $self = shift;
    return unless $self->SUPER::Prepare();

    $self->OnStatusChange('open') and
    eval { $T::Approving = ($self->TicketObj->AllDependedOnBy( Type => 'ticket' ))[0] }
}

sub Commit {
    my $self = shift;
    $self->RunScripAction('Notify Owner', 'New Pending Approval', @_);
}

1;

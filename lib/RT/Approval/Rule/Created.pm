package RT::Approval::Rule::Created;
use strict;
use warnings;
use base 'RT::Approval::Rule';

use constant _Stage => 'TransactionBatch';

use constant Description => "Notify Owner of their ticket has been approved by some or all approvers"; # loc

sub Prepare {
    my $self = shift;
    return unless $self->SUPER::Prepare();

    $self->TransactionObj->Type eq 'Create' &&
    !$self->TicketObj->HasUnresolvedDependencies( Type => 'approval' );
}

sub Commit {
    my $self = shift;
    $self->RunScripAction('Open Tickets' => 'Blank');
}

1;

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
    my ($top) = $self->TicketObj->AllDependedOnBy( Type => 'ticket' );
    my $t = $self->TicketObj->Transactions;
    my $to;
    while ( my $o = $t->Next ) {
        $to = $o, last if $o->Type eq 'Create';
    }

    # XXX: this makes the owner incorrect so notify owner won't work
    # local $self->{TicketObj} = $top;

    # first txn entry of the approval ticket
    local $self->{TransactionObj} = $to;
    $self->RunScripAction('Notify Owner', 'New Pending Approval', @_);

    return;

    # this generates more correct content of the message, but not sure
    # if ccmessageto is the right way to do this.
    my $template = RT::Template->new($self->CurrentUser);
    $template->Load('New Pending Approval')
        or die;

    my ( $result, $msg ) = $template->Parse(
        TicketObj => $top,
        TransactionObj => $to,
    );
    $self->TicketObj->Comment( CcMessageTo => $self->TicketObj->OwnerObj->EmailAddress,
                               MIMEObj => $template->MIMEObj );

}

1;

package RT::Approval::Rule::Passed;
use strict;
use warnings;
use base 'RT::Approval::Rule';

use constant Description => "If an approval is rejected, reject the original and delete pending approvals"; # loc

sub Prepare {
    my $self = shift;
    return unless $self->SUPER::Prepare();

    $self->OnStatusChange('resolved');
}

sub Commit {    # XXX: from custom prepare code
    my $self = shift;
    my $note;
    my $t = $self->TicketObj->Transactions;
    while ( my $o = $t->Next ) {
        $note .= $o->Content . "\n" if $o->ContentObj
                and $o->Content !~ /Default Approval/;
    }

    foreach my $obj ( $self->TicketObj->AllDependedOnBy( Type => 'ticket' ) ) {
        $obj->Comment(
            Content => $self->loc( "Your request has been approved by [_1]. Other approvals may still be pending.", # loc
                $self->TransactionObj->CreatorObj->Name,
                ) . "\n" . $self->loc( "Approver's notes: [_1]",    # loc
                $note
                ),
        );
        $T::Approval = $self->TicketObj; # so we can access it inside templates
        $self->{TicketObj} = $obj; # we want the original id in the token line
    }

    $self->RunScripAction('Notify Requestors', 'Approval Passed');
}

1;

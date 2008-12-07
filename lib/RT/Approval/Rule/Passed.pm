package RT::Approval::Rule::Passed;
use strict;
use warnings;
use base 'RT::Approval::Rule';

use constant Description => "Notify Owner of their ticket has been approved by some or all approvers"; # loc

sub Prepare {
    my $self = shift;
    return unless $self->SUPER::Prepare();

    $self->OnStatusChange('resolved');
}

sub Commit {
    my $self = shift;
    my $note;
    my $t = $self->TicketObj->Transactions;

    while ( my $o = $t->Next ) {
        $note .= $o->Content . "\n" if $o->ContentObj
                and $o->Content !~ /Default Approval/;
    }
    my ($Approval) = $self->TicketObj->AllDependedOnBy( Type => 'ticket' );
    my $links  = $self->TicketObj->DependedOnBy;
    my $passed = 0;

    while ( my $link = $links->Next ) {
        my $obj = $link->BaseObj;
        next if ( $obj->HasUnresolvedDependencies( Type => 'approval' ) );

        if ( $obj->Type eq 'ticket' ) {
            $obj->Comment(
                Content => $self->loc("Your request has been approved."),
            );
            $passed = 1;
        }
        elsif ( $obj->Type eq 'approval' ) {
            $obj->SetStatus( Status => 'open', Force => 1 );
        }
    }

    unless ($passed) {
        $Approval->Comment(
            Content => $self->loc( "Your request has been approved by [_1]. Other approvals may still be pending.", # loc
                $self->TransactionObj->CreatorObj->Name,
                ) . "\n" . $self->loc( "Approver's notes: [_1]",    # loc
                $note
                ),
        );
    }

    $T::Approval = $self->TicketObj; # so we can access it inside templates
    $self->RunScripAction('Notify Requestors',
                          $passed ? 'All Approvals Passed' : 'Approval Passed',
                          TicketObj => $Approval,
                      );
}

1;

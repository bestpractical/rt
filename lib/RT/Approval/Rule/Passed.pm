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
        next unless $o->Type eq 'Correspond';
        $note .= $o->Content . "\n" if $o->ContentObj;
    }
    my ($top) = $self->TicketObj->AllDependedOnBy( Type => 'ticket' );
    my $links  = $self->TicketObj->DependedOnBy;

    while ( my $link = $links->Next ) {
        my $obj = $link->BaseObj;
        next unless $obj->Type eq 'approval';
        next if $obj->HasUnresolvedDependencies( Type => 'approval' );

        $obj->SetStatus( Status => 'open', Force => 1 );
    }

    my $passed = !$top->HasUnresolvedDependencies( Type => 'approval' );
    my $template = $self->GetTemplate(
        $passed ? 'All Approvals Passed' : 'Approval Passed',
        TicketObj => $top,
        Approval => $self->TicketObj,
        Notes => $note,
    ) or die;

    $top->Correspond( MIMEObj => $template->MIMEObj );
    return;
}

1;

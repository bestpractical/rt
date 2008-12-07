package RT::Approval::Rule::Rejected;
use strict;
use warnings;
use base 'RT::Approval::Rule';

use constant Description => "If an approval is rejected, reject the original and delete pending approvals"; # loc

sub Prepare {
    my $self = shift;
    return unless $self->SUPER::Prepare();

    return (0)
        unless $self->OnStatusChange('rejected') or $self->OnStatusChange('deleted')
}

sub Commit {    # XXX: from custom prepare code
    my $self = shift;

    my $rejected = 0;
    my $links    = $self->TicketObj->DependedOnBy;
    foreach my $link ( @{ $links->ItemsArrayRef } ) {
        my $obj = $link->BaseObj;
        if ( $obj->QueueObj->IsActiveStatus( $obj->Status ) ) {
            if ( $obj->Type eq 'ticket' ) {
                $obj->Comment(
                    Content => $self->loc("Your request was rejected."),
                );
                $obj->SetStatus(
                    Status => 'rejected',
                    Force  => 1,
                );

                $T::Approval = $self->TicketObj; # so we can access it inside templates
                $self->{TicketObj} = $obj; # we want the original id in the token line
                $rejected = 1;
            }
            else {
                $obj->SetStatus(
                    Status => 'deleted',
                    Force  => 1,
                );
            }
        }
    }

    $links = $self->TicketObj->DependsOn;
    foreach my $link ( @{ $links->ItemsArrayRef } ) {
        my $obj = $link->TargetObj;
        if ( $obj->QueueObj->IsActiveStatus( $obj->Status ) ) {
            $obj->SetStatus(
                Status => 'deleted',
                Force  => 1,
            );
        }
    }

    return $self->RunScripAction('Notify Requestors', 'Approvals Rejected')
        if $rejected;
}

1;

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
    if ( my ($rejected) =
        $self->TicketObj->AllDependedOnBy( Type => 'ticket' ) ) {
        my $template = RT::Template->new( $self->CurrentUser );
        $template->Load('Approval Rejected')
            or die;

        my ( $result, $msg ) = $template->Parse(
            TicketObj => $rejected,
            Approval  => $self->TicketObj,
            Notes     => '',
        );

        $rejected->Correspond( MIMEObj => $template->MIMEObj );
        $rejected->SetStatus(
            Status => 'rejected',
            Force  => 1,
        );
    }
    my $links = $self->TicketObj->DependedOnBy;
    foreach my $link ( @{ $links->ItemsArrayRef } ) {
        my $obj = $link->BaseObj;
        if ( $obj->QueueObj->IsActiveStatus( $obj->Status ) ) {
            if ( $obj->Type eq 'approval' ) {
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

}

1;

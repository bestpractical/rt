package RT::Approval::Rule::AllPassed;
use strict;
use warnings;
use base 'RT::Approval::Rule::Passed';

use constant Description => "When a ticket has been approved by all approvers, add correspondence to the original ticket"; # loc

sub Commit {    # XXX: from custom prepare code
    my $self   = shift;
    my $Ticket = $self->TicketObj;
    my @TOP    = $Ticket->AllDependedOnBy( Type => 'ticket' );
    my $links  = $Ticket->DependedOnBy;
    my $passed = 0;

    while ( my $link = $links->Next ) {
        my $obj = $link->BaseObj;
        next if ( $obj->HasUnresolvedDependencies( Type => 'approval' ) );

        if ( $obj->Type eq 'ticket' ) {
            $obj->Comment(
                Content => $self->loc("Your request has been approved."),
            );
            $T::Approval = $Ticket;    # so we can access it inside templates
            $self->{TicketObj} = $obj; # we want the original id in the token line
            $passed = 1;
        }
        elsif ( $obj->Type eq 'approval' ) {
            $obj->SetStatus( Status => 'open', Force => 1 );
        }
        elsif ( RT->Config->Get('UseCodeTickets') and $obj->Type eq 'code' ) {

            #XXX: RT->Config->Get('UseCodeTickets') used only once here!!!
            my $code = $obj->Transactions->First->Content;
            my $rv;

            foreach my $TOP (@TOP) {
                local $@;
                $rv++ if eval $code;
                $RT::Logger->error("Cannot eval code: $@") if $@;
            }

            if ( $rv or !@TOP ) {
                $obj->SetStatus( Status => 'resolved', Force => 1, );
            }
            else {
                $obj->SetStatus( Status => 'rejected', Force => 1, );
            }
        }
    }

    $self->RunScripAction('Notify Requestors', 'All Approvals Passed');
}

1;

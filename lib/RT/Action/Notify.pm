#$Header: /raid/cvsroot/rt/lib/RT/Action/Notify.pm,v 1.4 2002/01/11 00:02:34 jesse Exp $

package RT::Action::Notify;
require RT::Action::SendEmail;
@ISA = qw(RT::Action::SendEmail);

# {{{ sub SetRecipients

=head2 SetRecipients

Sets the recipients of this meesage to Owner, Requestor, AdminCc, Cc or All. 
Explicitly B<does not> notify the creator of the transaction.

=cut

sub SetRecipients {
    my $self = shift;

    $arg = $self->Argument;

    $arg =~ s/\bAll\b/Owner,Requestor,AdminCc,Cc/;

    my ( @To, @PseudoTo, @Cc, @Bcc );


    if ($arg =~ /\bOtherRecipients\b/) {
        if ($self->TransactionObj->Message->First) {
            push (@Cc, $self->TransactionObj->Message->First->GetHeader('RT-Send-Cc'));
            push (@Bcc, $self->TransactionObj->Message->First->GetHeader('RT-Send-Bcc'));
        }
    }

    if ( $arg =~ /\bRequestor\b/ ) {
        push ( @To, $self->TicketObj->Requestors->MemberEmailAddresses  );
    }

    

    if ( $arg =~ /\bCc\b/ ) {

        #If we have a To, make the Ccs, Ccs, otherwise, promote them to To
        if (@To) {
            push ( @Cc, $self->TicketObj->Cc->MemberEmailAddresses );
            push ( @Cc, $self->TicketObj->QueueObj->Cc->MemberEmailAddresses  );
        }
        else {
            push ( @Cc, $self->TicketObj->Cc->MemberEmailAddresses  );
            push ( @To, $self->TicketObj->QueueObj->Cc->MemberEmailAddresses  );
        }
    }

    if ( ( $arg =~ /\bOwner\b/ )
        && ( $self->TicketObj->OwnerObj->id != $RT::Nobody->id ) )
    {

        # If we're not sending to Ccs or requestors, 
        # then the Owner can be the To.
        if (@To) {
            push ( @Bcc, $self->TicketObj->OwnerObj->EmailAddress );
        }
        else {
            push ( @To, $self->TicketObj->OwnerObj->EmailAddress );
        }

    }

    if ( $arg =~ /\bAdminCc\b/ ) {
        push ( @Bcc, $self->TicketObj->AdminCc->MemberEmailAddresses  );
        push ( @Bcc, $self->TicketObj->QueueObj->AdminCc->MemberEmailAddresses  );
    }

    if ($RT::UseFriendlyToLine) {
        unless (@To) {
            push ( @PseudoTo,
                "'$arg of $RT::rtname Ticket #"
                  . $self->TicketObj->id . "':;" );
        }
    }

    my $creator = $self->TransactionObj->CreatorObj->EmailAddress();

    #Strip the sender out of the To, Cc and AdminCc and set the 
    # recipients fields used to build the message by the superclass.

    $RT::Logger->debug("$self: To is ".join(",",@To));
    $RT::Logger->debug("$self: Cc is ".join(",",@Cc));
    $RT::Logger->debug("$self: Bcc is ".join(",",@Bcc));

    @{ $self->{'To'} }  = grep ( !/^$creator$/, @To );
    @{ $self->{'Cc'} }  = grep ( !/^$creator$/, @Cc );
    @{ $self->{'Bcc'} } = grep ( !/^$creator$/, @Bcc );
    @{ $self->{'PseudoTo'} } = @PseudoTo;
    return (1);

}

# }}}

1;

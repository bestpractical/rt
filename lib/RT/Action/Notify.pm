#$Header$

package RT::Action::Notify;
require RT::Action::SendEmail;
@ISA = qw(RT::Action::SendEmail);


sub SetRecipients {
    my $self=shift;

    $arg=$self->Argument;

    $arg =~ s/\bAll\b/Owner,Requestor,AdminCc,Cc/;
    

    my (@To, @Cc, @Bcc, $To, $Cc, $Bcc);

    if ($arg =~ /\bRequestor\b/) {
	push(@To, $self->TicketObj->RequestorsAsString);
    }
    
    
    
    if ($arg =~ /\bCc\b/) {
	#If we have a To, make the Ccs, Ccs, otherwise, promote them to To
	if (@To) {
	    push(@Cc, $self->TicketObj->CcAsString);
	    push(@Cc, $self->TicketObj->QueueObj->CcAsString);
	} else {
	    push(@Cc, $self->TicketObj->CcAsString);
	    push(@To, $self->TicketObj->QueueObj->CcAsString);
	}
    }
    
    
    if ($arg =~ /\bOwner\b/ && ($self->TicketObj->OwnerObj->id != $RT::Nobody->id)) {
	#If we're not sending to Ccs or requestors, then the Owner can be the To.
	if (@To) {
	    push(@Bcc, $self->TicketObj->OwnerObj->EmailAddress);
	}
	else {
	    push(@To, $self->TicketObj->OwnerObj->EmailAddress);
	}
	
    }
    
    
    if ($arg =~ /\bAdminCc\b/) {
        push(@Bcc, $self->TicketObj->AdminCcAsString);
	    push(@Bcc, $self->TicketObj->QueueObj->AdminCcAsString);
    }
    

    if (@To) {
	$To = join(',',@To);
    }
    else {
	$To = "'$arg of $RT::rtname Ticket #".$self->TicketObj->id.":' ;";
    }
    
    $Cc = join(',',@Cc);
    $Bcc = join(',',@Bcc);
    
    $self->SetTo($To);
    $self->SetCc($Cc);
    $self->SetBcc($Bcc);
    
    return(1);

}


1;

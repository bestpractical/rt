#$Header$

package RT::Action::Notify;
require RT::Action::SendEmail;
@ISA = qw(RT::Action::SendEmail);


# {{{ sub SetRecipients

=head2 SetRecipients

Sets the recipients of this meesage to Owner, Requestor, AdminCc, Cc or All. 
Explicitly B<does not> notify the creator of the transaction.

=cut


sub SetRecipients {
    my $self=shift;

    $arg=$self->Argument;

    $arg =~ s/\bAll\b/Owner,Requestor,AdminCc,Cc/;
    
    my (@To, @Cc, @Bcc);

    if ($arg =~ /\bRequestor\b/) {
	push(@To, @{$self->TicketObj->Requestors->Emails});
    }
        
    if ($arg =~ /\bCc\b/) {
	#If we have a To, make the Ccs, Ccs, otherwise, promote them to To
	if (@To) {
	    push(@Cc, @{$self->TicketObj->Cc->Emails});
	    push(@Cc, @{$self->TicketObj->QueueObj->Cc->Emails});
	} else {
	    push(@Cc, @{$self->TicketObj->CcAsString});
	    push(@To, @{$self->TicketObj->QueueObj->Cc->Emails});
	}
    }
    
    if ( ($arg =~ /\bOwner\b/) && 
	 ($self->TicketObj->OwnerObj->id != $RT::Nobody->id) ) {
	# If we're not sending to Ccs or requestors, 
	# then the Owner can be the To.
	if (@To) {
	    push(@Bcc, $self->TicketObj->OwnerObj->EmailAddress);
	}
	else {
	    push(@To, $self->TicketObj->OwnerObj->EmailAddress);
	}
	
    }
    
    if ($arg =~ /\bAdminCc\b/) {
        push(@Bcc, @{$self->TicketObj->AdminCc->Emails});
	push(@Bcc, @{$self->TicketObj->QueueObj->AdminCc->Emails});
    }

    if ($RT::UseFriendlyToLine) {    
    	unless (@To) {
	    push (@To,  "'$arg of $RT::rtname Ticket #".$self->TicketObj->id."':;");
	}
    } 
    
    my $creator = $self->TransactionObj->CreatorObj->EmailAddress();
      
    #Strip the sender out of the To, Cc and AdminCc and set the 
    # recipients fields used to build the message by the superclass.
    @{$self->{'To'}} = grep (!/^$creator$/, @To);
    @{$self->{'Cc'}} = grep (!/^$creator$/, @Cc);
    @{$self->{'Bcc'}} = grep (!/^$creator$/, @Bcc);
        
    return(1);

}

# }}}

1;

package RT::Action::Notify
require RT::Action::SendEmail;
@ISA = qw(RT::Action::SendEmail);

# TODO: This one should take the Argument from the Scrips and set the
# recipients unless they're listed in the template itself.

sub SetRecipients {
    my $self=shift;

    # The logic here could of course be placed either in three
    # separate SetBcc, SetTo and SetCc subs, or in a Prepare-sub.
    # Anyway, I think having a "SetRecipients" is a good idea, I
    # think the Receipients belong to some kind of a logical unit
    # ... they shouldn't be set completely independently from each
    # other.

    $self->Argument =~ s/\bAll\b/Owner,Requestor,AdminCc,Cc/;

    if ($self->Argument =~ /\bOwner\b/) {
	$self->{To}=join(",", $self->TicketObj->Owner->Email, $self->{To});
    }

    if ($self->Argument =~ /\bRequestor\b/) {
	$self->{To}=join(",", $self->TicketObj->RequestorsAsString, $self->{To});
    }

    # Will send to AdminCc as Bcc if there are other receipients, and
    # as To if there aren't
    if ($self->Argument =~ /\bAdminCc\b/) {
	if ($` || $') {
	    $self->{Bcc}=join(",", $self->TicketObj->AdminCcAsString, $self->{Bcc});
	} else {
	    $self->{To}=join(",", $self->TicketObj->AdminCcAsString, $self->{To});
	}
    }

    # Will use Cc as To if there aren't any To.
    if ($self->Argument =~ /\bCc\b/) {
	if ($self->{To}) {
	    $self->{Cc}=join(",", $self->TicketObj->CcAsString, $self->{Cc});
	} else {
	    $self->{To}=$self->TicketObj->CcAsString;
	}
    }
}




package RT::Action::Notify;
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

    $arg=$self->Argument;
    $arg =~ s/\bAll\b/Owner,Requestor,AdminCc,Cc/;

    if ($arg =~ /\bOwner\b/ && $self->TicketObj->Owner) {
	push(@{$self->{To}}, $self->TicketObj->Owner->EmailAddress);
    }

    if ($arg =~ /\bRequestor\b/) {
	push(@{$self->{To}}, $self->TicketObj->RequestorsAsString);
    }

    # Will send to AdminCc as Bcc if there are other receipients, and
    # as To if there aren't
    if ($arg =~ /\bAdminCc\b/) {
	if ($` || $') {
	    push(@{$self->{Bcc}}, $self->TicketObj->AdminCcAsString);
	} else {
	    push(@{$self->{To}}, $self->TicketObj->AdminCcAsString);
	}
    }

    # Will use Cc as To if there aren't any To.
    if ($arg =~ /\bCc\b/) {
	if (@{$self->{To}}) {
	    push(@{$self->{Cc}}, $self->TicketObj->CcAsString);
	} else {
	    push(@{$self->{To}}, $self->TicketObj->CcAsString);
	}
    }

    return 0 unless (exists $self->{To} && defined $self->{To} && @{$self->{To}});

    return $self->SUPER::SetRecipients;
}




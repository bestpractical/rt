#$Header$

package RT::Action::Autoreply;
require RT::Action::SendEmail;
@ISA = qw(RT::Action::SendEmail);


# {{{ sub SetRecipients

=head2 SetRecipients

Sets the recipients of this message to this ticket's Requestor.

=cut


sub SetRecipients {
    my $self=shift;

    push(@To, @{$self->TicketObj->Requestors->Emails});
    my $To = join(',',@To);
    
    $self->SetTo($To);
    return(1);
}

# }}}

1;

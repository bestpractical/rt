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


# {{{ sub SetReturnAddress 

=head2 SetReturnAddress

Set this message's return address to the apropriate queue address

=cut

sub SetReturnAddress {

  my $self = shift;
  
  # From and Reply-To
  # $self->{comment} should be set if the comment address is to be used.
  my $email_address=$self->{comment} ? 
    $self->TicketObj->QueueObj->CommentAddress :
      $self->TicketObj->QueueObj->CorrespondAddress
        or $RT::Logger->warning( "$self Can't find email address for queue" . $TicketObj->QueueObj->Name."\n");
  
  
  unless ($self->TemplateObj->MIMEObj->head->get('From')) {
      my $friendly_name=$self->TransactionObj->CreatorObj->RealName;
      # TODO: this "via RT" should really be site-configurable.
      $self->SetHeader('From', "RT <$email_address>");
  }
  
  unless ($self->TemplateObj->MIMEObj->head->get('Reply-To')) {
      $self->SetHeader('Reply-To', "$email_address");
  }
  
}

# }}}

1;

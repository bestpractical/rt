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

    push(@{$self->{'To'}}, @{$self->TicketObj->Requestors->Emails});
    
    return(1);
}

# }}}


# {{{ sub SetReturnAddress 

=head2 SetReturnAddress

Set this message\'s return address to the apropriate queue address

=cut

sub SetReturnAddress {
    my $self = shift;
    my %args = ( is_comment => 0,
		 @_
	       );
    
    if ($args{'is_comment'}) { 
	$replyto = $self->TicketObj->QueueObj->CommentAddress || 
		     $RT::CommentAddress;
    }
    else {
	$replyto = $self->TicketObj->QueueObj->CorrespondAddress ||
		     $RT::CorrespondAddress;
    }
    
    unless ($self->TemplateObj->MIMEObj->head->get('From')) {
	my $friendly_name=$self->TransactionObj->CreatorObj->RealName;
	# TODO: this "via RT" should really be site-configurable.
	$self->SetHeader('From', "RT <$replyto>");
    }
    
    unless ($self->TemplateObj->MIMEObj->head->get('Reply-To')) {
	$self->SetHeader('Reply-To', "$replyto");
    }
    
}
  
# }}}

1;

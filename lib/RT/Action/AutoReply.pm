# $Header$

package RT::Action::AutoReply;

require RT::Action::SendEmail;
@ISA = qw(RT::Action::SendEmail);

# {{{ sub Describe
sub Describe  {
  return ("Sends an autoresponse to the requestor");
}
# }}}

# {{{ sub Commit 
sub Commit  {
  my $self = shift;
  print STDERR "AutoReply Commiting\n";

  #
  # Here's where you'd do any special things you want to 
  # to on commit.

  #You must _always_ call Super::Commit();
  return($self->SUPER::Commit());
}
# }}}

# {{{ sub Prepare 
sub Prepare  {
  my $self = shift;

  # This stub is where you would insert any special 
  # Headers you'd want to add to the mail message.
  # For example:

  # $self->{'Header'}->add('RT-Action-Type', "Autoreply");
  
  #You _always_ need to run SUPER::Prepare();
  return ($self->SUPER::Prepare());
}
# }}}

# {{{ sub SetSubject
sub SetSubject {
  my $self = shift;
  
  #If the template has a subject line already, we do nothing.
  unless ($self->TemplateObj->MIMEObj->head->get(Subject)) {
    
    # Make the subject the Ticket's subject.
    $self->{Subject}=$self->TicketObj->Subject() || "(no subject)";
    
    #Set the header object's notion of the subject.
    $self->TemplateObj->MIMEObj->head->add('Subject',"AutoReply ($$self{Subject})");
    
  }
}

# }}}

# {{{ sub SetReturnAddress 

# The return address set by SendEmail includes the name of the 
# actor, which we really don't want here. So we slam our
# routine on top of SendEmail's

sub SetReturnAddress {
  my $self = shift;
  
  # From and Reply-To
  # If we don't have a CorrespondAddress, we should RT's default 
  # correspond address
  my $email_address = $self->TicketObj->Queue->CorrespondAddress ? 
    $self->TicketObj->Queue->CorrespondAddress :
      $RT::CorrespondAddress
	or warn "Can't find email address for queue?";
  
  
  unless ($self->TemplateObj->MIMEObj->head->get('From')) {
    my $friendly_name=$self->{TransactionObj}->Creator->RealName;
    $self->TemplateObj->MIMEObj->head->add('From', "Request Tracker <$email_address>");
    $self->TemplateObj->MIMEObj->head->add('Reply-To', "$email_address");
  }
  



}

# }}}

1;





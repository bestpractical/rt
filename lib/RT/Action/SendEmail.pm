# $Header$
# Copyright 2000  Jesse Vincent <jesse@fsck.com> and Tobias Brox <tobix@cpan.org>
# Released under the terms of the GNU Public License

package RT::Action::SendEmail;
require RT::Action::Generic;

@ISA = qw(RT::Action::Generic);


=head1 NAME

  RT::Action::SendEmail - An Action which users can use to send mail 
  or can subclassed for more specialized mail sending behavior. 
  RT::Action::AutoReply is a good example subclass.


=head1 SYNOPSIS
  require RT::Action::SendEmail;
  @ISA  = qw(RT::Action::SendEmail);


=head1 DESCRIPTION

Basically, you create another module RT::Action::YourAction which ISA
RT::Action::SendEmail.

If you want to set the recipients of the mail to something other than
the addresses mentioned in the To, Cc, Bcc and headers in
the template, you should subclass RT::Action::SendEmail and override
either the SetRecipients method or the SetTo, SetCc, etc methods (see
the comments for the SetRecipients sub).


=head1 AUTHOR

Jesse Vincent <jesse@fsck.com> and Tobias Brox <tobix@cpan.org>

=head1 SEE ALSO

perl(1).

=cut

# {{{ Scrip methods (_Init, Commit, Prepare, IsApplicable)

# {{{ sub _Init 
# We use _Init from RT::Action
# }}}

# {{{ sub Commit 
#Do what we need to do and send it out.
sub Commit  {
    my $self = shift;
    #send the email
    
    # If there are no recipients, don't try to send the message.
    # If the transaction has content and has the header RT-Squelch-Replies-To
   
    if ($defined $self->TransactionObj->Message->First()) { 
    my $headers = $self->TransactionObj->Message->First->Headers();
    if ($headers =~ /^RT-Squelch-Replies-To: (.*?)$/si) {
  	my $blacklist = $1;
	
	# Cycle through the people we're sending to
	my @headers = qw (To Cc Bcc);
	
	# if a to address contains anyone in the squelch replies to, yank it out.
	while ( my $line =  $self->TemplateObj->MIMEObj->head->get($header)) {
	    if ($line =~ s/ $blacklist,//)  {
		$ $self->TemplateObj->MIMEObj->head->replace($header, $line);
	    }
	}
    }
    }
    $self->TemplateObj->MIMEObj->make_singlepart;
    
    $self->TemplateObj->MIMEObj->send($RT::MailCommand, $RT::MailParams) || 
      $RT::Logger->crit("$self: Could not send mail for ".$self->TransactionObj . "\n");
}
    

# }}}

# {{{ sub Prepare 

sub Prepare  {
  my $self = shift;
  
  # This actually populates the MIME::Entity fields in the Template Object
  
  $RT::Logger->debug("Now entering $self -> Prepare\n");
  unless ($self->TemplateObj) {
      $RT::Logger->debug("No template object handed to $self\n");
  }
  
  unless ($self->TransactionObj) {
      $RT::Logger->debug("No transaction object handed to $self\n");
      
  }
  
  unless ($self->TicketObj) {
      $RT::Logger->debug("No ticket object handed to $self\n");
      
  }
  
  
  $self->TemplateObj->Parse(Argument => $self->Argument,
			    TicketObj => $self->TicketObj, 
			    TransactionObj => $self->TransactionObj);
  
  # Header
  
  $self->SetSubject();
  $self->SetSubjectToken();
  $self->SetRecipients();  
  
  $self->SetReturnAddress();
  
  $self->SetRTSpecialHeaders();


  # Todo: add "\n-------------------------------------------- Managed by Request Tracker\n\n" to the message body
    
  return 1;
  
}

# }}}

# }}}

# {{{ Deal with message headers (Set* subs, designed for  easy overriding)

# {{{ sub SetRTSpecialHeaders

# This routine adds all the random headers that RT wants in a mail message
# that don't matter much to anybody else.

sub SetRTSpecialHeaders {
    my $self = shift;
    
    $self->SetReferences();

    $self->SetMessageID();
    
    $self->SetPrecedence();
        
    $self->TemplateObj->MIMEObj->head->add('RT-Ticket', $RT::rtname. " #".$self->TicketObj->id());
    $self->TemplateObj->MIMEObj->head->add
      ('Managed-By',"Request Tracker $RT::VERSION (http://www.fsck.com/projects/rt)");
    
    $self->TemplateObj->MIMEObj->head->add('RT-Originator', $self->TransactionObj->CreatorObj->EmailAddress);
    return();
    
}



# {{{ sub SetReferences

=head2 SetReferences 
  
  # This routine will set the References: and In-Reply-To headers,
# autopopulating it with all the correspondence on this ticket so
# far. This should make RT responses threadable.

=cut

sub SetReferences {
  my $self = shift;
  
  # TODO: this one is broken.  What is this email really a reply to?
  # If it's a reply to an incoming message, we'll need to use the
  # actual message-id from the appropriate Attachment object.  For
  # incoming mails, we would like to preserve the In-Reply-To and/or
  # References.

  $self->TemplateObj->MIMEObj->head->add
    ('In-Reply-To', "<rt-".$self->TicketObj->id().
     "\@".$RT::rtname.">");


  # TODO $RT::rtname should be replaced by $RT::hostname to form valid
  # message-ids (ref rfc822)

  # TODO We should always add References headers for all message-ids
  # of previous messages related to this ticket.
}

# }}}

# {{{ sub SetMessageID

# Without this one, threading won't work very nice in email agents.
# Anyway, I'm not really sure it's that healthy if we need to send
# several separate/different emails about the same transaction.

sub SetMessageID {
  my $self = shift;

  # TODO this one might be sort of broken.  If we have several scrips +++
  # sending several emails to several different persons, we need to
  # pull out different message-ids.  I'd suggest message ids like
  # "rt-ticket#-transaction#-scrip#-receipient#"

  # TODO $RT::rtname should be replaced by $RT::hostname to form valid
  # message-ids (ref rfc822)
  
  $self->TemplateObj->MIMEObj->head->add
    ('Message-ID', "<rt-".$self->TicketObj->id().
     "-".
     $self->TransactionObj->id()."." .rand(20) . "\@".$RT::rtname.">")
      unless $self->TemplateObj->MIMEObj->head->get('Message-ID');
}


# }}}

# }}}

# {{{ sub SetReturnAddress 

sub SetReturnAddress {

  my $self = shift;
  
  # From and Reply-To
  # $self->{comment} should be set if the comment address is to be used.
  my $email_address=$self->{comment} ? 
    $self->TicketObj->QueueObj->CommentAddress :
      $self->TicketObj->QueueObj->CorrespondAddress
	or warn "Can't find email address for queue?";
  
  
  unless ($self->TemplateObj->MIMEObj->head->get('From')) {
      my $friendly_name=$self->TransactionObj->CreatorObj->RealName;
      # TODO: this "via RT" should really be site-configurable.
      $self->TemplateObj->MIMEObj->head->add('From', "$friendly_name via RT <$email_address>");
  }
  
  unless ($self->TemplateObj->MIMEObj->head->get('Reply-To')) {
      $self->TemplateObj->MIMEObj->head->add('Reply-To', "$email_address");
  }
  
}

# }}}




# {{{ sub SetHeader

sub SetHeader {
  my $self = shift;
  my $field = shift;
  my $val = shift;

  my $cnt=0;
  $self->TemplateObj->MIMEObj->head->add($field, $val);
  return $self->TemplateObj->MIMEObj->head->get($field);
}

# }}}

# {{{ sub SetTo

sub SetTo {
    my $self=shift;
    my $addresses = shift;
    return $self->SetHeader('To',$addresses);
}
# }}}

# {{{ sub SetCc
=head2 SetCc

Takes a string that is the addresses you want to Cc

=cut

sub SetCc {
    my $self=shift;
    my $addresses = shift;

    return $self->SetHeader('Cc', $addresses);
}
# }}}

# {{{ sub SetBcc

=head2 SetBcc

Takes a string that is the addresses you want to Bcc

=cut
sub SetBcc {
    my $self=shift;
    my $addresses = shift;

    return $self->SetHeader('Bcc', $addresses);
}

# }}}

# {{{ sub SetPrecedence 

sub SetPrecedence {
  my $self = shift;

  $self->TemplateObj->MIMEObj->head->add('Precedence', "bulk");
}

# }}}

# {{{ sub SetSubject

=head2 SetSubject

This routine sets the subject. it does not add the rt tag. that gets done elsewhere
If $self->{'Subject'} is already defined, it uses that. otherwise, it tries to get
the transaction's subject.

=cut 

sub SetSubject {
  my $self = shift;
  unless ($self->TemplateObj->MIMEObj->head->get(Subject)) {
      my $m=$self->TransactionObj->Message->First;
      my $ticket=$self->TicketObj->Id;
      ($self->{Subject})=$m->Headers =~ /^Subject: (.*)$/m
	  if $m;
      $self->{Subject}=$self->TicketObj->Subject()
	  unless $self->{Subject};
      
      $self->TemplateObj->MIMEObj->head->add('Subject',"$$self{Subject}");

  }

  return($self->{'Subject'});
}
# }}}

# {{{ sub SetSubjectToken

=head2 SetSubjectToken

 This routine fixes the RT tag in the subject. It's unlikely that you want to overwrite this.

=cut

sub SetSubjectToken {
    my $self=shift;
    my $tag = "[$RT::rtname #".$self->TicketObj->id."]";
    my $sub = $self->TemplateObj->MIMEObj->head->get('subject');
    $self->TemplateObj->MIMEObj->head->replace('subject', "$tag $sub")
      unless $sub =~ /\Q$tag\E/;
}

# }}}

# }}}

__END__

# {{{ POD

# }}}

1;



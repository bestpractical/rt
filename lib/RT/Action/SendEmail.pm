# $Header$
# Copyright 2000 Tobias Brox <tobix@cpan.org> and  Jesse Vincent <jesse@fsck.com>
# Released under the terms of the GNU Public License

package RT::Action::SendEmail;

require RT::Action;

@ISA = qw(RT::Action);


# {{{ sub _Init 
# We use _Init from RT::Action
# }}}




#
# Scrip methods
#


#Do what we need to do and send it out.

# {{{ sub Commit 
sub Commit  {
  my $self = shift;
  #send the email

  print STDERR "About to Commit a mail message\n";

  my @body = grep($_ .= "\n", split(/\n/,$self->{'Body'}));

  #TODO HACKISH
  open(SENDMAIL,"|/usr/lib/sendmail -oi -t");

  # We should have some kind of site specific configuration here.  I
  # think the default method for sending an email should be
  # send('sendmail'), but some RT installations might want to use the
  # smtpsend method anyway.
  $self->TemplateObj->MIMEObj->print(\*SENDMAIL);
#  $self->TemplateObj->MIMEObj->smtpsend(Host => 'localhost') || die "could not send email";

  #TODO: enable this once tobix' new Mail::Internet is out there.
  #$self->{'TemplateObj'}->send('sendmail'); || die "Could not send mail;

  # TODO Tell the administrator that RT couldn't send mail
  close(SENDMAIL)

}
# }}}

# {{{ sub Prepare 

sub Prepare  {
  my $self = shift;

  # This actually populates the MIME::Entity fields in the Template Object

  $self->TemplateObj->Parse(TicketObj => $self->TicketObj, 
			    TransactionObj => $self->TransactionObj);


  # Header
  
  # Maybe it's better to separate out _all_ headers/group of headers
  # to make it easier to customize subclasses?  nah ... 

  # Yes, actually --jesse ;)

  $self->SetSubject();

  my $sub = $self->TemplateObj->MIMEObj->head->get('subject');
  $self->TemplateObj->MIMEObj->head->replace('subject', "[$RT::rtname #".$self->TicketObj->id."] $sub");  

  $self->SetReturnAddress();

  $self->SetContentType();

  $self->SetRTSpecialHeaders();

  $self->SetReferences();

  $self->SetMessageID();

  $self->SetPrecedence();

  # Is it any reason why we need three separate subs for this?  I can
  # hardly see that they will operate that differently. --TobiX

  $self->SetTo();

  $self->SetCc();

  $self->SetBcc();

 $self->{'Body'} .= 
    "\n-------------------------------------------- Managed by Request Tracker\n\n";
  


}

# }}}

# {{{ sub SetRTSpecialHeaders

# This routine adds all the random headers that RT wants in a mail message
# that don't matter much to anybody else.

sub SetRTSpecialHeaders {
  my $self = shift;
    
  unless ($self->TemplateObj->MIMEObj->head->get('RT-Action')) {
    $self->TemplateObj->MIMEObj->head->add('RT-Action', $self->Describe);
  }
  
  unless ($self->TemplateObj->MIMEObj->head->get('RT-Scrip')) {
    $self->TemplateObj->MIMEObj->head->add('RT-Scrip', $self->{'ScripObj'}->Description);
  }
  
  $self->TemplateObj->MIMEObj->head->add('RT-Ticket-ID', $self->TicketObj->id());
  $self->TemplateObj->MIMEObj->head->add('RT-Loop-Prevention', $RT::rtname);

  $self->TemplateObj->MIMEObj->head->add
    ('RT-Managed-By',"Request Tracker $RT::VERSION (http://www.fsck.com/projects/rt)");

  $self->TemplateObj->MIMEObj->head->add('RT-Originator', $self->TransactionObj->Creator->EmailAddress);
  return();

}
# }}}

# {{{ sub SetReferences

# This routine will set the References: and In-Reply-To headers,
# autopopulating it with all the correspondence on this ticket so
# far. This should make RT responses threadable. Yay!

sub SetReferences {
  my $self = shift;
  
  # TODO: this one is broken.  What is this email really a reply to?
  # If it's a reply to an incoming message, we'll need to use the
  # actual message-id from the appropriate Attachment object.  For
  # incoming mails, we would like to preserve the In-Reply-To and/or
  # References.

  $self->TemplateObj->MIMEObj->head->add
    ('In-Reply-To', "<rt-".$self->TicketObj->id().
     "-".
     $self->TransactionObj->id()."\@".$RT::rtname.">");

  # Changed this one to In-Reply-To.  References are mostly used in
  # News.  For email messages one reference is usually enough, and we
  # set it up by In-Reply-To rather than References.  This is mostly
  # IMO as RFC822 (unfortunately) isn't very clear at this.  I'm not
  # familiar with how this is threated in eventual follow-ups of
  # rfc822 --TobiX

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

  # TODO this one might be sort of broken.  If we have several scrips
  # sending several emails to several different persons, we need to
  # pull out different message-ids.  I'd suggest message ids like
  # "rt-ticket#-transaction#-scrip#-receipient#"

  # TODO $RT::rtname should be replaced by $RT::hostname to form valid
  # message-ids (ref rfc822)

  $self->TemplateObj->MIMEObj->head->add
    ('Message-ID', "<rt-".$self->TicketObj->id().
     "-".
     $self->TransactionObj->id()."\@".$RT::rtname.">")
      unless $self->TemplateObj->MIMEObj->head->get('Message-ID');
}


# }}}

# {{{ sub SetContentType
sub SetContentType {
  my $self = shift;
  
  # TODO do we really need this with MIME::Entity? I think it autosets
  # it -- jesse

  # I guess it can autoset Content-Type if it's different from
  # text/plain, but MIME::Entity has no way to determinate what
  # charset a template is written in.  I should know most about this
  # issue; my maid uses ISO-8859-4 and my gf uses KOI-8. :) --TobiX

  # The Template's Content-Type is used when nothing else is set.

  # TODO by default, we should peek at the Content-Type of the
  # transaction message.  BTW, I think our (reply|comment) templates
  # as of today will break if the incoming Message has a different
  # content-type than text/plain.  Eventually we should fix the
  # template system so the original message always will be a separate
  # MIME part.

  unless ($self->TemplateObj->MIMEObj->head->get('Content-Type')) {
      $self->TemplateObj->MIMEObj->head->add('Content-Type', 'text/plain; charset=ISO-8859-1');
  }
return();
}


# }}}

# {{{ sub SetReturnAddress 
sub SetReturnAddress {

  my $self = shift;
  
  # From and Reply-To
  # $self->{comment} should be set if the comment address is to be used.
  my $email_address=$self->{comment} ? 
    $self->TicketObj->Queue->CommentAddress :
      $self->TicketObj->Queue->CorrespondAddress
	or warn "Can't find email address for queue?";
  
  
  unless ($self->TemplateObj->MIMEObj->head->get('From')) {
    my $friendly_name=$self->TransactionObj->Creator->RealName;
    # TODO: this "via RT" should really be site-configurable.
    $self->TemplateObj->MIMEObj->head->add('From', "$friendly_name via RT <$email_address>");
  }
  
  unless ($self->TemplateObj->MIMEObj->head->get('Reply-To')) {
    $self->TemplateObj->MIMEObj->head->add('Reply-To', "$email_address");
  }
  
}

# }}}

# {{{ sub SetEnvelopeTo

# Ehrm ... I thought EnvelopeTo was something that was set by some
# MTAs, not a field that would be respected when calling the MDA /
# sending through SMTP?

sub SetEnvelopeTo {
  my $self = shift;
  #TODO Set Envelope to
  return($self->{'EnvelopeTo'});
}

# }}}

# {{{ sub SetTo

sub SetTo {
  my $self = shift;
  if (exists $self->{'To'}) {
      $self->TemplateObj->MIMEObj->head->add('To', $self->{'To'});
  }
  return($self->{'To'});
}

# }}}

# {{{ sub SetCc

sub SetCc {
  my $self = shift;
  if (exists $self->{'Cc'}) {
      $self->TemplateObj->MIMEObj->head->add('Cc', $self->{'Cc'});
  }
  return($self->{'Cc'});
}

# }}}

# {{{ sub SetBcc

sub SetBcc {
  my $self = shift;
  if (exists $self->{'Bcc'}) {
      $self->TemplateObj->MIMEObj->head->add('Bcc', $self->{'Bcc'});
  }
  return($self->{'Bcc'});
}
# }}}

# {{{ sub SetPrecedence 
sub SetPrecedence {
  
  my $self = shift;
  $self->TemplateObj->MIMEObj->head->add('Precedence', "Bulk");
}


# }}}

# {{{ sub SetSubject

# This routine sets the subject. it does not add the rt tag. that gets done elsewhere

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

  #TODO Set the subject
  return($self->{'Subject'});
}
# }}}

# {{{ sub IsApplicable 
sub IsApplicable  {
  my $self = shift;
  # More work needs to be done here to avoid duplicates beeing sent.
  return(1);
}
# }}}

__END__

=head1 NAME

  RT::Action::SendEmail - An abstract base Action which allows RT::Action modules to send email

=head1 SYNOPSIS
  require RT::Action::SendEmail;
  @ISA qw(RT::Action::SendEmail);


=head1 DESCRIPTION

  Basically, you create another module RT::Action::YourAction which ISA RT::Action::SendEmail

  You'll want to override the SetTo, SetCc, SetBcc, SetEnvelopeTo headers to send mail messages
somewhere other than to the ticket's interested parties. RT::Action::NotifyWatchers would be a
good place to look to see how this works.


=head1 AUTHOR

Jesse Vincent <jesse@fsck.com> and Tobias Brox <tobix@cpan.org>

=head1 SEE ALSO

perl(1).

=cut


1;



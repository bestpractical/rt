# $Header$
# Copyright 2000 Tobias Brox <tobix@cpan.org> and  Jesse Vincent <jesse@fsck.com>
# Released under the terms of the GNU Public License

package RT::Action::SendEmail;

require RT::Action;

@ISA = qw(RT::Action);


# {{{ sub new 
sub new  {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = { @_ };
  bless ($self, $class);
  $self->_Init();
  return $self;
}
# }}}

# {{{ sub _Init 
sub _Init  {
  my $self = shift;
  my $template = shift;
  
  # Load in whatever tempalte we've been called with.
  # RT Templates are subclasses of MIME::Entity, which are subclasses of
  # Mail::Internet.
  require RT::Template;
  $self->{'TemplateObj'}=RT::Template->new;
  $self->{'TemplateObj'}->Load($template);
  # This actually populates the MIME::Entity fields in the Template Object
  $self->{'TemplateObj'}->Parse;


  #TODO: Tobix: what does this do? -jesse
  $self->{'TemplateObj'}->{'Header'}->fold(78);

  return();
}
# }}}

# {{{ sub Commit 
sub Commit  {
  my $self = shift;
  #send the email

  my @body = grep($_ .= "\n", split(/\n/,$self->{'Body'}));


  # This one is stupid.  There are really stability concerns with
  # smtpsend.  We really should call $self->{'Message'}->send instead
  # - unfortunately that sub is not implemented, and probably never
  # will be.  I will probably mash it together myself some day.
  # -- TobiX

  $self->{'TemplateObj'}->smtpsend || die "could not send email";

  #TODO: enable this once tobix' new Mail::Internet is out there.
  #$self->{'TemplateObj'}->send('sendmail'); || die "Could not send mail;

  # TODO Tell the administrator that RT couldn't send mail

}
# }}}

# {{{ sub Prepare 

sub Prepare  {
  my $self = shift;

  # Header
  
  # Maybe it's better to separate out _all_ headers/group of headers
  # to make it easier to customize subclasses?  nah ... 

  # Yes, actually --jesse ;)

  $self->SetSubject();

  #TODO We should _Always_ insert the [RT::rtname #$ticket] tag here.

  $self->SetReturnAddress();

  $self->SetContentType();

  $self->SetRTSpecialHeaders();

  $self->SetReferences();
  #TODO Set up an In-Reply-To maybe.

  $self->SetPrecedence();

 $self->{'Body'} .= 
    "\n-------------------------------------------- Managed by Request Tracker\n\n";
  


}

# }}}

# {{{ sub SetRTSpecialHeaders

# This routine adds all the random headers that RT wants in a mail message
# that don't matter much to anybody else.

sub SetRTSpecialHeaders {
  my $self = shift;
    
  unless ($self->{'Header'}->get('RT-Action')) {
    $self->{'Header'}->add('RT-Action', $self->Describe);
  }
  
  unless ($self->{'Header'}->get('RT-Scrip')) {
    $self->{'Header'}->add('RT-Scrip', $self->{'ScripObject'}->Description);
  }
  
  $self->{'Header'}->add('RT-Ticket-ID', $self->{'TicketObject'}->id());
  $self->{'Header'}->add('RT-Loop-Prevention', $RT::rtname);

  $self->{'Header'}->add
    ('RT-Managed-By',"Request Tracker $RT::VERSION (http://www.fsck.com/projects/rt)");

  $self->{'Header'}->add('RT-Originator', $self->{TransactionObject}->Creator->EmailAddress);
  return();

}
# }}}

# {{{ sub SetReferences

# This routine will set the References: header, autopopulating it with all the correspondence on this
# ticket so far. This should make RT responses threadable. Yay!

sub SetReferences {
  my $self = shift;
  
  $self->{'Header'}->add
    ('References', "<rt-ticket-".$self->{'TicketObject'}->id()."\@".$RT::rtname.">");
    #TODO We should always add References headers for previous messages
  # related to this ticket.
}
# }}}

# {{{ sub SetContentType
sub SetContentType {
  my $self = shift;
  
  
  # TODO do we really need this with MIME::Entity? I think it autosets it -- jesse
  #. ISO-8859-1 just
  # isn't sufficient for international usage (it's even not enough for
  # European usage ... there are people using ISO-8859-2 and KOI-8 and
  # stuff like that).
  # By default, the Template's Content-Type is used. 

  unless ($self->{'Header'}->get('Content-Type')) {
      $self->{'Header'}->add('Content-Type', 'text/plain; charset=ISO-8859-1');
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
      $self->{TicketObject}->Queue->CommentAddress :
      $self->{TicketObject}->Queue->CorrespondAddress
	  or warn "Can't find email address for queue?";


  unless ($self->{'Header'}->get('From')) {
      my $friendly_name=$self->{TransactionObject}->Creator->RealName;
      $self->{'Header'}->add('From', "$friendly_name via RT <$email_address>");
      $self->{'Header'}->add('Reply-To', "$email_address");
  }

}

# }}}

# {{{ sub SetEnvelopeTo

sub SetEnvelopeTo {
  my $self = shift;
  #TODO Set Envelope to
  return($self->{'EnvelopeTo'});
}

# }}}

# {{{ sub SetTo

sub SetTo {
  my $self = shift;
  #TODO Set To
  return($self->{'To'});
}

# }}}

# {{{ sub SetCc

sub SetCc {
  my $self = shift;
  #TODO Set Cc
  return($self->{'Cc'});
}

# }}}

# {{{ sub SetBcc

sub SetBcc {
  my $self = shift;
  #TODO Set Bcc
  return($self->{'Bcc'});
}
# }}}

# {{{ sub SetPrecedence 
sub SetPrecedence {
  
  my $self = shift;
  $self->{'Header'}->add('Precedence', "Bulk");
}


# }}}

# {{{ sub SetSubject

# This routine sets the subject. it does not add the rt tag. that gets done elsewhere

sub SetSubject {
  my $self = shift;
  unless ($self->{'TemplateObj'}->{'Header'}->get(Subject)) {
      my $m=$self->{TransactionObject}->Message->First;
      my $ticket=$self->{TicketObject}->Id;
      ($self->{Subject})=$m->Headers =~ /^Subject: (.*)$/m
	  if $m;
      $self->{Subject}=$self->{TicketObject}->Subject()
	  unless $self->{Subject};
      
      $self->{'Header'}->add('Subject',"$$self{Subject}");

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



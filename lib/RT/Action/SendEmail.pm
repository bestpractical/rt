# $Header$

package RT::Action::SendEmail;

require RT::Action;
require Mail::Internet;
require RT::Template;

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
  $self->{'TemplateObject'}=RT::Template->new;
  $self->{'TemplateObject'}->Load($self->{Template});
  $self->{'Header'} = Mail::Header->new;
  $self->{'Header'}->fold(78);
}
# }}}

# {{{ sub Commit 
sub Commit  {
  my $self = shift;
  #send the email

  # This is way stupid.  The more I fiddle around with Mail::Internet,
  # the more I'm just wanting to throw it out the window. -- TobiX
  my @body = grep($_ .= "\n", split(/\n/,$self->{'Body'}));

  $self->{'Message'}=Mail::Internet->new(Header=>$self->{'Header'}, 
					 Body=>\@body);

  # This one is stupid.  There are really stability concerns with
  # smtpsend.  We really should call $self->{'Message'}->send instead
  # - unfortunately that sub is not implemented, and probably never
  # will be.  I will probably mash it together myself some day.
  # -- TobiX

  $self->{'Message'}->smtpsend || die "could not send email";

  # I would at least expect it to sort the headers in an appropriate
  # order.  It doesn't.
}
# }}}

# {{{ sub Prepare 
sub Prepare  {
  my $self = shift;

  # Perform variable substitution on the template headers
  my $headers=$self->{TemplateObject}->ParseHeaders($self);

  for (split /\n/, $headers) {
      /: /;
      $self->{Header}->add($`, $');
  }

  # Header
  
  # To, bcc and cc
  $self->SetReceipients() || return undef;

  # Maybe it's better to separate out _all_ headers/group of headers
  # to make it easier to customize subclasses?

  # nah ... 

  # Subject
  unless ($self->{'Header'}->get(Subject)) {
      my $m=$self->{TransactionObject}->Message->First;
      my $ticket=$self->{TicketObject}->Id;
      ($self->{Subject})=$m->Headers =~ /^Subject: (.*)$/m
	  if $m;
      $self->{Subject}=$self->{TicketObject}->Subject()
	  unless $self->{Subject};

      $self->{'Header'}->add('Subject', 
			     "[$RT::rtname #$ticket] $$self{Subject}");

  }

  #TODO We should _Always_ insert the [RT::rtname #$ticket] tag here.

  # From, RT-Originator (was Sender) and Reply-To
  # $self->{comment} should be set if the comment address is to be used.
  my $email_address=$self->{comment} ? 
      $self->{TicketObject}->Queue->CommentAddress :
      $self->{TicketObject}->Queue->CorrespondAddress
	  or warn "Can't find email address for queue?";


  unless ($self->{'Header'}->get('From')) {
      my $friendly_name=$self->{TransactionObject}->Creator->RealName;
      $self->{'Header'}->add('From', "$friendly_name <$email_address>");
      $self->{'Header'}->add('Reply-To', "$email_address");
  }
  

  $self->{'Header'}->add('RT-Originator', $self->{TransactionObject}->Creator->EmailAddress);

  #. ISO-8859-1 just
  # isn't sufficient for international usage (it's even not enough for
  # European usage ... there are people using ISO-8859-2 and KOI-8 and
  # stuff like that).
  # By default, the Template's Content-Type is used. 

  unless ($self->{'Header'}->get('Content-Type')) {
      $self->{'Header'}->add('Content-Type', 'text/plain; charset=ISO-8859-1');
  }

  unless ($self->{'Header'}->get('RT-Action')) {
      $self->{'Header'}->add('RT-Action', $self->Describe);
  }

  unless ($self->{'Header'}->get('RT-Scrip')) {
      $self->{'Header'}->add('RT-Scrip', $self->{'ScripObject'}->Description);
  }

  $self->{'Header'}->add('RT-Ticket-ID', $self->{'TicketObject'}->id());
  $self->{'Header'}->add('RT-Loop-Prevention', $RT::rtname);

  # Perform variable substitution on the template body
  $self->{'Body'}=$self->{TemplateObject}->Parse($self);
  $self->{'Body'} .= 
      "\n-------------------------------------------- Managed by Request Tracker\n\n";
 

  
  $self->{'Header'}->add
    ('X-Managed-By',"Request Tracker $RT::VERSION (http://www.fsck.com/projects/rt)");


  $self->{'Header'}->add
    ('References', "<rt-ticket-".$self->{'TicketObject'}->id()."\@".$RT::rtname.">");

  #TODO We should always add In-Reply-To and References headers for previous messages
  # related to this ticket.
  


}
# }}}


# {{{ sub SetReceipients 
sub SetRecipients {
}
# }}}


# {{{ sub IsApplicable 
sub IsApplicable  {
  my $self = shift;
  # More work needs to be done here to avoid duplicates beeing sent.
  return(1);
}
# }}}

1;



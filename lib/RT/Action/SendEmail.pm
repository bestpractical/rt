# $Header$

package RT::Action::SendEmail;

require RT::Action;
require Mail::Internet;
require RT::Template;

@ISA = qw(RT::Action);

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = { @_ };
  bless ($self, $class);
  $self->_Init();
  return $self;
}

sub _Init {
  my $self = shift;
  $self->{'TemplateObject'}=RT::Template->new;
  $self->{'TemplateObject'}->Load($self->{Template});
  $self->{'Header'} = Mail::Header->new;
  $self->{'Header'}->fold(78);
}

sub Commit {
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


sub Prepare {
  my $self = shift;

  # Header
  
  # To, bcc and cc
  if (my $a=$self->{Argument}) {
      my $receipient;
      if ($a eq '$Requestor') {
	  # TODO
	  # I guess this is wrong - I guess we should fetch the
	  # Requestor(s) from the Watcher table.
	  $receipient=$self->{TicketObject}->Creator()->EmailAddress();
      } else {
	  warn "stub - no support for argument/receipient $a yet";
      } 
      $self->{Header}->add('To', $receipient);
  } else {
      warn "stub";
      # Find all watchers, and add
  }

  # Subject
  unless ($self->{'Header'}->get(Subject)) {
      my $m=$self->{TransactionObject}->Message;
      my $subject=$m->head->get('subject')
	  if $m;
      $subject=$self->{TicketObject}->Subject()
	  unless $subject;

      $self->{'Header'}->add('subject', 
			     "[$RT::rtname #$$self{Ticket}] $subject");

  }

  # From, Sender and Reply-To
  # $self->{comment} should be set if the comment address is to be used.
  unless ($self->{'Header'}->get('From')) {
      my $friendly_name=$self->{TransactionObject}->Creator->RealName;
      my $email_address=$self->{comment} ? 
	  $self->{TicketObject}->Queue->CommentAddress :
          $self->{TicketObject}->Queue->CorrespondAddress
	      or warn "Can't find email address for queue?";
      $self->{'Header'}->add('From', "$friendly_name <$email_address>");
      $self->{'Header'}->add('Reply-To', "$email_address");
      $self->{'Header'}->add('Sender', $self->{TransactionObject}->Creator->EmailAddress);
      # Is this one necessary?
#      $self->{'Header'}->add('X-Sender', $self->{TransactionObject}->Creator->EmailAddress);
  }

  # This should perhaps be in the templates table. ISO-8859-1 just
  # isn't sufficient.

  unless ($self->{'Header'}->get('Content-Type')) {
      $self->{'Header'}->add('Content-Type', 'text/plain; charset=ISO-8859-1');
  }

  $self->{'Header'}->add('X-Request-ID', $self->{'TicketObject'}->id());
  $self->{'Header'}->add('X-RT-Loop-Prevention', $RT::rtname);

  # Perform variable substitution on the template
  $self->{'Body'}=$self->{TemplateObject}->Parse($self);
  $self->{'Body'} .= 
      "\n-------------------------------------------- Managed by Request Tracker\n\n";
 


  $self->{'Header'}->add
      ('X-Managed-By',"Request Tracker $RT::VERSION (http://www.fsck.com/projects/rt)");

}

sub IsApplicable {
  my $self = shift;
  return(1);
}

1;



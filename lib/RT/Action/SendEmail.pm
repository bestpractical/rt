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
}

sub Commit {
  my $self = shift;
  #send the email

  # This one is stupid.  There are really stability concerns with
  # smtpsend.  We really should call $self->{'Message'}->send instead
  # - unfortunately that sub is not implemented, and probably never
  # will be.  I will probably mash it together myself some day.
  # TobiX

  $self->{'Message'}=Mail::Internet->new(Header=>$self->{'Header'}, Body=>$self->{'Body'});
  $self->{'Message'}->smtpsend || die "could not send email";

}

sub Prepare {
  my $self = shift;

  if (my $a=$self->{Argument} and !$self->{Header}->get('To')) {
      my $receipient=eval "\$self->{TicketObject}->{$a}";
      $self->{Header}->add('To', $receipient)
	  if $receipient;
  }

  #perform variable substitution on the template
  
}

sub IsApplicable {
  my $self = shift;
  return(1);
}

1;

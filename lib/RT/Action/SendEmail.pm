# $Header$

package RT::Action::SendEmail;

require RT::Action;
require Mail::Internet;

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
  $self->{'Message'} = Mail::Internet->new; 
}

sub Commit {
  my $self = shift;
  #send the email

  # This one is stupid.  There are really stability concerns with
  # smtpsend.  We really should call $self->{'Message'}->send instead
  # - unfortunately that sub is not implemented, and probably never
  # will be.  I will probably mash it together myself some day.

  $self->{'Message'}->smtpsend || die "could not send email";

}

sub Prepare {
  my $self = shift;
  
  #perform variable substitution on the template
}

sub IsApplicable {
  my $self = shift;
  return(1);
}

1;

# $Header$

package RT::Action::SendEmail;

require RT::Action;
require Mail::Internet;

@ISA = qw(RT::Action);

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $self->_Init(@_);
  return $self;
}

sub _Init {
  my $self = shift;
  $self->{'Message'} = Mail::Internet->new; 
}

sub Commit {
  my $self = shift;
  #send the email

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

# $Header$

package RT::Action::SendEmail;
@ISA qw(RT::Action);


sub _Init {
  $self->{'Message'} = new Mail::Internet; 

}

sub Commit {
  my $self = shift;
  #send the email

}

sub Prepare {
  my $self = shift;
  #perform variable substitution on the template
}

sub Applicable {
  my $self = shift;
  return(1);
}

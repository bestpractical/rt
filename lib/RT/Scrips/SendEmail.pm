# $Header$

package RT::Scrips::SendEmail;
@ISA qw(RT::Scrips::Base);


sub Commit {
  my $self = shift;
  #send the email

}

sub Prepare {
  my $self = shift;
  #perform variable substitution on the template
}

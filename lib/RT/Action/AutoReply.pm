# $Header$

package RT::Action::AutoReply;

require RT::Action::SendEmail;
@ISA = qw(RT::Action::SendEmail);

sub Describe {
  return ("Sends an autoresponse to the requestor and all interested parties.");
}


sub Commit {
  my $self = shift;
  print "AutoReply Commiting\n";
  return($self->SUPER::Commit());
}

sub Prepare {
  my $self = shift;
  #Set the To and Cc
  #Set the subject
  #Set the body 
  print "Preparing\n";
}

1;






# $Header$

package RT::Action::AutoReply;

require RT::Action::SendEmail;
@ISA = qw(RT::Action::SendEmail);

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $self->_Init(@_);
  return $self;
}

sub Describe {
  return ("Sends an autoresponse to the requestor and all interested parties.");
}


sub Commit {
  my $self = shift;
  print "Commiting\n";
  return($self->SUPER::Commit());
}

sub Prepare {
  my $self = shift;
  #Set the To and Cc
  #Set the subject
  #Set the body 
  print "Preparing\n";
}

sub IsApplicable {
  my $self = shift;
  return ($self->SUPER::IsApplicable());
}

1;

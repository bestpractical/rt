# $Header$

package RT::Action::NotifyWatchers;

require RT::Action::SendEmail;
@ISA = qw(RT::Action::SendEmail);

# {{{ sub Describe 
sub Describe  {
  return ("Sends mail to all applicable watchers");
}
# }}}

# {{{ sub Commit 
sub Commit  {
  my $self = shift;
  print "AutoReply Commiting\n";
  return($self->SUPER::Commit());
}
# }}}

# {{{ sub Prepare 
sub Prepare  {
  my $self = shift;

  print "Preparing\n";
  
  my $id=$self->{TicketObject}->id || die;
  unless ($template->Subject
  my $subject=$self->{TicketObject}->Subject || "(no subject)";

  my $email=$self->{TicketObject}->Queue->CorrespondAddress;
  
  $self->{'Header'}->add('From', "Request Tracker <$email>");

  $self->{'Header'}->add('Precedence', 'bulk');

  return $self->SUPER::Prepare();
}
# }}}

# {{{ sub Recipients

# This subroutine returns a scalar which contains everyone who
# should get a copy of this notification

sub Recipients {
  my $self = shift;
  #TODO Stubbed
}

# }}}
# {{{ sub To

# This routine returns the notification's Visible To header
# Note that the actual envelope recipients should be specified
# in the Recipients subroutine

sub To {
  my $self = shift;
  #TODO stubbed
}

#}}}

# {{{ sub Cc

# This routine returns the notification's Visible Cc header
# Note that the actual envelope recipients should be specified
# in the Recipients subroutine

sub Cc {
  my $self = shift;
  #TODO stubbed
}

# }}}



1;






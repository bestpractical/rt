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
  my $subject=$self->{TicketObject}->Subject || "(no subject)";

  my $email=$self->{TicketObject}->Queue->CorrespondAddress;
  
  $self->{'Header'}->add('From', "Request Tracker <$email>");

  $self->{'Header'}->add('Subject', 
			 "[$RT::rtname \#$id] Autoreply: $subject");

  $self->{'Header'}->add('Precedence', 'bulk');

  return $self->SUPER::Prepare();
}
# }}}

1;






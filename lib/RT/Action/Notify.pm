 fo# $Header$

package RT::Action::Notify;

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
  
  return $self->SUPER::Prepare();
}
# }}}

# {{{ sub SetEnvelopeTo

# This subroutine returns a scalar which contains everyone who
# should get a copy of this notification
# Options are Admin, Owner, Requestors (which includes Ccs)
# RequestorsOnly, All and any other string, which will be
# interpreted as a literal email address
sub SetEnvelopeTo {
  my $self = shift;
  
 
  if ($self->Argument eq 'Admin') {
    $self->{'EnvelopeTo'} = $self->Ticket->AdminCcAsString();
    
  }
  elsif ($self->Argument eq 'Owner') {
    $self->{'EnvelopeTo'} = $self->Ticket->OwnerAsString();
  }

  elsif ($self->Argument eq 'Requestors') {
    $self->{'EnvelopeTo'} = $self->Ticket->RequestorsCcAsString() . ", " .
      $self->Ticket->CcAsString;
  }
  elsif ($self->Argument eq 'RequestorsOnly') {
    $self->{'EnvelopeTo'} = $self->Ticket->RequestorsAsString();
  }
  
  elsif ($self->Argument eq 'All') {
    $self->{'EnvelopeTo'} = $self->Ticket->WatchersAsString(). ", " .
      $self->Ticket->OwnerAsString();
  }
  
  else {
    $self->{'EnvelopeTo'} = $self->Argument;
   }

  
}

# }}}
# {{{ sub SetTo

# This routine returns the notification's Visible To header
# Note that the actual envelope recipients should be specified
# in the Recipients subroutine

sub SetTo {
  my $self = shift;
  
}

#}}}

# {{{ sub SetCc

# This routine returns the notification's Visible Cc header
# Note that the actual envelope recipients should be specified
# in the Recipients subroutine

sub SetCc {
  my $self = shift;
  #TODO stubbed
}

# }}}



1;






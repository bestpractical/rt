#$Tag$

package RT::Notification;

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  return $self;
}



sub Send {
  my $self = shift;
  return ("RT::Notification->Send not yet implemented");
}

sub Create {
  my $self = shift;
  my @args = ( from => "$RT::MailAlias",
	       reply-to => "$RT::MailAlias",
	       to => undef,
	       cc => undef,
	       bcc => undef,
	       subject => "No Subject",
	       content => undef,
	       @_
	       );
  
  
  $self->{'from'} = $args->{'from'};
  $self->{'reply-to'} = $args->{'reply-to'};
  $self->{'to'} = $args->{'to'};
  $self->{'subject'} = $args->{'subject'};
  $self->{'cc'} = $args->{'cc'};
  $self->{'bcc'} = $args->{'bcc'};
  $self->{'content'} = $args->{'content'};

}

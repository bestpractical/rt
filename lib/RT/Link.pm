# $Header$
# (c) 1996-1999 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL
#

package RT::Link;
use RT::Record;
@ISA= qw(RT::Record);

# {{{ sub new 
sub new  {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $self->{'table'} = "Links";
  $self->_Init(@_);

  return($self);
}
# }}}

# {{{ sub Create 
sub Create  {
  my $self = shift;
  my %args = (
	      Base => undef,
	      Target => undef,
	      Type => undef,
	      @_ # get the real argumentlist
	     );
  
  

  my $id = $self->SUPER::Create(%args);
  $self->Load($id);
  
  #TODO: this is horrificially wasteful. we shouldn't commit 
  # to the db and then instantly turn around and load the same data
  
  return ($id,"Link created");
}
# }}}
 
# {{{ sub Load 
sub Load  {
  my $self = shift;
  my $identifier = shift;
  
  if ($identifier !~ /\D/) {
    $self->SUPER::LoadById($identifier);
  }
  else {
	return (0, "That's not a numerical id");
  }
}
# }}}


# {{{ sub TargetObj 
sub TargetObj {
  my $self = shift;
   return $self->_TicketObj('base',$self->Target);
}
# }}}

# {{{ sub BaseObj
sub BaseObj {
  my $self = shift;
  return $self->_TicketObj('target',$self->Base);
}
# }}}


# {{{ sub _TicketObj
sub _TicketObj {
  my $self = shift;
  my $name = shift;
  my $ref = shift;
  my $tag="$name\_obj";
  
  unless (exists $self->{$tag}) {
    if ($self->_IsLocal($ref)) {
      $self->{$tag}=RT::Ticket->new;
      $self->{$tag}->Load($ref);
    }
    else {
      $self->{$tag} = undef;
    }
  }
  return $self->{$tag};
}
# }}}


# {{{ sub _Accessible 
sub _Accessible  {
  my $self = shift;
  my %Cols = (
	      Base => 'read/write',
	      Target => 'read/write',
	      Type => 'read/write',
	     );
  return($self->SUPER::_Accessible(@_, %Cols));
}
# }}}


# {{{ sub DisplayPermitted
sub DisplayPermitted {
    # TODO: stub!
    return 1;
}

# }}}


# Static methods:

# {{{ sub BaseIsLocal
sub BaseIsLocal {
  my $self = shift;
  return $self->_IsLocal($self->Base);
}

# }}}

# {{{ sub TargetIsLocal
sub TargetIsLocal {
  my $self = shift;
  return $self->_IsLocal($self->Target);
}

# }}}

# {{{ sub _IsLocal

# checks whether an URI is local or not
sub _IsLocal {
  my $self = shift;
  my $URI=shift;
  # TODO: More thorough check
  $URI =~ /^(\d+)$/;
  return $1;
}
# }}}


# {{{ sub BaseAsHREF 
sub BaseAsHREF {
  my $self = shift;
  return $self->AsHREF($self->Base);
}
# }}}

# {{{ sub TargetAsHREF 
sub TargetAsHREF {
  my $self = shift;
  return $self->AsHREF($self->Target);
}
# }}}

# {{{ sub AsHREF
# Converts Link URIs to HTTP URLs
sub AsHREF {
  my $self=shift;
  my $URI=shift;
  if ($self->_IsLocal($URI)) {
    my $url=$RT::WebURL . "Ticket/Display.html?id=$URI";
    return $url;
  } else {
    my ($protocol) = $URI =~ m|(.*?)://|;
    return $RT::URI2HTTP{$protocol}->($URI);
    }
}

# }}}

1;
 

# $Header$
# (c) 1996-1999 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL
=head1 NAME

  RT::Link - an RT Link object

=head1 SYNOPSIS

  use RT::Link;

=head1 DESCRIPTION


=head1 METHODS

=cut

package RT::Link;
use RT::Record;
use Carp;
@ISA= qw(RT::Record);

# {{{ sub _Init
sub _Init  {
  my $self  = shift;
  $self->{'table'} = "Links";
  return ($self->SUPER::_Init(@_));
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
 

  my $BaseURI = $self->CanonicalizeURI($args{'Base'});
  my $TargetURI = $self->CanonicalizeURI($args{'Target'});
 
    
  unless (defined $BaseURI) {
     $RT::Logger->warning ("$self couldn't resolve base:'".$args{'Base'}."' into a URI\n");
       return (undef);
   }
  unless (defined $TargetURI) {
     $RT::Logger->warning ("$self couldn't resolve target:'".$args{'Target'}."' into a URI\n");
     return(undef);
   }
    
 my $LocalBase = $self->_IsLocal($BaseURI);
 my $LocalTarget = $self->_IsLocal($TargetURI);
 my $id = $self->SUPER::Create(Base => "$BaseURI",
                               Target => "$TargetURI",
                               LocalBase => $LocalBase, 
                               LocalTarget => $LocalTarget,
                               Type => $args{'Type'});
  
  #TODO +++ deal with a failed create 
  $self->Load($id);
  
  #TODO: this is horrificially wasteful. we shouldn't commit 
  # to the db and then instantly turn around and load the same data
  
  return ($id);
}
# }}}
 
# {{{ sub Load 

=head2 Load

  Load an RT::Link object from the database.  Takes one parameter or three.
  One parameter is the id of an entry in the links table.  Three parameters are a tuple of (base, linktype, target);


=cut

sub Load  {
  my $self = shift;
  my $identifier = shift;
  my $linktype = shift if (@_);
  my $target = shift if (@_);
  
  if ($target) {
      my $BaseURI = $self->CanonicalizeURI($identifier);
      my $TargetURI = $self->CanonicalizeURI($target);
      $self->LoadByCols( Base => $BaseURI,
			 Type => $linktype,
			 Target => $TargetURI
		       ) || return (0, "Couldn't load link");
  }
  
  elsif ($identifier =~ /^\d+$/) {
      $self->LoadById($identifier) ||
	return (0, "Couldn't load link");
  }
  else {
	return (0, "That's not a numerical id");
  }
}
# }}}

# {{{ sub TargetObj 

=head2 TargetObj

=cut

sub TargetObj {
  my $self = shift;
   return $self->_TicketObj('base',$self->Target);
}
# }}}

# {{{ sub BaseObj

=head2 BaseObj

=cut

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

  $self->{$tag}=RT::Ticket->new($self->CurrentUser);

  #If we can get an actual ticket, load it up.
  if ($self->_IsLocal($ref)) {
      $self->{$tag}->Load($ref);
    }
  }
  return $self->{$tag};
}
# }}}


# {{{ sub _Accessible 
sub _Accessible  {
  my $self = shift;
  my %Cols = (
          LocalBase => 'read',
          LocalTarget => 'read',
	      Base => 'read',
	      Target => 'read',
	      Type => 'read',
	     );
  return($self->SUPER::_Accessible(@_, %Cols));
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
=head2 _IsLocal 

when handed a URI returns the local ticket id if it's local. otherwise returns undef.

=cut

# checks whether an URI is local or not
sub _IsLocal {
  my $self = shift;
  my $URI=shift;
  unless ($URI) {
      $RT::Logger->warning ("$self _IsLocal called without a URI\n");
      return (undef);
  }
  # TODO: More thorough check
  if ($URI =~ /^$RT::TicketBaseURI(\d+)$/) {
    return($1);
   }
   else {
    return (undef);
   }
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

# {{{ sub AsHREF - Converts Link URIs to HTTP URLs
sub AsHREF {
    my $self=shift;
    my $URI=shift;
    if ($self->_IsLocal($URI)) {
	my $url=$RT::WebURL . "Ticket/Display.html?id=$URI";
	return $url;
    } else {
	my ($protocol) = $URI =~ m|(.*?)://|;
	unless (exists $RT::URI2HTTP{$protocol}) {
	    warn "Linking for protocol $protocol not defined in the config file!";
	    return "";
	}
	return $RT::URI2HTTP{$protocol}->($URI);
    }
}

# }}}

# {{{ sub GetContent - gets the content from a link
sub GetContent {
    my ($self, $URI)=@_;
    if ($self->_IsLocal($URI)) {
	die "stub";
    } else {
	# Find protocol
	if ($URI =~ m|^(.*?)://|) {
	    if (exists $RT::ContentFromURI{$1}) {
		return $RT::ContentFromURI{$1}->($URI);
	    } else {
		warn "No sub exists for fetching the content from a $1 in $URI";
	    }
	} else {
	    warn "No protocol specified in $URI";
	}
    }
}
# }}}

# {{{ sub CanonicalizeURI

=head2 CanonicalizeURI

Takes a single argument: some form of ticket identifier. 
Returns its canonicalized URI.

Bug: ticket aliases can't have :// in them. URIs must have :// in them.

=cut

sub CanonicalizeURI {
 my $self = shift;
 my $id = shift;


  #If it's a local URI, load the ticket object and return its URI
  if ($id =~ /^$RT::TicketBaseURI/)  {
    my $ticket = new RT::Ticket($self->CurrentUser);
    $ticket->LoadByURI($id);
    #If we couldn't find a ticket, return undef.
    return undef unless (defined $ticket->Id);
    $RT::Logger->debug("$self -> CanonicalizeURI was passed $id and returned ".$ticket->URI ." (uri)\n");
    return ($ticket->URI);
  }
  #If it's a remote URI, we're going to punt for now
  elsif ($id =~ '://' ) {
    return ($id);
   }
  
  #If the base is an integer, load it as a ticket 
 elsif ( $id =~ /^\d+$/ ) {
   
    $RT::Logger->debug("$self -> CanonicalizeURI was passed $id. It's a ticket id.\n");
    my $ticket = new RT::Ticket($self->CurrentUser);
    $ticket->Load($id);
    #If we couldn't find a ticket, return undef.
    return undef unless (defined $ticket->Id);
    $RT::Logger->debug("$self returned ".$ticket->URI ." (id #)\n");
    return ($ticket->URI);
  }

  #It's not a URI. It's not a numerical ticket ID. It must be an alias
  else { 
    my $ticket = new RT::Ticket($self->CurrentUser);
    $ticket->LoadByAlias($id);
    #If we couldn't find a ticket, return undef.
    return undef unless (defined $ticket->Id);
    $RT::Logger->debug("$self -> CanonicalizeURI was passed $id and returned ".$ticket->URI ." (uri)\n");
    return ($ticket->URI);
    return($ticket->URI);
  }

 
}

# }}}
1;
 

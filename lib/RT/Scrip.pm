# Copyright 1999-2000 Jesse Vincent <jesse@fsck.com>
# Released under the terms of the GNU Public License
# $Header$

package RT::Scrip;
use RT::Record;
@ISA= qw(RT::Record);

# {{{ sub new 
sub new  {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $self->{'table'} = "Scrips";
  $self->_Init(@_);
  return ($self);
}
# }}}

# {{{ sub _Accessible 
sub _Accessible  {
  my $self = shift;
  my %Cols = ( Name  => 'read/write',
	       Description => 'read/write',
	       Type	 => 'read/write',
	       Action  => 'read/write',
	       DefaultTemplate => 'read/write',
	       Argument  => 'read/write'
	     );
  return($self->SUPER::_Accessible(@_, %Cols));
}
# }}}

# {{{ sub Create 
sub Create  {
  my $self = shift;
  die "RT::Scrip->create stubbed\n";
  my $id = $self->SUPER::Create(Name => @_);
  $self->LoadById($id);
  
}
# }}}

# {{{ sub delete 
sub Delete  {
  my $self = shift;
 # this function needs to move all requests into some other queue!
  my ($query_string,$update_clause);
  
  die ("Scrip->Delete not implemented yet");
    
      

}
# }}}



# {{{ sub Load 
sub Load  {
  my $self = shift;
  my $identifier = shift;

  my $template = shift;

  if (!$identifier) {
    return (undef);
  }	    

  if ($identifier !~ /\D/) {
    $self->SUPER::LoadById($identifier);
  }
  else {
    die "This code should never be reached ;)";  

  }

  # Set the template Id to the passed in template
  # or fall back to the default for this scrip
  if (defined $template) {
    $self->{'Template'} = $template;
  }
  else {
    $self->{'Template'} = $self->DefaultTemplate();
  }
 
}
# }}}

# {{{ sub LoadAction 
sub LoadAction  {
  my $self = shift;
  my %args = ( TransactionObj => undef,
	       TicketObj => undef,
	       @_ );

  #TODO: Put this in an eval  
  my $type = "RT::Action::". $self->Action;
 
  $RT::Logger->debug("now requiring $type\n"); 
  eval "require $type" || die "Require of $type failed.\nThis most likely means that a custom Action installed by your RT administrator broke. $@\n";
  $self->{'Action'}  = $type->new ( 'ScripObj' => $self, 
				    'TicketObj' => $args{'TicketObj'},
					  'TransactionObj' => $args{'TransactionObj'},
					  'TemplateObj' => $self->TemplateObj,
					  'Argument' => $self->Argument,
					  'Type' => $self->Type,
				  );
}
# }}}

# {{{ sub TemplateObj
sub TemplateObj {
    my $self = shift;
    return undef unless $self->{Template};
    if (!$self->{'TemplateObj'})  {
	require RT::Template;
	$self->{'TemplateObj'} = RT::Template->new($self->CurrentUser);
	$self->{'TemplateObj'}->LoadById($self->{'Template'});
	
    }
  
    return ($self->{'TemplateObj'});
}
# }}}

# The following methods call the action object

# {{{ sub Prepare 
sub Prepare  {
  my $self = shift;
  return ($self->{'Action'}->Prepare());
  
}
# }}}

# {{{ sub Commit 
sub Commit  {
  my $self = shift;
   return($self->{'Action'}->Commit());

  
}
# }}}

# {{{ sub Describe 
sub Describe  {
  my $self = shift;
  return ($self->{'Action'}->Describe());
  
}
# }}}

# {{{ sub IsApplicable 
sub IsApplicable  {
  my $self = shift;
  return ($self->{'Action'}->IsApplicable());
  
}
# }}}

# {{{ sub DESTROY
sub DESTROY {
    my $self=shift;
    $self->{'Action'} = undef;
    $self->{'TemplateObj'} = undef;
}
# }}}

# ACCESS CONTROL


1;



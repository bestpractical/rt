#$Header$

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
sub delete  {
  my $self = shift;
 # this function needs to move all requests into some other queue!
  my ($query_string,$update_clause);
  
  die ("Scrip->Delete not implemented yet");
    
      

}
# }}}

# {{{ sub create 
sub create  {
  my $self = shift;
  return($self->Create(@_));
}
# }}}


# {{{ sub Load 
sub Load  {
  my $self = shift;
  my $identifier = shift;

  my $template = shift if (@_);

  if (!$identifier) {
    return (undef);
  }	    

  if ($identifier !~ /\D/) {
    $self->SUPER::LoadById($identifier);
  }
  else {
    die "This code is never reached ;)";  

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
  
  eval "require $type" || die "Require of $type failed.\nThis most likely means that a custom Action installed by your RT administrator broke. $@\n";
  $self->{'ScriptObject'}  = $type->new ( 'TicketObj' => $args{'TicketObj'},
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
  if (!$self->{'TemplateObj'})  {
    require RT::Scrip;
    $self->{'TemplateObj'} = RT::Template->new($self->CurrentUser);
    $self->{'TemplateObj'}->load($self->Template());
  
  }
  
  return ($self->{'TemplateObj'});
}
# }}}


#
# The following methods call the action object
#

# {{{ sub Prepare 
sub Prepare  {
  my $self = shift;
  return ($self->{'ScriptObject'}->Prepare());
  
}
# }}}

# {{{ sub Commit 
sub Commit  {
  my $self = shift;
  return ($self->{'ScriptObject'}->Commit());
  
}
# }}}
# {{{ sub Describe 
sub Describe  {
  my $self = shift;
  return ($self->{'ScriptObject'}->Describe());
  
}
# }}}
# {{{ sub IsApplicable 
sub IsApplicable  {
  my $self = shift;
  return ($self->{'ScriptObject'}->IsApplicable());
  
}
# }}}
#
# ACCESS CONTROL
# 

# {{{ sub DisplayPermitted 
sub DisplayPermitted  {
  my $self = shift;

  my $actor = shift;
  if (!$actor) {
   my $actor = $self->CurrentUser;
 }
#  if ($self->Queue->DisplayPermitted($actor)) {
 if (1){   
    return(1);
  }
  else {
    #if it's not permitted,
    return(0);
  }
}
# }}}
# {{{ sub ModifyPermitted 
sub ModifyPermitted  {
  my $self = shift;
  my $actor = shift;
  if (!$actor) {
    my $actor = $self->CurrentUser;
  }
#  if ($self->Queue->ModifyPermitted($actor)) {
 if (1) {   
    return(1);
  }
  else {
    #if it's not permitted,
    return(0);
  }
}
# }}}

# {{{ sub AdminPermitted 
sub AdminPermitted  {
  my $self = shift;
  my $actor = shift;
  if (!$actor) {
    my $actor = $self->CurrentUser;
  }


#  if ($self->ACL->AdminPermitted($actor)) {
 if (1) {   
    return(1);
  }
  else {
    #if it's not permitted,
    return(0);
  }
}
# }}}


1;



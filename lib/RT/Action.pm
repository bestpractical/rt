# $Header$

package RT::Action;



# {{{ sub new 
sub new  {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $self->_Init(@_);
  return $self;
}
# }}}

# {{{ sub _Init 
sub _Init  {
  my $self = shift;
  my %args = ( TransactionObj => undef,
	       TicketObj => undef,
	       TemplateObj => undef,
	       Argument => undef,
	       Type => undef,
	       @_ );
  
  
  $self->{'Argument'} = $args{'Argument'};
  $self->{'TicketObj'} = $args{'TicketObj'};
  $self->{'TransactionObj'} = $args{'TransactionObj'};
  $self->{'TemplateObj'} = $args{'TemplateObj'};
  $self->{'Type'} = $args{'Type'};
}
# }}}




#Access Scripwide data
# {{{ sub Argument 
sub Argument  {
  my $self = shift;
  return($self->{'Argument'});
}
# }}}

# {{{ sub Ticket 
sub TicketObj  {
  my $self = shift;
  return($self->{'TicketObj'});
}
# }}}
# {{{ sub Transaction 
sub TransactionObj  {
  my $self = shift;
  return($self->{'TransactionObj'});
}
# }}}
# {{{ sub Template 
sub TemplateObj  {
  my $self = shift;
  return($self->{'TemplateObj'});
}
# }}}

# {{{ sub Type 
sub Type  {
  my $self = shift;
  return($self->{'Type'});
}
# }}}



#
# Scrip methods
#


#Do what we need to do and send it out.
# {{{ sub Commit 
sub Commit  {
  my $self = shift;
  return(0,"Commit Stubbed");
}
# }}}


#What does this type of Action does
# {{{ sub Describe 
sub Describe  {
  my $self = shift;
  return ("No description for " . ref $self);
}
# }}}

#Parse the templates, get things ready to go.
# {{{ sub Prepare 
sub Prepare  {
  my $self = shift;
  return (0,"Prepare Stubbed");
}
# }}}


#If this rule applies to this transaction, return true.
# {{{ sub IsApplicable 
sub IsApplicable  {
  my $self = shift;
  return(undef);
}
# }}}


1;

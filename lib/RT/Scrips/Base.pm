# $Header$

package RT::Scrips::Base;



sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $self->_Init(@_);
  return $self;
}

sub _Init {
  my $self = shift;
  my %args = ( Transaction => undef,
	       Ticket => undef,
	       Template => undef,
	       Argument => undef,
	       Type => undef,
	       @_ );
  
  
  $self->{'Argument'} = $args{'Argument'};
  $self->{'Ticket'} = $args{'Ticket'};
  $self->{'Transaction'} = $args{'Transaction'};
  $self->{'Template'} = $args{'Template'};
  $self->{'Type'} = $args{'Type'};
}




#Access Scripwide data
sub Argument {
  my $self = shift;
  return($self->{'Argument'});
}

sub Ticket {
  my $self = shift;
  return($self->{'Ticket'});
}
sub Transaction {
  my $self = shift;
  return($self->{'Transaction'});
}
sub Template {
  my $self = shift;
  return($self->{'Template'});
}

sub Type {
  my $self = shift;
  return($self->{'Type'});
}



#
# Scrip methods
#


#Do what we need to do and send it out.
sub Commit {
  my $self = shift;
  return(0,"Commit Stubbed");
}


#What does this type of Scrip do
sub Describe {
  my $self = shift;
  return (1, "This is a baseclass for a Scrip.");
}

#Parse the templates, get things ready to go.
sub Prepare {
  my $self = shift;
  return (0,"Prepare Stubbed");
}


#If this rule applies to this transaction, return true.
sub IsApplicable {
  my $self = shift;
  return(undef);
}

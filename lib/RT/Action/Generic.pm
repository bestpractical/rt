# $Header: /raid/cvsroot/rt/lib/RT/Action/Generic.pm,v 1.2 2001/11/06 23:04:17 jesse Exp $
# (c) 1996-2000 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL

=head1 NAME

  RT::Action::Generic - a generic baseclass for RT Actions

=head1 SYNOPSIS

  use RT::Action::Generic;

=head1 DESCRIPTION

=head1 METHODS

=begin testing

ok (require RT::Action::Generic);

=end testing

=cut

package RT::Action::Generic;

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
	       ScripObj => undef,
	       TemplateObj => undef,
	       Argument => undef,
	       Type => undef,
	       @_ );
  
  
  $self->{'Argument'} = $args{'Argument'};
  $self->{'ScripObj'} = $args{'ScripObj'};
  $self->{'TicketObj'} = $args{'TicketObj'};
  $self->{'TransactionObj'} = $args{'TransactionObj'};
  $self->{'TemplateObj'} = $args{'TemplateObj'};
  $self->{'Type'} = $args{'Type'};
}
# }}}

# Access Scripwide data

# {{{ sub Argument 
sub Argument  {
  my $self = shift;
  return($self->{'Argument'});
}
# }}}

# {{{ sub TicketObj
sub TicketObj  {
  my $self = shift;
  return($self->{'TicketObj'});
}
# }}}

# {{{ sub TransactionObj
sub TransactionObj  {
  my $self = shift;
  return($self->{'TransactionObj'});
}
# }}}

# {{{ sub TemplateObj
sub TemplateObj  {
  my $self = shift;
  return($self->{'TemplateObj'});
}
# }}}

# {{{ sub ScripObj
sub ScripObj  {
  my $self = shift;
  return($self->{'ScripObj'});
}
# }}}

# {{{ sub Type
sub Type  {
  my $self = shift;
  return($self->{'Type'});
}
# }}}


# Scrip methods

#Do what we need to do and send it out.

# {{{ sub Commit 
sub Commit  {
  my $self = shift;
  return(0, $self->loc("Commit Stubbed"));
}
# }}}


#What does this type of Action does

# {{{ sub Describe 
sub Describe  {
  my $self = shift;
  return $self->loc("No description for [_1]", ref $self);
}
# }}}


#Parse the templates, get things ready to go.

# {{{ sub Prepare 
sub Prepare  {
  my $self = shift;
  return (0, $self->loc("Prepare Stubbed"));
}
# }}}


#If this rule applies to this transaction, return true.

# {{{ sub IsApplicable 
sub IsApplicable  {
  my $self = shift;
  return(undef);
}
# }}}

# {{{ sub DESTROY
sub DESTROY {
    my $self = shift;

    # We need to clean up all the references that might maybe get
    # oddly circular
    $self->{'TemplateObj'} =undef
    $self->{'TicketObj'} = undef;
    $self->{'TransactionObj'} = undef;
    $self->{'ScripObj'} = undef;


     
}

# }}}
1;

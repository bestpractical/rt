# $Header: /raid/cvsroot/rt/lib/RT/Condition/Generic.pm,v 1.3 2002/01/11 00:02:34 jesse Exp $
# (c) 1996-2000 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL

=head1 NAME

  RT::Condition::Generic - ;

=head1 SYNOPSIS

    use RT::Condition::Generic;
    my $foo = new RT::Condition::IsApplicable( 
		TransactionObj => $tr, 
		TicketObj => $ti, 
		ScripObj => $scr, 
		Argument => $arg, 
		Type => $type);

    if ($foo->IsApplicable) {
 	   # do something
    }


=head1 DESCRIPTION


=head1 METHODS


=begin testing

ok (require RT::Condition::Generic);

=end testing


=cut

package RT::Condition::Generic;

# TODO XXX we need to make this an RT::Somethingorother object so it gets a loc method


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
	       ApplicableTransTypes => undef,
	       @_ );
  
  $self->{'Argument'} = $args{'Argument'};
  $self->{'ScripObj'} = $args{'ScripObj'};
  $self->{'TicketObj'} = $args{'TicketObj'};
  $self->{'TransactionObj'} = $args{'TransactionObj'};
  $self->{'ApplicableTransTypes'} = $args{'ApplicableTypes'};
}
# }}}

# Access Scripwide data

# {{{ sub Argument 

=head2 Argument

Return the optional argument associated with this ScripCondition

=cut

sub Argument  {
  my $self = shift;
  return($self->{'Argument'});
}
# }}}

# {{{ sub TicketObj

=head2 TicketObj

Return the ticket object we're talking about

=cut

sub TicketObj  {
  my $self = shift;
  return($self->{'TicketObj'});
}
# }}}

# {{{ sub ScripObj

=head2 ScripObj

Return the Scrip object we're talking about

=cut

sub ScripObj  {
  my $self = shift;
  return($self->{'ScripObj'});
}
# }}}
# {{{ sub TransactionObj

=head2 TransactionObj

Return the transaction object we're talking about

=cut

sub TransactionObj  {
  my $self = shift;
  return($self->{'TransactionObj'});
}
# }}}

# {{{ sub Type

=head2 Type 



=cut

sub ApplicableTransTypes  {
  my $self = shift;
  return($self->{'ApplicableTransTypes'});
}
# }}}


# Scrip methods


#What does this type of Action does

# {{{ sub Describe 
sub Describe  {
  my $self = shift;
  return ($self->loc("No description for [_1]", ref $self));
}
# }}}


#Parse the templates, get things ready to go.

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

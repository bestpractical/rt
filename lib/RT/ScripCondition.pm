# Copyright 1999-2000 Jesse Vincent <jesse@fsck.com>
# Released under the terms of the GNU Public License
# $Header$

=head1 NAME

  RT::ScripCondition - RT scrip conditional

=head1 SYNOPSIS

  use RT::ScripCondition;


=head1 DESCRIPTION


=head1 METHODS

=cut

package RT::ScripCondition;
use RT::Record;
@ISA= qw(RT::Record);



# {{{  sub _Init 
sub _Init  {
    my $self = shift; 
    $self->{'table'} = "ScripConditions";
    return ($self->SUPER::_Init(@_));
}
# }}}

# {{{ sub _Accessible 
sub _Accessible  {
    my $self = shift;
    my %Cols = ( Name  => 'read/write',
		 Description => 'read/write',
		 ApplicableTransTypes	 => 'read/write',
		 ExecModule  => 'read/write',
		 Argument  => 'read/write'
	       );
    return($self->SUPER::_Accessible(@_, %Cols));
}
# }}}

# {{{ sub Create 
=head2 Create
  
Takes a hash. Creates a new Condition entry.
 should be better documented.
=cut
sub Create  {
  my $self = shift;
  #TODO check these args and do smart things.
  my $id = $self->SUPER::Create(@_);
  $self->LoadById($id);
  #TODO proper return values 
}
# }}}

# {{{ sub delete 
sub Delete  {
    my $self = shift;
    # this function needs to move all requests into some other queue!
    my ($query_string,$update_clause);
    
    die ("Condition->Delete not implemented yet");
}
# }}}



# {{{ sub Load 
sub Load  {
    my $self = shift;
    my $identifier = shift;
    
    if (!$identifier) {
	return (undef);
    }	    
    
  if ($identifier !~ /\D/) {
      $self->SUPER::LoadById($identifier);
  }
    else {
	$self->LoadByCol('Name', $identifier);
    }
}
# }}}


# {{{ sub LoadCondition 
sub LoadCondition  {
    my $self = shift;
    my %args = ( TransactionObj => undef,
		 TicketObj => undef,
		 @_ );
    
    #TODO: Put this in an eval  
    my $type = "RT::Condition::". $self->ExecModule;
    
    $RT::Logger->debug("now requiring $type\n"); 
    eval "require $type" || die "Require of $type failed.\n$@\n";
    
    $self->{'Condition'}  = $type->new ( 'ScripConditionObj' => $self, 
				      'TicketObj' => $args{'TicketObj'},
				      'TransactionObj' => $args{'TransactionObj'},
				      'Argument' => $self->Argument,
				      'ApplicableTransTypes' => $self->ApplicableTransTypes,
				    );
}
# }}}


# The following methods call the Condition object


# {{{ sub Describe 
sub Describe  {
    my $self = shift;
    return ($self->{'Condition'}->Describe());
    
}
# }}}

# {{{ sub IsApplicable 
sub IsApplicable  {
    my $self = shift;
    return ($self->{'Condition'}->IsApplicable());
    
}
# }}}

# {{{ sub DESTROY
sub DESTROY {
    my $self=shift;
    $self->{'Condition'} = undef;
}
# }}}


1;



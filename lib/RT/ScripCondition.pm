# Copyright 1999-2000 Jesse Vincent <jesse@fsck.com>
# Released under the terms of the GNU Public License
# $Header$

=head1 NAME

  RT::ScripCondition - RT scrip conditional

=head1 SYNOPSIS

  use RT::ScripCondition;


=head1 DESCRIPTION

This module should never be called directly by client code. it's an internal module which
should only be accessed through exported APIs in other modules.


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
    my %Cols = ( Name  => 'read',
		 Description => 'read',
		 ApplicableTransTypes	 => 'read',
		 ExecModule  => 'read',
		 Argument  => 'read',
		 Creator => 'read/auto',
		 Created => 'read/auto',
		 LastUpdatedBy => 'read/auto',
		 LastUpdated => 'read/auto'
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
    return($self->SUPER::Create(@_));
}
# }}}

# {{{ sub Delete 

=head2 Delete

No API available for deleting things just yet.

=cut

sub Delete  {
    my $self = shift;
    return(0,'Unimplemented');
}
# }}}

# {{{ sub Load 

=head2 Load IDENTIFIER

Loads a condition takes a name or ScripCondition id.

=cut

sub Load  {
    my $self = shift;
    my $identifier = shift;
    
    unless (defined $identifier) {
	return (undef);
    }	    
    
    if ($identifier !~ /\D/) {
	return ($self->SUPER::LoadById($identifier));
    }
    else {
	return ($self->LoadByCol('Name', $identifier));
    }
}
# }}}

# {{{ sub LoadCondition 

=head2 LoadCondition  HASH

takes a hash which has the following elements:  TransactionObj and TicketObj.
Loads the Condition module in question.

=cut


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

# {{{ The following methods call the Condition object


# {{{ sub Describe 

=head2 Describe 

Helper method to call the condition module\'s Describe method.

=cut

sub Describe  {
    my $self = shift;
    return ($self->{'Condition'}->Describe());
    
}
# }}}

# {{{ sub IsApplicable 

=head2 IsApplicable

Helper method to call the condition module\'s IsApplicable method.

=cut

sub IsApplicable  {
    my $self = shift;
    return ($self->{'Condition'}->IsApplicable());
    
}
# }}}

# }}}

# {{{ sub DESTROY
sub DESTROY {
    my $self=shift;
    $self->{'Condition'} = undef;
}
# }}}


1;



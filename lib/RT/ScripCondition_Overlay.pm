# BEGIN LICENSE BLOCK
# 
# Copyright (c) 1996-2003 Jesse Vincent <jesse@bestpractical.com>
# 
# (Except where explictly superceded by other copyright notices)
# 
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
# 
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# Unless otherwise specified, all modifications, corrections or
# extensions to this work which alter its source code become the
# property of Best Practical Solutions, LLC when submitted for
# inclusion in the work.
# 
# 
# END LICENSE BLOCK
=head1 NAME

  RT::ScripCondition - RT scrip conditional

=head1 SYNOPSIS

  use RT::ScripCondition;


=head1 DESCRIPTION

This module should never be called directly by client code. it's an internal module which
should only be accessed through exported APIs in other modules.


=begin testing

ok (require RT::ScripCondition);

=end testing

=head1 METHODS

=cut

use strict;
no warnings qw(redefine);


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
    return(0, $self->loc('Unimplemented'));
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
    $self->ExecModule =~ /^(\w+)$/;
    my $module = $1;
    my $type = "RT::Condition::". $module;
    
    eval "require $type" || die "Require of $type failed.\n$@\n";
    
    $self->{'Condition'}  = $type->new ( 'ScripConditionObj' => $self, 
					 'TicketObj' => $args{'TicketObj'},
					 'ScripObj' => $args{'ScripObj'},
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



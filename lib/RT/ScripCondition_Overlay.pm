# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
# 
# This software is Copyright (c) 1996-2009 Best Practical Solutions, LLC
#                                          <jesse@bestpractical.com>
# 
# (Except where explicitly superseded by other copyright notices)
# 
# 
# LICENSE:
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
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
# 
# 
# CONTRIBUTION SUBMISSION POLICY:
# 
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
# 
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
# 
# END BPS TAGGED BLOCK }}}

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
                     CurrentUser => $self->CurrentUser 
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



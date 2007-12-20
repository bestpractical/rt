# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2007 Best Practical Solutions, LLC 
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
# http://www.gnu.org/copyleft/gpl.html.
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
=head1 name

  RT::Model::ScripCondition - RT scrip conditional

=head1 SYNOPSIS

  use RT::Model::ScripCondition;


=head1 DESCRIPTION

This module should never be called directly by client code. it's an internal module which
should only be accessed through exported APIs in other modules.



=head1 METHODS

=cut


package RT::Model::ScripCondition;

use strict;
no warnings qw(redefine);

use base qw/RT::Record/;

# {{{  sub _init 

sub table {'ScripConditions'}
use Jifty::DBI::Schema;
use Jifty::DBI::Record schema {
    column name                 => type is 'text';
    column Description          => type is 'text';
    column ExecModule           => type is 'text';
    column Argument             => type is 'text';
    column ApplicableTransTypes => type is 'text';
    column Creator => max_length is 11, type is 'int(11)', default is '0';
    column Created =>  type is 'datetime', default is '';
    column LastUpdatedBy => max_length is 11, type is 'int(11)', default is '0';
    column LastUpdated =>  type is 'datetime', default is '';

};

# }}}

# {{{ sub create 

=head2 Create
  
  Takes a hash. Creates a new Condition entry.
  should be better documented.

=cut

sub create  {
    my $self = shift;
    return($self->SUPER::create(@_));
}
# }}}

# {{{ sub delete 

=head2 delete

No API available for deleting things just yet.

=cut

sub delete  {
    my $self = shift;
    return(0, $self->loc('Unimplemented'));
}
# }}}

# {{{ sub load 

=head2 Load IDENTIFIER

Loads a condition takes a name or ScripCondition id.

=cut

sub load  {
    my $self = shift;
    my $identifier = shift;
    
    unless (defined $identifier) {
	return (undef);
    }	    
    
    if ($identifier !~ /\D/) {
	return ($self->SUPER::load_by_id($identifier));
    }
    else {
	return ($self->load_by_cols('name', $identifier));
    }
}
# }}}

# {{{ sub loadCondition 

=head2 LoadCondition  HASH

takes a hash which has the following elements:  TransactionObj and TicketObj.
Loads the Condition module in question.

=cut


sub loadCondition  {
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
                     CurrentUser => $self->current_user 
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


sub _value { shift->__value(@_)}
1;





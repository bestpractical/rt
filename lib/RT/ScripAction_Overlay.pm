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

  RT::ScripAction - RT Action object

=head1 SYNOPSIS

  use RT::ScripAction;


=head1 DESCRIPTION

This module should never be called directly by client code. it's an internal module which
should only be accessed through exported APIs in other modules.


=begin testing

ok (require RT::ScripAction);

=end testing

=head1 METHODS

=cut

use strict;
no warnings qw(redefine);

# {{{  sub _Init 
sub _Init  {
    my $self = shift; 
    $self->{'table'} = "ScripActions";
    return ($self->SUPER::_Init(@_));
}
# }}}

# {{{ sub _Accessible 
sub _Accessible  {
    my $self = shift;
    my %Cols = ( Name  => 'read',
		 Description => 'read',
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
  
 Takes a hash. Creates a new Action entry.
 should be better documented.
=cut

sub Create  {
    my $self = shift;
    #TODO check these args and do smart things.
    return($self->SUPER::Create(@_));
}
# }}}

# {{{ sub Delete 
sub Delete  {
    my $self = shift;
    
    return (0, "ScripAction->Delete not implemented");
}
# }}}

# {{{ sub Load 
sub Load  {
    my $self = shift;
    my $identifier = shift;
    
    if (!$identifier) {
	return (0, $self->loc('Input error'));
    }	    
    
    if ($identifier !~ /\D/) {
	$self->SUPER::Load($identifier);
    }
    else {
	$self->LoadByCol('Name', $identifier);
	
    }

    if (@_) {
	# Set the template Id to the passed in template    
	my $template = shift;
	
	$self->{'Template'} = $template;
    }
    return ($self->loc('[_1] ScripAction loaded', $self->Id));
}
# }}}

# {{{ sub LoadAction 

=head2 LoadAction HASH

  Takes a hash consisting of TicketObj and TransactionObj.  Loads an RT::Action:: module.

=cut

sub LoadAction  {
    my $self = shift;
    my %args = ( TransactionObj => undef,
		 TicketObj => undef,
		 @_ );
    
    #TODO: Put this in an eval  
    $self->ExecModule =~ /^(\w+)$/;
    my $module = $1;
    my $type = "RT::Action::". $module;
 
    eval "require $type" || die "Require of $type failed.\n$@\n";
    
    $self->{'Action'}  = $type->new ( 'ScripActionObj' => $self, 
				      'TicketObj' => $args{'TicketObj'},
				      'ScripObj' => $args{'ScripObj'},
				      'TransactionObj' => $args{'TransactionObj'},
				      'TemplateObj' => $self->TemplateObj,
				      'Argument' => $self->Argument,
				    );
}
# }}}

# {{{ sub TemplateObj

=head2 TemplateObj

Return this action\'s template object

=cut

sub TemplateObj {
    my $self = shift;
    return undef unless $self->{Template};
    if (!$self->{'TemplateObj'})  {
	require RT::Template;
	$self->{'TemplateObj'} = RT::Template->new($self->CurrentUser);
	$self->{'TemplateObj'}->LoadById($self->{'Template'});
	
    }
    
    return ($self->{'TemplateObj'});
}
# }}}

# The following methods call the action object

# {{{ sub Prepare 

sub Prepare  {
    my $self = shift;
    return ($self->{'Action'}->Prepare());
  
}
# }}}

# {{{ sub Commit 
sub Commit  {
    my $self = shift;
    return($self->{'Action'}->Commit());
    
    
}
# }}}

# {{{ sub Describe 
sub Describe  {
    my $self = shift;
    return ($self->{'Action'}->Describe());
    
}
# }}}

# {{{ sub DESTROY
sub DESTROY {
    my $self=shift;
    $self->{'Action'} = undef;
    $self->{'TemplateObj'} = undef;
}
# }}}


1;



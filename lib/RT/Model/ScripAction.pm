use warnings;
use strict;

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

  RT::Model::ScripAction - RT Action object

=head1 SYNOPSIS

  use RT::Model::ScripAction;


=head1 DESCRIPTION

This module should never be called directly by client code. it's an internal module which
should only be accessed through exported APIs in other modules.



=head1 METHODS

=cut


package RT::Model::ScripAction;

use strict;
no warnings qw(redefine);
use RT::Model::Template;
use base qw/RT::Record/;
sub table {'ScripActions'}
use Jifty::DBI::Schema;
use Jifty::DBI::Record schema {
        column name => type is 'text';
        column Description => type is 'text';
        column ExecModule => type is 'text';
        column Argument => type is 'text';
    column        Creator =>  max_length is 11,      type is 'int(11)', default is '0';
        column        Created =>       type is 'datetime', default is '';
            column        LastUpdatedBy => max_length is 11,      type is 'int(11)', default is '0';
                column        LastUpdated =>       type is 'datetime', default is '';


};
# }}}

# {{{ sub create 

=head2 Create

Takes a hash. Creates a new Action entry.  should be better
documented.

=cut


# {{{ sub delete 
sub delete  {
    my $self = shift;
    
    return (0, "ScripAction->delete not implemented");
}
# }}}

# {{{ sub load 

=head2 Load IDENTIFIER

Loads an action by its name.

Returns: Id, Error Message

=cut

sub load  {
    my $self = shift;
    my $identifier = shift;
    
    if (!$identifier) {
	return (0, $self->loc('Input error'));
    }	    
    
    if ($identifier !~ /\D/) {
	$self->SUPER::load($identifier);
    }
    else {
	$self->load_by_cols('name', $identifier);
	
    }

    if (@_) {
	# Set the template Id to the passed in template    
	my $template = shift;
	
	$self->{'Template'} = $template;
    }
    return ($self->id, ($self->loc('[_1] ScripAction loaded', $self->id)));
}
# }}}

# {{{ sub loadAction 

=head2 LoadAction HASH

  Takes a hash consisting of TicketObj and TransactionObj.  Loads an RT::ScripAction:: module.

=cut

sub loadAction  {
    my $self = shift;
    my %args = ( TransactionObj => undef,
		 TicketObj => undef,
		 @_ );

    $self->{_TicketObj} = $args{TicketObj};
    
    #TODO: Put this in an eval  
    $self->ExecModule =~ /^(\w+)$/;
    my $module = $1;
    my $type = "RT::ScripAction::". $module;
 
    eval "require $type" || die "Require of $type failed.\n$@\n";
    
    $self->{'Action'}  = $type->new ( Argument => $self->Argument,
                                      CurrentUser => $self->current_user,
                                      ScripActionObj => $self, 
                                      ScripObj => $args{'ScripObj'},
                                      TemplateObj => $self->TemplateObj,
                                      TicketObj => $args{'TicketObj'},
                                      TransactionObj => $args{'TransactionObj'},
				    );
}
# }}}

# {{{ sub TemplateObj

=head2 TemplateObj

Return this action's template object

TODO: Why are we not using the Scrip's template object?


=cut

sub TemplateObj {
    my $self = shift;
    return undef unless $self->{Template};
    if ( !$self->{'TemplateObj'} ) {
        $self->{'TemplateObj'} = RT::Model::Template->new;
        $self->{'TemplateObj'}->load_by_id( $self->{'Template'} );

        if ( ( $self->{'TemplateObj'}->__value('Queue') == 0 )
            && $self->{'_TicketObj'} ) {
            my $tmptemplate = RT::Model::Template->new;
            my ( $ok, $err ) = $tmptemplate->loadQueueTemplate(
                Queue => $self->{'_TicketObj'}->QueueObj->id,
                name  => $self->{'TemplateObj'}->name);

            if ( $tmptemplate->id ) {
                # found the queue-specific template with the same name
                $self->{'TemplateObj'} = $tmptemplate;
            }
        }

    }

    return ( $self->{'TemplateObj'} );
}
# }}}

# The following methods call the action object

# {{{ sub prepare 

sub prepare  {
    my $self = shift;
    $self->{_Message_ID} = 0;
    return ($self->Action->prepare());
  
}
# }}}

# {{{ sub commit 
sub commit  {
    my $self = shift;
    return($self->Action->commit());
    
    
}
# }}}

# {{{ sub Describe 
sub Describe  {
    my $self = shift;
    return ($self->Action->Describe());
    
}
# }}}

=head2 Action

Return the actual RT::ScripAction object for this scrip.

=cut

sub Action {
    my $self = shift;
    return ($self->{'Action'});
}

# {{{ sub DESTROY
sub DESTROY {
    my $self=shift;
    $self->{'_TicketObj'} = undef;
    $self->{'Action'} = undef;
    $self->{'TemplateObj'} = undef;
}
# }}}

=head2 TODO

Between this, RT::Model::Scrip and RT::ScripAction::*, we need to be able to get rid of a 
class. This just reeks of too much complexity -- jesse

=cut

1;



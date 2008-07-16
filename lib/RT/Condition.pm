# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2008 Best Practical Solutions, LLC
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

  RT::Condition - generic baseclass for scrip condition;

=head1 SYNOPSIS

    use RT::Condition;
    my $foo = RT::Condition->new( 
		TransactionObj => $tr, 
		TicketObj => $ti, 
		ScripObj => $scr, 
		Argument => $arg, 
		Type => $type);

    if ($foo->is_applicable) {
 	   # do something
    }


=head1 DESCRIPTION


=head1 METHODS




=cut

package RT::Condition;

use strict;
use warnings;

use base qw/RT::Base/;

# {{{ sub new
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};
    bless( $self, $class );
    $self->_init(@_);
    return $self;
}

# }}}

# {{{ sub _Init
sub _init {
    my $self = shift;
    my %args = (
        transaction_obj       => undef,
        ticket_obj            => undef,
        scrip_obj             => undef,
        template_obj          => undef,
        argument             => undef,
        applicable_trans_types => undef,
        current_user          => undef,
        @_
    );

    $self->{'argument'}             = $args{'argument'};
    $self->{'scrip_obj'}             = $args{'scrip_obj'};
    $self->{'ticket_obj'}            = $args{'ticket_obj'};
    $self->{'transaction_obj'}       = $args{'transaction_obj'};
    $self->{'applicable_trans_types'} = $args{'applicable_trans_types'};
    $self->current_user( $args{'current_user'} );
}

# }}}

# Access Scripwide data

# {{{ sub Argument

=head2 Argument

Return the optional argument associated with this ScripCondition

=cut

sub argument {
    my $self = shift;
    return ( $self->{'argument'} );
}

# }}}

# {{{ sub TicketObj

=head2 TicketObj

Return the ticket object we're talking about

=cut

sub ticket_obj {
    my $self = shift;
    return ( $self->{'ticket_obj'} );
}

# }}}

# {{{ sub ScripObj

=head2 ScripObj

Return the Scrip object we're talking about

=cut

sub scrip_obj {
    my $self = shift;
    return ( $self->{'scrip_obj'} );
}

# }}}
# {{{ sub TransactionObj

=head2 TransactionObj

Return the transaction object we're talking about

=cut

sub transaction_obj {
    my $self = shift;
    return ( $self->{'transaction_obj'} );
}

# }}}

# {{{ sub Type

=head2 Type 



=cut

sub applicable_trans_types {
    my $self = shift;
    return ( $self->{'applicable_trans_types'} );
}

# }}}

# Scrip methods

#What does this type of Action does

# {{{ sub Describe
sub describe {
    my $self = shift;
    return ( $self->loc( "No description for %1", ref $self ) );
}

# }}}

#Parse the templates, get things ready to go.

#If this rule applies to this transaction, return true.

# {{{ sub IsApplicable
sub is_applicable {
    my $self = shift;
    return (undef);
}

# }}}

# {{{ sub DESTROY
sub DESTROY {
    my $self = shift;

    # We need to clean up all the references that might maybe get
    # oddly circular
    $self->{'template_obj'} = undef;
    $self->{'ticket_obj'} = undef;
    $self->{'transaction_obj'} = undef;
    $self->{'scrip_obj'}       = undef;

}

1;

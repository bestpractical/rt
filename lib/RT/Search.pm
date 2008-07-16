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

  RT::Search - generic baseclass for searches;

=head1 SYNOPSIS

    use RT::Search;
    my $tickets = RT::Model::TicketCollection->new( current_user => $CurrentUser );
    my $foo = RT::Search->new(argument => $arg,
                              tickets_obj => $tickets);
    $foo->prepare();
    while ( my $ticket = $foo->next ) {
        # Do something with each ticket we've found
    }


=head1 DESCRIPTION


=head1 METHODS




=cut

package RT::Search;

use strict;

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

# {{{ sub _init
sub _init {
    my $self = shift;
    my %args = (
        tickets_obj => undef,
        argument   => undef,
        @_
    );

    $self->{'tickets_obj'} = $args{'tickets_obj'};
    $self->{'argument'}   = $args{'argument'};
}

# }}}

# {{{ sub argument

=head2 argument

Return the optional argument associated with this Search

=cut

sub argument {
    my $self = shift;
    return ( $self->{'argument'} );
}

# }}}

=head2 tickets_obj 

Return the Tickets object passed into this search

=cut

sub tickets_obj {
    my $self = shift;
    return ( $self->{'tickets_obj'} );
}

# {{{ sub describe
sub describe {
    my $self = shift;
    return ( $self->loc( "No description for %1", ref $self ) );
}

# }}}

# {{{ sub prepare
sub prepare {
    my $self = shift;
    return (1);
}

# }}}

1;

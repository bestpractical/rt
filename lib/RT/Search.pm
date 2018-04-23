# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2018 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
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
    my $tickets = RT::Tickets->new($CurrentUser);
    my $foo = RT::Search->new(Argument => $arg,
                              TicketsObj => $tickets);
    $foo->Prepare();
    while ( my $ticket = $foo->Next ) {
        # Do something with each ticket we've found
    }


=head1 DESCRIPTION


=head1 METHODS




=cut

package RT::Search;

use strict;
use warnings;

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};
    bless( $self, $class );
    $self->_Init(@_);
    return $self;
}

sub _Init {
    my $self = shift;
    my %args = (
        TicketsObj => undef,
        Argument   => undef,
        @_
    );

    $self->{'TicketsObj'} = $args{'TicketsObj'};
    $self->{'Argument'}   = $args{'Argument'};
}

=head2 Argument

Return the optional argument associated with this Search

=cut

sub Argument {
    my $self = shift;
    return ( $self->{'Argument'} );
}

=head2 TicketsObj

Return the Tickets object passed into this search

=cut

sub TicketsObj {
    my $self = shift;
    return ( $self->{'TicketsObj'} );
}

sub Describe {
    my $self = shift;
    return ( $self->loc( "No description for [_1]", ref $self ) );
}

sub Prepare {
    my $self = shift;
    return (1);
}

RT::Base->_ImportOverlays();

1;

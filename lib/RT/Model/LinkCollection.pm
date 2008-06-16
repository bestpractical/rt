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

  RT::Model::LinkCollection - A collection of Link objects

=head1 SYNOPSIS

  use RT::Model::LinkCollection;
  my $links = RT::Model::LinkCollection->new($CurrentUser);

=head1 description


=head1 METHODS



=cut

use warnings;
use strict;

package RT::Model::LinkCollection;

use base qw/RT::SearchBuilder/;

use RT::URI;

# {{{ sub limit
sub limit {
    my $self = shift;
    my %args = (
        entry_aggregator => 'AND',
        operator         => '=',
        @_
    );

    #if someone's trying to search for tickets, try to resolve the uris for searching.

    if (   ( $args{'operator'} eq '=' ) and ( $args{'column'} eq 'base' )
        or ( $args{'column'} eq 'target' ) )
    {
        my $dummy = RT::URI->new;
        $dummy->from_uri( $args{'value'} );

        # $uri = $dummy->uri;
    }

    # If we're limiting by target, order by base
    # (order by the thing that's changing)

    if (   ( $args{'column'} eq 'target' )
        or ( $args{'column'} eq 'local_target' ) )
    {
        $self->order_by(
            alias  => 'main',
            column => 'base',
            order  => 'ASC'
        );
    } elsif ( ( $args{'column'} eq 'base' )
        or ( $args{'column'} eq 'local_base' ) )
    {
        $self->order_by(
            alias  => 'main',
            column => 'target',
            order  => 'ASC'
        );
    }

    $self->SUPER::limit(%args);
}

# }}}

# {{{ limit_RefersTo

=head2 limit_refers_to URI

find all things that refer to URI

=cut

sub limit_refers_to {
    my $self = shift;
    my $URI  = shift;

    $self->limit( column => 'type',   value => 'RefersTo' );
    $self->limit( column => 'target', value => $URI );
}

# }}}
# {{{ limit_ReferredToBy

=head2 limit_referred_to_by URI

find all things that URI refers to

=cut

sub limit_referred_to_by {
    my $self = shift;
    my $URI  = shift;

    $self->limit( column => 'type', value => 'RefersTo' );
    $self->limit( column => 'base', value => $URI );
}

# }}}

# {{{ Next
sub next {
    my $self = shift;

    my $Link = $self->SUPER::next();
    return $Link unless $Link && ref $Link;

    # Skip links to local objects thast are deleted
    if (    $Link->target_uri->is_local
        and UNIVERSAL::isa( $Link->target_obj, "RT::Model::Ticket" )
        and ( $Link->target_obj->__value('status') || '' ) eq "deleted" )
    {
        return $self->next;
    } elsif ( $Link->base_uri->is_local
        and UNIVERSAL::isa( $Link->base_obj, "RT::Model::Ticket" )
        and ( $Link->base_obj->__value('status') || '' ) eq "deleted" )
    {
        return $self->next;
    } else {
        return $Link;
    }
}

# }}}
1;


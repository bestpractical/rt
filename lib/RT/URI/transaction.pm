# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2026 Best Practical Solutions, LLC
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

use strict;
use warnings;

package RT::URI::transaction;
use base qw/RT::URI::base/;

require RT::Transaction;

=head1 NAME

RT::URI::transaction - Internal URIs for linking to an L<RT::Transaction>

=head1 DESCRIPTION

This class should rarely be used directly, but via L<RT::URI> instead.

Represents, parses, and generates internal RT URIs such as:

    transaction:42
    transaction://example.com/42

These URIs are used to link directly to a transaction within RT, for example
when recording links in ticket history.

=head1 METHODS

Much of the interface below is dictated by L<RT::URI> and L<RT::URI::base>.

=head2 Scheme

Return the URI scheme for transactions

=cut

sub Scheme {"transaction"}

=head2 LocalURIPrefix

Returns the site-specific prefix for a local transaction URI

=cut

sub LocalURIPrefix {
    my $self = shift;
    return $self->Scheme . "://" . RT->Config->Get('Organization');
}

=head2 IsLocal

Returns a true value, the transaction ID, if this object represents a local
transaction, undef otherwise.

=cut

sub IsLocal {
    my $self   = shift;
    my $prefix = $self->LocalURIPrefix;
    return $1 if $self->{uri} =~ qr!^\Q$prefix\E/(\d+)!i;
    return undef;
}

=head2 URIForObject RT::Transaction

Returns the URI for a local L<RT::Transaction> object

=cut

sub URIForObject {
    my $self = shift;
    my $obj  = shift;
    return $self->LocalURIPrefix . '/' . $obj->Id;
}

=head2 ParseURI URI

Primarily used by L<RT::URI> to set internal state.

Figures out from a C<transaction:> URI whether it refers to a local transaction
and the transaction ID.

Returns the transaction ID if local, otherwise returns false.

=cut

sub ParseURI {
    my $self = shift;
    my $uri  = shift;

    my $scheme = $self->Scheme;

    # canonicalize "42" and "transaction:42" -> transaction://example.com/42
    if ( $uri =~ /^(?:\Q$scheme\E:)?(\d+)$/i ) {
        my $txn = RT::Transaction->new( $self->CurrentUser );
        my ( $ret, $msg ) = $txn->Load($1);
        if ( $ret && $txn->id ) {
            $self->{'uri'}    = $txn->URI;
            $self->{'object'} = $txn;
        }
        else {
            RT->Logger->error("Unable to load transaction for id: $1: $msg");
            return;
        }
    }
    else {
        $self->{'uri'} = $uri;
    }

    my $txn = RT::Transaction->new( $self->CurrentUser );
    if ( my $id = $self->IsLocal ) {
        $txn->Load($id);
        if ( $txn->id ) {
            $self->{'object'} = $txn;
        }
        else {
            RT->Logger->error("Can't load Transaction #$id by URI '$uri'");
            return;
        }
    }
    return $txn->id;
}

=head2 Object

Returns the object for this URI, if it's local. Otherwise returns undef.

=cut

sub Object {
    my $self = shift;
    return $self->{'object'};
}

=head2 HREF

If this is a local transaction, return an HTTP URL pointing at it, anchored at
the transaction in its object's history (C<...#txn-NN>). A ticket transaction
uses the dedicated F</Transaction/Display.html> page. For other object types we
link to that object's dedicated History page, which always renders the
transaction (object display pages are page-layout driven and may omit history).

Otherwise, return its URI.

=cut

sub HREF {
    my $self = shift;
    if ( $self->IsLocal and $self->Object ) {
        my $txn = $self->Object;

        # A ticket transaction has a dedicated single-transaction display page.
        return RT->Config->Get('WebURL') . 'Transaction/Display.html?id=' . $txn->id
            if $txn->ObjectType eq 'RT::Ticket';

        # Other object types link to their History page: display pages are page-layout
        # driven and may omit history (and the only group history page is admin-only).
        my %display = (
            'RT::Asset'   => 'Asset/History.html?id=',
            'RT::Article' => 'Articles/Article/History.html?id=',
            'RT::User'    => 'User/History.html?id=',
            'RT::Group'   => 'Admin/Groups/History.html?id=',
        );
        if ( my $path = $display{ $txn->ObjectType } ) {
            return RT->Config->Get('WebURL') . $path . $txn->ObjectId . '#txn-' . $txn->id;
        }
    }
    return $self->URI;
}

=head2 AsString

Returns a description of this object

=cut

sub AsString {
    my $self = shift;
    if ( $self->IsLocal and $self->Object ) {
        return $self->loc( 'Transaction #[_1]', $self->Object->id );
    }
    else {
        return $self->SUPER::AsString(@_);
    }
}

RT::Base->_ImportOverlays();

1;

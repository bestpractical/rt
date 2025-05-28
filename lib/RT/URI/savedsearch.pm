# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2025 Best Practical Solutions, LLC
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

package RT::URI::savedsearch;
use base qw/RT::URI::base/;

require RT::SavedSearch;

=head1 NAME

RT::URI::savedsearch - Internal URIs for linking to an L<RT::SavedSearch>

=head1 DESCRIPTION

This class should rarely be used directly, but via L<RT::URI> instead.

Represents, parses, and generates internal RT URIs such as:

    savedsearch:42
    savedsearch://example.com/42

These URIs are used to link between objects in RT such as associating an
savedsearch with a dashboard.

=head1 METHODS

Much of the interface below is dictated by L<RT::URI> and L<RT::URI::base>.

=head2 Scheme

Return the URI scheme for savedsearchs

=cut

sub Scheme {"savedsearch"}

=head2 LocalURIPrefix

Returns the site-specific prefix for a local savedsearch URI

=cut

sub LocalURIPrefix {
    my $self = shift;
    return $self->Scheme . "://" . RT->Config->Get('Organization');
}

=head2 IsLocal

Returns a true value, the savedsearch ID, if this object represents a local savedsearch,
undef otherwise.

=cut

sub IsLocal {
    my $self   = shift;
    my $prefix = $self->LocalURIPrefix;
    return $1 if $self->{uri} =~ qr!^\Q$prefix\E/(\d+)!i;
    return undef;
}

=head2 URIForObject RT::SavedSearch

Returns the URI for a local L<RT::SavedSearch> object

=cut

sub URIForObject {
    my $self = shift;
    my $obj  = shift;
    return $self->LocalURIPrefix . '/' . $obj->Id;
}

=head2 ParseURI URI

Primarily used by L<RT::URI> to set internal state.

Figures out from an C<savedsearch:> URI whether it refers to a local savedsearch and the
savedsearch ID.

Returns the savedsearch ID if local, otherwise returns false.

=cut

sub ParseURI {
    my $self = shift;
    my $uri  = shift;

    my $scheme = $self->Scheme;

    # canonicalize "42" and "savedsearch:42" -> savedsearch://example.com/42
    if ( $uri =~ /^(?:\Q$scheme\E:)?(\d+)$/i ) {
        my $savedsearch_obj = RT::SavedSearch->new( $self->CurrentUser );
        my ( $ret, $msg ) = $savedsearch_obj->Load($1);

        if ($ret) {
            $self->{'uri'}    = $savedsearch_obj->URI;
            $self->{'object'} = $savedsearch_obj;
        }
        else {
            RT::Logger->error("Unable to load savedsearch for id: $1: $msg");
            return;
        }
    }
    else {
        $self->{'uri'} = $uri;
    }

    my $savedsearch = RT::SavedSearch->new( $self->CurrentUser );
    if ( my $id = $self->IsLocal ) {
        $savedsearch->Load($id);

        if ( $savedsearch->id ) {
            $self->{'object'} = $savedsearch;
        }
        else {
            RT->Logger->error("Can't load SavedSearch #$id by URI '$uri'");
            return;
        }
    }
    return $self->{'object'}->id;
}

=head2 Object

Returns the object for this URI, if it's local. Otherwise returns undef.

=cut

sub Object {
    my $self = shift;
    return $self->{'object'};
}

=head2 HREF

If this is a local dashboard, return an HTTP URL for it.

Otherwise, return its URI.

=cut

sub HREF {
    my $self = shift;
    return $self->URI;
}

=head2 AsString

Returns a description of this object

=cut

sub AsString {
    my $self = shift;
    if ( $self->IsLocal and $self->Object ) {
        return $self->loc( 'Saved Search #[_1]: [_2]', $self->Object->id, $self->Object->Name );
    }
    else {
        return $self->SUPER::AsString(@_);
    }
}

RT::Base->_ImportOverlays();

1;

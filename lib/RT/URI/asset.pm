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

use strict;
use warnings;

package RT::URI::asset;
use base qw/RT::URI::base/;

require RT::Asset;

=head1 NAME

RT::URI::asset - Internal URIs for linking to an L<RT::Asset>

=head1 DESCRIPTION

This class should rarely be used directly, but via L<RT::URI> instead.

Represents, parses, and generates internal RT URIs such as:

    asset:42
    asset://example.com/42

These URIs are used to link between objects in RT such as associating an asset
with a ticket or an asset with another asset.

=head1 METHODS

Much of the interface below is dictated by L<RT::URI> and L<RT::URI::base>.

=head2 Scheme

Return the URI scheme for assets

=cut

sub Scheme { "asset" }

=head2 LocalURIPrefix

Returns the site-specific prefix for a local asset URI

=cut

sub LocalURIPrefix {
    my $self = shift;
    return $self->Scheme . "://" . RT->Config->Get('Organization');
}

=head2 IsLocal

Returns a true value, the asset ID, if this object represents a local asset,
undef otherwise.

=cut

sub IsLocal {
    my $self   = shift;
    my $prefix = $self->LocalURIPrefix;
    return $1 if $self->{uri} =~ qr!^\Q$prefix\E/(\d+)!i;
    return undef;
}

=head2 URIForObject RT::Asset

Returns the URI for a local L<RT::Asset> object

=cut

sub URIForObject {
    my $self = shift;
    my $obj  = shift;
    return $self->LocalURIPrefix . '/' . $obj->Id;
}

=head2 ParseURI URI

Primarily used by L<RT::URI> to set internal state.

Figures out from an C<asset:> URI whether it refers to a local asset and the
asset ID.

Returns the asset ID if local, otherwise returns false.

=cut

sub ParseURI {
    my $self = shift;
    my $uri  = shift;

    my $scheme = $self->Scheme;

    # canonicalize "42" and "asset:42" -> asset://example.com/42
    if ($uri =~ /^(?:\Q$scheme\E:)?(\d+)$/i) {
        my $asset_obj = RT::Asset->new( $self->CurrentUser );
        my ($ret, $msg) = $asset_obj->Load($1);

        if ( $ret ) {
            $self->{'uri'} = $asset_obj->URI;
            $self->{'object'} = $asset_obj;
        }
        else {
            RT::Logger->error("Unable to load asset for id: $1: $msg");
            return;
        }
    }
    else {
        $self->{'uri'} = $uri;
    }

    my $asset = RT::Asset->new( $self->CurrentUser );
    if ( my $id = $self->IsLocal ) {
        $asset->Load($id);

        if ($asset->id) {
            $self->{'object'} = $asset;
        } else {
            RT->Logger->error("Can't load Asset #$id by URI '$uri'");
            return;
        }
    }
    return $asset->id;
}

=head2 Object

Returns the object for this URI, if it's local. Otherwise returns undef.

=cut

sub Object {
    my $self = shift;
    return $self->{'object'};
}

=head2 HREF

If this is a local asset, return an HTTP URL for it.

Otherwise, return its URI.

=cut

sub HREF {
    my $self = shift;
    if ($self->IsLocal and $self->Object) {
        return RT->Config->Get('WebURL')
             . ( $self->CurrentUser->Privileged ? "" : "SelfService/" )
             . "Asset/Display.html?id="
             . $self->Object->Id;
    } else {
        return $self->URI;
    }
}

=head2 AsString

Returns a description of this object

=cut

sub AsString {
    my $self = shift;
    if ($self->IsLocal and $self->Object) {
        my $object = $self->Object;
        if ( $object->Name ) {
            return $self->loc('Asset #[_1]: [_2]', $object->id, $object->Name);
        } else {
            return $self->loc('Asset #[_1]', $object->id);
        }
    } else {
        return $self->SUPER::AsString(@_);
    }
}

1;

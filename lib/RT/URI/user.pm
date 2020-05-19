# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2020 Best Practical Solutions, LLC
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

package RT::URI::user;
use base qw/RT::URI::base/;

require RT::User;

=head1 NAME

RT::URI::user - Internal URIs for linking to an L<RT::User>

=head1 DESCRIPTION

This class should rarely be used directly, but via L<RT::URI> instead.

Represents, parses, and generates internal RT URIs such as:

    user:42
    user://example.com/42

These URIs are used to link between objects in RT such as referencing an RT user
record from a ticket in the Links section.

=head1 METHODS

Much of the interface below is dictated by L<RT::URI> and L<RT::URI::base>.

=head2 Scheme

Return the URI scheme for groups

=cut

sub Scheme { "user" }

=head2 LocalURIPrefix

Returns the site-specific prefix for a local group URI

=cut

sub LocalURIPrefix {
    my $self = shift;
    return $self->Scheme . "://" . RT->Config->Get('Organization');
}

=head2 IsLocal

Returns a true value, the grouup ID, if this object represents a local group,
undef otherwise.

=cut

sub IsLocal {
    my $self   = shift;
    my $prefix = $self->LocalURIPrefix;
    return $1 if $self->{uri} =~ qr!^\Q$prefix\E/(\d+)!i;
    return undef;
}

=head2 URIForObject RT::Group

Returns the URI for a local L<RT::Group> object

=cut

sub URIForObject {
    my $self = shift;
    my $obj  = shift;
    return $self->LocalURIPrefix . '/' . $obj->Id;
}

=head2 ParseURI URI

Primarily used by L<RT::URI> to set internal state.

Figures out from an C<user:> URI whether it refers to a local user and the
user ID.

Returns the user ID if local, otherwise returns false.

=cut

sub ParseURI {
    my $self = shift;
    my $uri  = shift;

    my $scheme = $self->Scheme;

    # canonicalize "42" and "user:42" -> user://example.com/42
    if ($uri =~ /^(?:\Q$scheme\E:)?(\d+)$/i) {
        my $user_obj = RT::User->new( $self->CurrentUser );
        my ($ret, $msg) = $user_obj->Load($1);

        if ( $ret ) {
            $self->{'uri'} = $user_obj->URI;
            $self->{'object'} = $user_obj;
        }
        else {
            RT::Logger->error("Unable to load user for id: $1: $msg");
            return;
        }
    }
    else {
        $self->{'uri'} = $uri;
    }

    my $user = RT::User->new( $self->CurrentUser );
    if ( my $id = $self->IsLocal ) {
        $user->Load($id);

        if ($user->id) {
            $self->{'object'} = $user;
        } else {
            RT->Logger->error("Can't load User #$id by URI '$uri'");
            return;
        }
    }
    return $user->id;
}

=head2 Object

Returns the object for this URI, if it's local. Otherwise returns undef.

=cut

sub Object {
    my $self = shift;
    return $self->{'object'};
}

=head2 HREF

If this is a local group, return an HTTP URL for it.

Otherwise, return its URI.

=cut

sub HREF {
    my $self = shift;
    if ($self->IsLocal and $self->Object) {
        return RT->Config->Get('WebURL')
             . "User/Summary.html?id="
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
            return $self->loc('[_1] (User #[_2])', $object->Name, $object->id);
        } else {
            return $self->loc('User #[_1]', $object->id);
        }
    } else {
        return $self->SUPER::AsString(@_);
    }
}

1;

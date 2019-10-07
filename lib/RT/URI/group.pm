# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2019 Best Practical Solutions, LLC
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

package RT::URI::group;
use base qw/RT::URI::base/;

require RT::Group;

=head1 NAME

RT::URI::group - Internal URIs for linking to an L<RT::Group>

=head1 DESCRIPTION

This class should rarely be used directly, but via L<RT::URI> instead.

Represents, parses, and generates internal RT URIs such as:

    group:42
    group://example.com/42

These URIs are used to link between objects in RT such as associating a group
with another group.

=head1 METHODS

Much of the interface below is dictated by L<RT::URI> and L<RT::URI::base>.

=head2 Scheme

Return the URI scheme for groups

=cut

sub Scheme { "group" }

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

Figures out from an C<group:> URI whether it refers to a local group and the
group ID.

Returns the group ID if local, otherwise returns false.

=cut

sub ParseURI {
    my $self = shift;
    my $uri  = shift;

    my $scheme = $self->Scheme;

    # canonicalize "42" and "group:42" -> group://example.com/42
    if ($uri =~ /^(?:\Q$scheme\E:)?(\d+)$/i) {
        my $group_obj = RT::Group->new( $self->CurrentUser );
        my ($ret, $msg) = $group_obj->Load($1);

        if ( $ret ) {
            $self->{'uri'} = $group_obj->URI;
            $self->{'object'} = $group_obj;
        }
        else {
            RT::Logger->error("Unable to load group for id: $1: $msg");
            return;
        }
    }
    else {
        $self->{'uri'} = $uri;
    }

    my $group = RT::Group->new( $self->CurrentUser );
    if ( my $id = $self->IsLocal ) {
        $group->Load($id);

        if ($group->id) {
            $self->{'object'} = $group;
        } else {
            RT->Logger->error("Can't load Group #$id by URI '$uri'");
            return;
        }
    }
    return $group->id;
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
#             . ( $self->CurrentUser->Privileged ? "" : "SelfService/" )
#             . "Admin/Groups/Modify.html?id="
             . "Group/Summary.html?id="
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
            return $self->loc('[_1] (Group #[_2])', $object->Name, $object->id);
        } else {
            return $self->loc('Group #[_1]', $object->id);
        }
    } else {
        return $self->SUPER::AsString(@_);
    }
}

1;

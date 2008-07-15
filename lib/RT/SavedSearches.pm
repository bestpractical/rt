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

  RT::SavedSearches - a pseudo-collection for SavedSearch objects.

=head1 SYNOPSIS

  use RT::SavedSearch

=head1 description

  SavedSearches is an object consisting of a number of SavedSearch objects.
  It works more or less like a Jifty::DBI collection, although it
  is not.

=head1 METHODS


=cut

package RT::SavedSearches;

use RT::SavedSearch;

use strict;
use base 'RT::Base';

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};
    bless( $self, $class );
    $self->_get_current_user(@_);
    $self->{'idx'}     = 0;
    $self->{'objects'} = [];
    return $self;
}

=head2 limit_to_privacy

Takes two argumets: a privacy string, of the format "<class>-<id>", as
produced by RT::SavedSearch::Privacy(); and a type string, as produced
by RT::SavedSearch::Type().  The SavedSearches object will load the
searches belonging to that user or group that are of the type
specified.  If no type is specified, all the searches belonging to the
user/group will be loaded.  Repeated calls to the same object should DTRT.

=cut

sub limit_to_privacy {
    my $self    = shift;
    my $privacy = shift;
    my $type    = shift;

    my $object = $self->_get_object($privacy);

    if ($object) {
        $self->{'objects'} = [];
        my @search_atts = $object->attributes->named('saved_search');
        foreach my $att (@search_atts) {
            my $search = RT::SavedSearch->new;
            $search->load( $privacy, $att->id );

            next if $type && $search->type ne $type;
            push( @{ $self->{'objects'} }, $search );
        }
    } else {
        Jifty->log->error("Could not load object $privacy");
    }
}

### Accessor methods

=head2 next

Returns the next object in the collection.

=cut

sub next {
    my $self   = shift;
    my $search = $self->{'objects'}->[ $self->{'idx'} ];
    if ($search) {
        $self->{'idx'}++;
    } else {

        # We have run out of objects; reset the counter.
        $self->{'idx'} = 0;
    }
    return $search;
}

=head2 count

Returns the number of search objects found.

=cut

sub count {
    my $self = shift;
    return scalar @{ $self->{'objects'} };
}

### Internal methods

# _Getobject: helper routine to load the correct object whose parameters
#  have been passed.

sub _get_object {
    my $self    = shift;
    my $privacy = shift;

    return RT::SavedSearch->new->_get_object($privacy);
}

### Internal methods

# _Privacyobjects: returns a list of objects that can be used to load saved searches from.

sub _privacy_objects {
    my $self        = shift;
    my $CurrentUser = $self->current_user;

    my $groups = RT::Model::GroupCollection->new;
    $groups->limit_to_user_defined_groups;
    $groups->with_member(
        principal_id => $self->current_user->id,
        recursively  => 1
    );

    return ( $CurrentUser->user_object, @{ $groups->items_array_ref() } );
}

1;

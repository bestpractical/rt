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

  RT::SharedSettings - a pseudo-collection for SharedSetting objects.

=head1 SYNOPSIS

  use RT::SharedSettings

=head1 DESCRIPTION

  SharedSettings is an object consisting of a number of SharedSetting objects.
  It works more or less like a DBIx::SearchBuilder collection, although it
  is not.

=head1 METHODS


=cut

package RT::SharedSettings;

use strict;
use warnings;
use base 'RT::Base';

use RT::SharedSetting;

sub new  {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};
    bless ($self, $class);
    $self->CurrentUser(@_);
    $self->{'idx'} = 0;
    $self->{'objects'} = [];
    return $self;
}

### Accessor methods

=head2 Next

Returns the next object in the collection.

=cut

sub Next {
    my $self = shift;
    my $search = $self->{'objects'}->[$self->{'idx'}];
    if ($search) {
        $self->{'idx'}++;
    } else {
        # We have run out of objects; reset the counter.
        $self->{'idx'} = 0;
    }
    return $search;
}

=head2 Count

Returns the number of search objects found.

=cut

sub Count {
    my $self = shift;
    return scalar @{$self->{'objects'}};
}

=head2 CountAll

Returns the number of search objects found

=cut

sub CountAll {
    my $self = shift;
    return $self->Count;
}

=head2 GotoPage

Act more like a normal L<DBIx::SearchBuilder> collection.
Moves the internal index around

=cut

sub GotoPage {
    my $self = shift;
    $self->{idx} = shift;
}

### Internal methods

# _GetObject: helper routine to load the correct object whose parameters
#  have been passed.

sub _GetObject {
    my $self = shift;
    my $privacy = shift;

    return $self->RecordClass->new($self->CurrentUser)->_GetObject($privacy);
}

RT::Base->_ImportOverlays();

1;


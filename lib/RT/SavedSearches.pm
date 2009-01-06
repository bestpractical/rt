# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
# 
# This software is Copyright (c) 1996-2009 Best Practical Solutions, LLC
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

  RT::SavedSearches - a pseudo-collection for SavedSearch objects.

=head1 SYNOPSIS

  use RT::SavedSearch

=head1 DESCRIPTION

  SavedSearches is an object consisting of a number of SavedSearch objects.
  It works more or less like a DBIx::SearchBuilder collection, although it
  is not.

=head1 METHODS


=cut

package RT::SavedSearches;

use RT::SavedSearch;

use strict;
use base 'RT::Base';

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

=head2 LimitToPrivacy

Takes two argumets: a privacy string, of the format "<class>-<id>", as
produced by RT::SavedSearch::Privacy(); and a type string, as produced
by RT::SavedSearch::Type().  The SavedSearches object will load the
searches belonging to that user or group that are of the type
specified.  If no type is specified, all the searches belonging to the
user/group will be loaded.  Repeated calls to the same object should DTRT.

=cut

sub LimitToPrivacy {
    my $self = shift;
    my $privacy = shift;
    my $type = shift;

    my $object = $self->_GetObject($privacy);

    if ($object) {
	$self->{'objects'} = [];
	my @search_atts = $object->Attributes->Named('SavedSearch');
	foreach my $att (@search_atts) {
	    my $search = RT::SavedSearch->new($self->CurrentUser);
	    $search->Load($privacy, $att->Id);
	    next if $type && $search->Type ne $type;
	    push(@{$self->{'objects'}}, $search);
	}
    } else {
	$RT::Logger->error("Could not load object $privacy");
    }
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

### Internal methods

# _GetObject: helper routine to load the correct object whose parameters
#  have been passed.

sub _GetObject {
    my $self = shift;
    my $privacy = shift;

    return RT::SavedSearch->new($self->CurrentUser)->_GetObject($privacy);
}

### Internal methods

# _PrivacyObjects: returns a list of objects that can be used to load saved searches from.

sub _PrivacyObjects {
    my $self        = shift;
    my $CurrentUser = $self->CurrentUser;

    my $groups = RT::Groups->new($CurrentUser);
    $groups->LimitToUserDefinedGroups;
    $groups->WithMember( PrincipalId => $CurrentUser->Id,
                         Recursively => 1 );

    return ( $CurrentUser->UserObj, @{ $groups->ItemsArrayRef() } );
}

eval "require RT::SavedSearches_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/SavedSearches_Vendor.pm});
eval "require RT::SavedSearches_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/SavedSearches_Local.pm});

1;

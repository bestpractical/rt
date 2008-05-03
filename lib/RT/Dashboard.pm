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
=head1 NAME

  RT::Dashboard - an API for saving and retrieving dashboards

=head1 SYNOPSIS

  use RT::Dashboard

=head1 DESCRIPTION

  Dashboard is an object that can belong to either an RT::User or an
  RT::Group.  It consists of an ID, a name, and a number of
  saved searches.

=head1 METHODS


=cut

package RT::Dashboard;

use RT::SavedSearch;

use strict;
use warnings;
use base qw/RT::SharedSetting/;

my %new_rights = (
    ModifyDashboard    => 'Create and modify dashboards', #loc_pair
    SubscribeDashboard => 'Subscribe to email dashboards', #loc_pair
);

use RT::System;
$RT::System::RIGHTS = { %$RT::System::RIGHTS, %new_rights };
%RT::ACE::LOWERCASERIGHTNAMES = ( %RT::ACE::LOWERCASERIGHTNAMES,
                                  map { lc($_) => $_ } keys %new_rights);

=head2 ObjectName

An object of this class is called "dashboard"

=cut

sub ObjectName { "dashboard" }

sub SaveAttribute {
    my $self   = shift;
    my $object = shift;
    my $args   = shift;

    return $object->AddAttribute(
        'Name'        => 'Dashboard',
        'Description' => $args->{'Name'},
        'Content'     => {Searches => $args->{'Searches'}},
    );
}

sub UpdateAttribute {
    my $self = shift;
    my $args = shift;

    my ($status, $msg) = (1, undef);
    if (defined $args->{'Searches'}) {
        ($status, $msg) = $self->{'Attribute'}->SetSubValues(
            Searches => $args->{'Searches'},
        );
    }

    if ($status && $args->{'Name'}) {
        ($status, $msg) = $self->{'Attribute'}->SetDescription($args->{'Name'});
    }

    return ($status, $msg);
}

=head2 Searches

Returns a list of loaded saved searches

=cut

sub Searches {
    my $self = shift;
    return map {
               my $search = RT::SavedSearch->new($self->CurrentUser);
               $search->Load($_->[0], $_->[1]);
               $search
           } $self->SearchIds;
}

=head2 SearchIds

Returns a list of array references, each being a saved-search privacy, ID, and
description

=cut

sub SearchIds {
    my $self = shift;
    return unless ref($self->{'Attribute'}) eq 'RT::Attribute';
    return @{ $self->{'Attribute'}->SubValue('Searches') || [] };
}

=head2 SearchPrivacies

Returns a list of array references, each one being suitable to pass to
/Elements/ShowSearch.

=cut

sub SearchPrivacies {
    my $self = shift;
    return map { [$self->SearchPrivacy(@$_)] } $self->SearchIds;
}

=head2 SearchPrivacy TYPE, ID, DESC

Returns an array for one saved search, suitable for passing to
/Elements/ShowSearch.

=cut

sub SearchPrivacy {
    my $self = shift;
    my ($type, $id, $desc) = @_;
    if ($type eq 'RT::System') {
        return Name => $desc;
    }

    return SavedSearch => join('-', $type, 'SavedSearch', $id);
}

# _PrivacyObjects: returns a list of objects that can be used to load
# dashboards from. Unlike SavedSearch, this will return the System object if
# applicable. You may pass in a paramhash of ShowSystem to force
# showing/hiding of the System object

sub _PrivacyObjects {
    my $self = shift;
    my %args = @_;

    my $CurrentUser = $self->CurrentUser;
    my @objects = $CurrentUser->UserObj;

    my $groups = RT::Groups->new($CurrentUser);
    $groups->LimitToUserDefinedGroups;
    $groups->WithMember( PrincipalId => $CurrentUser->Id,
                         Recursively => 1 );

    push @objects, @{ $groups->ItemsArrayRef };

    # if ShowSystem, always show it
    # if not ShowSystem, then show only if the user didn't specify AND the
    #    current user is superuser
    push @objects, RT::System->new($CurrentUser)
        if $args{ShowSystem}
        || (!defined($args{ShowSystem})
            && $CurrentUser->HasRight(Object => $RT::System,
                                      Right => 'SuperUser'));

    return @objects;
}

eval "require RT::Dashboard_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Dashboard_Vendor.pm});
eval "require RT::Dashboard_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Dashboard_Local.pm});

1;

# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2008 Best Practical Solutions, LLC
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

  RT::Dashboard - an API for saving and retrieving dashboards

=head1 SYNOPSIS

  use RT::Dashboard

=head1 DESCRIPTION

  Dashboard is an object that can belong to either an RT::Model::User or an
  RT::Model::Group.  It consists of an ID, a name, and a number of
  saved searches.

=head1 METHODS


=cut

package RT::Dashboard;

use RT::SavedSearch;

use strict;
use warnings;
use base qw/RT::SharedSetting/;

my %new_rights = (
    SubscribeDashboard => 'Subscribe to email dashboards',    #loc_pair

    SeeDashboard    => 'View system dashboards',              #loc_pair
    CreateDashboard => 'Create system dashboards',            #loc_pair
    ModifyDashboard => 'Modify system dashboards',            #loc_pair
    DeleteDashboard => 'Delete system dashboards',            #loc_pair

    SeeOwnDashboard    => 'View personal dashboards',         #loc_pair
    CreateOwnDashboard => 'Create personal dashboards',       #loc_pair
    ModifyOwnDashboard => 'Modify personal dashboards',       #loc_pair
    DeleteOwnDashboard => 'Delete personal dashboards',       #loc_pair
);

use RT::System;
$RT::System::RIGHTS = { %$RT::System::RIGHTS, %new_rights };
%RT::Model::ACE::LOWERCASERIGHTNAMES =
  ( %RT::Model::ACE::LOWERCASERIGHTNAMES, map { lc($_) => $_ } keys %new_rights );

=head2 object_name

An object of this class is called "dashboard"

=cut

sub object_name { "dashboard" }

sub save_attribute {
    my $self   = shift;
    my $object = shift;
    my $args   = shift;

    return $object->add_attribute(
        'name'        => 'Dashboard',
        'description' => $args->{'name'},
        'content'     => { Searches => $args->{'searches'} },
    );
}

sub update_attribute {
    my $self = shift;
    my $args = shift;

    my ( $status, $msg ) = ( 1, undef );
    if ( defined $args->{'searches'} ) {
        ( $status, $msg ) =
          $self->{'attribute'}
          ->set_sub_values( searches => $args->{'searches'}, );
    }

    if ( $status && $args->{'name'} ) {
        ( $status, $msg ) =
          $self->{'attribute'}->set_description( $args->{'name'} )
          unless $self->name eq $args->{'name'};
    }

    if ( $status && $args->{'privacy'} ) {
        my ( $new_obj_type, $new_obj_id ) = split /-/, $args->{'privacy'};
        my ( $obj_type,     $obj_id )     = split /-/, $self->privacy;

        my $attr = $self->{'attribute'};
        if ( $new_obj_type ne $obj_type ) {
            ( $status, $msg ) = $attr->set_object_type($new_obj_type);
        }
        if ( $status && $new_obj_id != $obj_id ) {
            ( $status, $msg ) = $attr->set_object_id($new_obj_id);
        }
        $self->{'privacy'} = $args->{'privacy'} if $status;
    }

    return ( $status, $msg );
}

=head2 searches

Returns a list of loaded saved searches

=cut

sub searches {
    my $self = shift;
    return map {
        my $search = RT::SavedSearch->new( current_user => $self->current_user );
        $search->load( $_->[0], $_->[1] );
        $search
    } $self->search_ids;
}

=head2 search_ids

Returns a list of array references, each being a saved-search privacy, ID, and
description

=cut

sub search_ids {
    my $self = shift;
    return unless ref( $self->{'attribute'} ) eq 'RT::Model::Attribute';
    return @{ $self->{'attribute'}->sub_value('searches') || [] };
}

=head2 search_privacies

Returns a list of array references, each one being suitable to pass to
/Elements/ShowSearch.

=cut

sub search_privacies {
    my $self = shift;
    return map { [ $self->search_privacy(@$_) ] } $self->search_ids;
}

=head2 search_privacy TYPE, ID, DESC

Returns an array for one saved search, suitable for passing to
/Elements/ShowSearch.

=cut

sub search_privacy {
    my $self = shift;
    my ( $type, $id, $desc ) = @_;
    if ( $type eq 'RT::System' ) {
        return name =>  $desc;
    }

    return SavedSearch => join( '-', $type, 'SavedSearch', $id );
}

=head2 possible_hidden_searches

This will return a list of saved searches that are potentially not visible by
all users for whom the dashboard is visible. You may pass in a privacy to
use instead of the dashboard's privacy.

=cut

sub possible_hidden_searches {
    my $self = shift;
    my $privacy = shift || $self->privacy;

    return grep { !$_->is_visible_to($privacy) } $self->searches;
}

# _privacy_objects: returns a list of objects that can be used to load
# dashboards from. If the Modify parameter is true, then check modify rights.
# If the Create parameter is true, then check create rights. Otherwise, check
# read rights.

sub _privacy_objects {
    my $self = shift;
    my %args = @_;

    my $CurrentUser = $self->current_user;
    my @objects;

    my $prefix =
        $args{modify} ? "Modify"
      : $args{create} ? "Create"
      :                 "See";

    push @objects, $CurrentUser->user_object
      if $self->current_user->has_right(
        right  => "${prefix}OwnDashboard",
        object => RT->system_user,
      );

    my $groups = RT::Model::GroupCollection->new( current_user => $CurrentUser );
    $groups->limit_to_user_defined_groups;
    $groups->with_member(
        principal_id => $CurrentUser->id,
        recursively => 1
    );

    push @objects, grep {
        $self->current_user->has_right(
            right  => "${prefix}GroupDashboard",
            object => $_,
          )
    } @{ $groups->items_array_ref };

    push @objects, RT::System->new( current_user => $CurrentUser )
      if $CurrentUser->has_right(
        right  => "${prefix}Dashboard",
        object => RT->system_user,
      );

    return @objects;
}

# ACLs

sub _current_user_can {
    my $self    = shift;
    my $privacy = shift || $self->privacy;
    my %args    = @_;

    if ( !defined($privacy) ) {
        Jifty->log->debug("No privacy provided to $self->_current_user_can");
        return 0;
    }

    my $object = $self->_get_object($privacy);
    return 0 unless $object;

    my $level;

    if    ( $object->isa('RT::Model::User') )   { $level = 'Own' }
    elsif ( $object->isa('RT::Model::Group') )  { $level = 'Group' }
    elsif ( $object->isa('RT::System') ) { $level = '' }
    else {
        Jifty->log->error("Unknown object $object from privacy $privacy");
        return 0;
    }

    # users are mildly special-cased, since we actually have to check that
    # the user is operating on himself
    if ( $object->isa('RT::Model::User') ) {
        return 0 unless $object->id == $self->current_user->id;
    }

    my $right = $args{full_right}
      || join( '', $args{right}, $level, 'Dashboard' );

    # all rights, except group rights, are global
    $object = RT->system_user unless $object->isa('RT::Model::Group');

    return $self->current_user->has_right(
        right  => $right,
        object => $object,
    );
}

sub current_user_can_see {
    my $self    = shift;
    my $privacy = shift;

    $self->_current_user_can( $privacy, right => 'See' );
}

sub current_user_can_create {
    my $self    = shift;
    my $privacy = shift;

    $self->_current_user_can( $privacy, right => 'Create' );
}

sub current_user_can_modify {
    my $self    = shift;
    my $privacy = shift;

    $self->_current_user_can( $privacy, right => 'Modify' );
}

sub current_user_can_delete {
    my $self    = shift;
    my $privacy = shift;

    $self->_current_user_can( $privacy, right => 'Delete' );
}

sub current_user_can_subscribe {
    my $self    = shift;
    my $privacy = shift;

    $self->_current_user_can( $privacy, full_right => 'SubscribeDashboard' );
}

1;

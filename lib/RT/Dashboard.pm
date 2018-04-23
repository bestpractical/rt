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

  RT::Dashboard - an API for saving and retrieving dashboards

=head1 SYNOPSIS

  use RT::Dashboard

=head1 DESCRIPTION

  Dashboard is an object that can belong to either an RT::User or an
  RT::Group.  It consists of an ID, a name, and a number of
  saved searches and portlets.

=head1 METHODS


=cut

package RT::Dashboard;

use strict;
use warnings;

use base qw/RT::SharedSetting/;

use RT::SavedSearch;

use RT::System;
'RT::System'->AddRight( Staff   => SubscribeDashboard => 'Subscribe to dashboards'); # loc

'RT::System'->AddRight( General => SeeDashboard       => 'View system dashboards'); # loc
'RT::System'->AddRight( Admin   => CreateDashboard    => 'Create system dashboards'); # loc
'RT::System'->AddRight( Admin   => ModifyDashboard    => 'Modify system dashboards'); # loc
'RT::System'->AddRight( Admin   => DeleteDashboard    => 'Delete system dashboards'); # loc

'RT::System'->AddRight( Staff   => SeeOwnDashboard    => 'View personal dashboards'); # loc
'RT::System'->AddRight( Staff   => CreateOwnDashboard => 'Create personal dashboards'); # loc
'RT::System'->AddRight( Staff   => ModifyOwnDashboard => 'Modify personal dashboards'); # loc
'RT::System'->AddRight( Staff   => DeleteOwnDashboard => 'Delete personal dashboards'); # loc


=head2 ObjectName

An object of this class is called "dashboard"

=cut

sub ObjectName { "dashboard" } # loc

sub SaveAttribute {
    my $self   = shift;
    my $object = shift;
    my $args   = shift;

    return $object->AddAttribute(
        'Name'        => 'Dashboard',
        'Description' => $args->{'Name'},
        'Content'     => {Panes => $args->{'Panes'}},
    );
}

sub UpdateAttribute {
    my $self = shift;
    my $args = shift;

    my ($status, $msg) = (1, undef);
    if (defined $args->{'Panes'}) {
        ($status, $msg) = $self->{'Attribute'}->SetSubValues(
            Panes => $args->{'Panes'},
        );
    }

    if ($status && $args->{'Name'}) {
        ($status, $msg) = $self->{'Attribute'}->SetDescription($args->{'Name'})
            unless $self->Name eq $args->{'Name'};
    }

    if ($status && $args->{'Privacy'}) {
        my ($new_obj_type, $new_obj_id) = split /-/, $args->{'Privacy'};
        my ($obj_type, $obj_id) = split /-/, $self->Privacy;

        my $attr = $self->{'Attribute'};
        if ($new_obj_type ne $obj_type) {
            ($status, $msg) = $attr->SetObjectType($new_obj_type);
        }
        if ($status && $new_obj_id != $obj_id ) {
            ($status, $msg) = $attr->SetObjectId($new_obj_id);
        }
        $self->{'Privacy'} = $args->{'Privacy'} if $status;
    }

    return ($status, $msg);
}

=head2 PostLoadValidate

Ensure that the ID corresponds to an actual dashboard object, since it's all
attributes under the hood.

=cut

sub PostLoadValidate {
    my $self = shift;
    return (0, "Invalid object type") unless $self->{'Attribute'}->Name eq 'Dashboard';
    return 1;
}

=head2 Panes

Returns a hashref of pane name to portlets

=cut

sub Panes {
    my $self = shift;
    return unless ref($self->{'Attribute'}) eq 'RT::Attribute';
    return $self->{'Attribute'}->SubValue('Panes') || {};
}

=head2 Portlets

Returns the list of this dashboard's portlets, each a hashref with key
C<portlet_type> being C<search> or C<component>.

=cut

sub Portlets {
    my $self = shift;
    return map { @$_ } values %{ $self->Panes };
}

=head2 Dashboards

Returns a list of loaded sub-dashboards

=cut

sub Dashboards {
    my $self = shift;
    return map {
        my $search = RT::Dashboard->new($self->CurrentUser);
        $search->LoadById($_->{id});
        $search
    } grep { $_->{portlet_type} eq 'dashboard' } $self->Portlets;
}

=head2 Searches

Returns a list of loaded saved searches

=cut

sub Searches {
    my $self = shift;
    return map {
        my $search = RT::SavedSearch->new($self->CurrentUser);
        $search->Load($_->{privacy}, $_->{id});
        $search
    } grep { $_->{portlet_type} eq 'search' } $self->Portlets;
}

=head2 ShowSearchName Portlet

Returns an array for one saved search, suitable for passing to
/Elements/ShowSearch.

=cut

sub ShowSearchName {
    my $self = shift;
    my $portlet = shift;

    if ($portlet->{privacy} eq 'RT::System') {
        return Name => $portlet->{description};
    }

    return SavedSearch => join('-', $portlet->{privacy}, 'SavedSearch', $portlet->{id});
}

=head2 PossibleHiddenSearches

This will return a list of saved searches that are potentially not visible by
all users for whom the dashboard is visible. You may pass in a privacy to
use instead of the dashboard's privacy.

=cut

sub PossibleHiddenSearches {
    my $self = shift;
    my $privacy = shift || $self->Privacy;

    return grep { !$_->IsVisibleTo($privacy) } $self->Searches, $self->Dashboards;
}

# _PrivacyObjects: returns a list of objects that can be used to load
# dashboards from. You probably want to use the wrapper methods like
# ObjectsForLoading, ObjectsForCreating, etc.

sub _PrivacyObjects {
    my $self = shift;

    my @objects;

    my $CurrentUser = $self->CurrentUser;
    push @objects, $CurrentUser->UserObj;

    my $groups = RT::Groups->new($CurrentUser);
    $groups->LimitToUserDefinedGroups;
    $groups->WithCurrentUser;
    push @objects, @{ $groups->ItemsArrayRef };

    push @objects, RT::System->new($CurrentUser);

    return @objects;
}

# ACLs

sub _CurrentUserCan {
    my $self    = shift;
    my $privacy = shift || $self->Privacy;
    my %args    = @_;

    if (!defined($privacy)) {
        $RT::Logger->debug("No privacy provided to $self->_CurrentUserCan");
        return 0;
    }

    my $object = $self->_GetObject($privacy);
    return 0 unless $object;

    my $level;

       if ($object->isa('RT::User'))   { $level = 'Own' }
    elsif ($object->isa('RT::Group'))  { $level = 'Group' }
    elsif ($object->isa('RT::System')) { $level = '' }
    else {
        $RT::Logger->error("Unknown object $object from privacy $privacy");
        return 0;
    }

    # users are mildly special-cased, since we actually have to check that
    # the user is operating on himself
    if ($object->isa('RT::User')) {
        return 0 unless $object->Id == $self->CurrentUser->Id;
    }

    my $right = $args{FullRight}
             || join('', $args{Right}, $level, 'Dashboard');

    # all rights, except group rights, are global
    $object = $RT::System unless $object->isa('RT::Group');

    return $self->CurrentUser->HasRight(
        Right  => $right,
        Object => $object,
    );
}

sub CurrentUserCanSee {
    my $self    = shift;
    my $privacy = shift;

    $self->_CurrentUserCan($privacy, Right => 'See');
}

sub CurrentUserCanCreate {
    my $self    = shift;
    my $privacy = shift;

    $self->_CurrentUserCan($privacy, Right => 'Create');
}

sub CurrentUserCanModify {
    my $self    = shift;
    my $privacy = shift;

    $self->_CurrentUserCan($privacy, Right => 'Modify');
}

sub CurrentUserCanDelete {
    my $self    = shift;
    my $privacy = shift;

    $self->_CurrentUserCan($privacy, Right => 'Delete');
}

sub CurrentUserCanSubscribe {
    my $self    = shift;
    my $privacy = shift;

    $self->_CurrentUserCan($privacy, FullRight => 'SubscribeDashboard');
}

=head2 Subscription

Returns the L<RT::Attribute> representing the current user's subscription
to this dashboard if there is one; otherwise, returns C<undef>.

=cut

sub Subscription {
    my $self = shift;

    # no subscription to unloaded dashboards
    return unless $self->id;

    for my $sub ($self->CurrentUser->UserObj->Attributes->Named('Subscription')) {
        return $sub if $sub->SubValue('DashboardId') == $self->id;
    }

    return;
}

sub ObjectsForLoading {
    my $self = shift;
    my %args = (
        IncludeSuperuserGroups => 1,
        @_
    );
    my @objects;

    # If you've been granted the SeeOwnDashboard global right (which you
    # could have by way of global user right or global group right), you
    # get to see your own dashboards
    my $CurrentUser = $self->CurrentUser;
    push @objects, $CurrentUser->UserObj
        if $CurrentUser->HasRight(Object => $RT::System, Right => 'SeeOwnDashboard');

    # Find groups for which: (a) you are a member of the group, and (b)
    # you have been granted SeeGroupDashboard on (by any means), and (c)
    # have at least one dashboard
    my $groups = RT::Groups->new($CurrentUser);
    $groups->LimitToUserDefinedGroups;
    $groups->ForWhichCurrentUserHasRight(
        Right             => 'SeeGroupDashboard',
        IncludeSuperusers => $args{IncludeSuperuserGroups},
    );
    $groups->WithCurrentUser;
    my $attrs = $groups->Join(
        ALIAS1 => 'main',
        FIELD1 => 'id',
        TABLE2 => 'Attributes',
        FIELD2 => 'ObjectId',
    );
    $groups->Limit(
        ALIAS => $attrs,
        FIELD => 'ObjectType',
        VALUE => 'RT::Group',
    );
    $groups->Limit(
        ALIAS => $attrs,
        FIELD => 'Name',
        VALUE => 'Dashboard',
    );
    push @objects, @{ $groups->ItemsArrayRef };

    # Finally, if you have been granted the SeeDashboard right (which
    # you could have by way of global user right or global group right),
    # you can see system dashboards.
    push @objects, RT::System->new($CurrentUser)
        if $CurrentUser->HasRight(Object => $RT::System, Right => 'SeeDashboard');

    return @objects;
}

sub CurrentUserCanCreateAny {
    my $self = shift;
    my @objects;

    my $CurrentUser = $self->CurrentUser;
    return 1
        if $CurrentUser->HasRight(Object => $RT::System, Right => 'CreateOwnDashboard');

    my $groups = RT::Groups->new($CurrentUser);
    $groups->LimitToUserDefinedGroups;
    $groups->ForWhichCurrentUserHasRight(
        Right             => 'CreateGroupDashboard',
        IncludeSuperusers => 1,
    );
    return 1 if $groups->Count;

    return 1
        if $CurrentUser->HasRight(Object => $RT::System, Right => 'CreateDashboard');

    return 0;
}

=head2 Delete

Deletes the dashboard and related subscriptions.
Returns a tuple of status and message, where status is true upon success.

=cut

sub Delete {
    my $self = shift;
    my $id = $self->id;
    my ( $status, $msg ) = $self->SUPER::Delete(@_);
    if ( $status ) {
        # delete all the subscriptions
        my $subscriptions = RT::Attributes->new( RT->SystemUser );
        $subscriptions->Limit(
            FIELD => 'Name',
            VALUE => 'Subscription',
        );
        $subscriptions->Limit(
            FIELD => 'Description',
            VALUE => "Subscription to dashboard $id",
        );
        while ( my $subscription = $subscriptions->Next ) {
            $subscription->Delete();
        }
    }

    return ( $status, $msg );
}

RT::Base->_ImportOverlays();

1;

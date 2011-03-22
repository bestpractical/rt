# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2011 Best Practical Solutions, LLC
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

  RT::Dashboard - a dashboard object

=head1 SYNOPSIS

  use RT::Dashboard;

=head1 DESCRIPTION

=head1 METHODS


=cut

package RT::Dashboard;
use strict;
use warnings;

use base 'RT::Record';

use RT::SavedSearch;
use RT::System;

sub Table { 'Dashboards' }

RT::System::AddRights(
    SubscribeDashboard => 'Subscribe to dashboards', #loc_pair

    SeeDashboard       => 'View system dashboards', #loc_pair
    CreateDashboard    => 'Create system dashboards', #loc_pair
    ModifyDashboard    => 'Modify system dashboards', #loc_pair
    DeleteDashboard    => 'Delete system dashboards', #loc_pair

    SeeOwnDashboard    => 'View personal dashboards', #loc_pair
    CreateOwnDashboard => 'Create personal dashboards', #loc_pair
    ModifyOwnDashboard => 'Modify personal dashboards', #loc_pair
    DeleteOwnDashboard => 'Delete personal dashboards', #loc_pair
);

RT::System::AddRightCategories(
    SubscribeDashboard => 'Staff',

    SeeDashboard       => 'General',
    CreateDashboard    => 'Admin',
    ModifyDashboard    => 'Admin',
    DeleteDashboard    => 'Admin',

    SeeOwnDashboard    => 'Staff',
    CreateOwnDashboard => 'Staff',
    ModifyOwnDashboard => 'Staff',
    DeleteOwnDashboard => 'Staff',
);

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
    $groups->WithMember( PrincipalId => $CurrentUser->Id,
                         Recursively => 1 );
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
    my @objects;

    my $CurrentUser = $self->CurrentUser;
    push @objects, $CurrentUser->UserObj
        if $CurrentUser->HasRight(Object => $RT::System, Right => 'SeeOwnDashboard');


    my $groups = RT::Groups->new($CurrentUser);
    $groups->LimitToUserDefinedGroups;
    $groups->ForWhichCurrentUserHasRight(
        Right             => 'SeeGroupDashboard',
        IncludeSuperusers => 1,
    );
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

=head2 id

Returns the current value of id.
(In the database, id is stored as int(11).)

=head2 Name

Returns the current value of Name.
(In the database, Name is stored as varchar(255).)

=head2 SetName VALUE

Set Name to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Name will be stored as a varchar(255).)

=head2 Content

Returns the current value of Content.
(In the database, Content is stored as blob.)

=head2 SetContent VALUE

Set Content to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Content will be stored as a blob.)

=head2 ObjectType

Returns the current value of ObjectType.
(In the database, ObjectType is stored as varchar(64).)

=head2 SetObjectType VALUE

Set ObjectType to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ObjectType will be stored as a varchar(64).)

=head2 ObjectId

Returns the current value of ObjectId.
(In the database, ObjectId is stored as int(11).)

=head2 SetObjectId VALUE

Set ObjectId to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ObjectId will be stored as a int(11).)

=head2 Creator

Returns the current value of Creator.
(In the database, Creator is stored as int(11).)

=head2 Created

Returns the current value of Created.
(In the database, Created is stored as datetime.)

=head2 LastUpdatedBy

Returns the current value of LastUpdatedBy.
(In the database, LastUpdatedBy is stored as int(11).)

=head2 LastUpdated

Returns the current value of LastUpdated.
(In the database, LastUpdated is stored as datetime.)

=cut

sub _CoreAccessible {
    {
        id => {read => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        Name => {read => 1, write => 1, sql_type => 12, length => 255,  is_blob => 0,  is_numeric => 0,  type => 'varchar(255)', default => ''},
        Content => {read => 1, write => 1, sql_type => -4, length => 0,  is_blob => 1,  is_numeric => 0,  type => 'blob', default => ''},
        ObjectType => {read => 1, write => 1, sql_type => 12, length => 64,  is_blob => 0,  is_numeric => 0,  type => 'varchar(64)', default => ''},
        ObjectId => {read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        Creator => {read => 1, auto => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        Created => {read => 1, auto => 1, sql_type => 11, length => 0,  is_blob => 0,  is_numeric => 0,  type => 'datetime', default => ''},
        LastUpdatedBy => {read => 1, auto => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        LastUpdated => {read => 1, auto => 1, sql_type => 11, length => 0,  is_blob => 0,  is_numeric => 0,  type => 'datetime', default => ''},
 }
};

RT::Base->_ImportOverlays();

1;


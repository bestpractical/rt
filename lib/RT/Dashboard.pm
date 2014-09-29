# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2014 Best Practical Solutions, LLC
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

  RT::Dashboard - Dashboard

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
use Storable qw/nfreeze thaw/;
use MIME::Base64;
use Scalar::Util 'blessed';

sub Table { 'Dashboards' }

'RT::System'->AddRight( Staff   => SubscribeDashboard => 'Subscribe to dashboards'); # loc

'RT::System'->AddRight( General => SeeDashboard       => 'View system dashboards'); # loc
'RT::System'->AddRight( Admin   => CreateDashboard    => 'Create system dashboards'); # loc
'RT::System'->AddRight( Admin   => ModifyDashboard    => 'Modify system dashboards'); # loc
'RT::System'->AddRight( Admin   => DeleteDashboard    => 'Delete system dashboards'); # loc

'RT::System'->AddRight( Staff   => SeeOwnDashboard    => 'View personal dashboards'); # loc
'RT::System'->AddRight( Staff   => CreateOwnDashboard => 'Create personal dashboards'); # loc
'RT::System'->AddRight( Staff   => ModifyOwnDashboard => 'Modify personal dashboards'); # loc
'RT::System'->AddRight( Staff   => DeleteOwnDashboard => 'Delete personal dashboards'); # loc

=head2 Create

Accepts a C<Privacy> instead of an C<ObjectType> and C<ObjectId>.

=cut

sub Create {
    my $self = shift;
    my %args = ( Content => {}, @_ );


    eval  {$args{'Content'} = $self->_SerializeContent($args{'Content'}); };
    if ($@) {
        return(0, $@);
    }

    # canonicalize Privacy into ObjectType and ObjectId
    if ($args{Privacy}) {
        ($args{ObjectType}, $args{ObjectId}) = split '-', delete $args{Privacy};
    }

    my ( $ret, $msg ) = $self->SUPER::Create(%args);
    return ( $ret, $msg ) unless $ret;
    return ( $ret, $self->loc('Dashboard [_1] created',$self->id) );
}

=head2 Panes

Returns a hashref of pane name to portlets

=cut

sub Panes {
    my $self = shift;
    return $self->Content->{Panes} || {};
}

sub SetPanes {
    my $self = shift;
    my $panes = shift || {};
    return $self->SetContent({ %{$self->Content}, Panes => $panes });
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
    $groups->WithMember(
        Recursively => 1,
        PrincipalId => $CurrentUser->UserObj->PrincipalId
    );
    my $dashboards = $groups->Join(
        ALIAS1 => 'main',
        FIELD1 => 'id',
        TABLE2 => 'Dashboards',
        FIELD2 => 'ObjectId',
    );
    $groups->Limit(
        ALIAS => $dashboards,
        FIELD => 'ObjectType',
        VALUE => 'RT::Group',
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
    unless ($self->CurrentUserCanDelete) {
        return (0,$self->loc('Permission Denied'));
    }

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
        return ( $status, $self->loc('Dashboard [_1] deleted', $id) );
    }

    return ( $status, $msg );
}

sub Object {
    my $self  = shift;
    return unless $self->__Value('ObjectId');
    my $Object = $self->__Value('ObjectType')->new($self->CurrentUser);
    $Object->Load($self->__Value('ObjectId'));
    return $Object;
}

sub Content {
    my $self = shift;
    my $content = $self->_Value('Content');
    return $self->_DeserializeContent($content);
}

sub SetContent {
    my $self    = shift;
    my $content = shift;
    return $self->_Set( Field => 'Content', Value => $self->_SerializeContent( $content ) );
}


sub _SerializeContent {
    my $self = shift;
    my $content = shift;
    return encode_base64(nfreeze($content));
}

sub _DeserializeContent {
    my $self = shift;
    my $content = shift;
    return thaw(decode_base64($content));
}

sub _build_privacy {
    my $self = shift;
    my $object = shift || $self->Object;
    return undef unless $object;
    return ref($object) . '-' . $object->id;
}

sub _load_privacy_object {
    my ($self, $obj_type, $obj_id) = @_;
    if ( $obj_type eq 'RT::User' ) {
        if ( $obj_id == $self->CurrentUser->Id ) {
            return $self->CurrentUser->UserObj;
        } else {
            $RT::Logger->warning("User #". $self->CurrentUser->Id ." tried to load container user #". $obj_id);
            return undef;
        }
    }
    elsif ($obj_type eq 'RT::Group') {
        my $group = RT::Group->new($self->CurrentUser);
        $group->Load($obj_id);
        return $group;
    }
    elsif ($obj_type eq 'RT::System') {
        return RT::System->new($self->CurrentUser);
    }

    $RT::Logger->error(
        "Tried to load a ". $self->ObjectName
        ." belonging to an $obj_type, which is neither a user nor a group"
    );

    return undef;
}

sub _GetObject {
    my $self = shift;
    my $privacy = shift;

    # short circuit: if they pass the object we want anyway, just return it
    if (blessed($privacy) && $privacy->isa('RT::Record')) {
        return $privacy;
    }

    my ($obj_type, $obj_id) = split(/\-/, ($privacy || ''));

    unless ($obj_type && $obj_id) {
        $privacy = '(undef)' if !defined($privacy);
        $RT::Logger->debug("Invalid privacy string '$privacy'");
        return undef;
    }

    my $object = $self->_load_privacy_object($obj_type, $obj_id);

    unless (ref($object) eq $obj_type) {
        $RT::Logger->error("Could not load object of type $obj_type with ID $obj_id, got object of type " . (ref($object) || 'undef'));
        return undef;
    }

    # Do not allow the loading of a user object other than the current
    # user, or of a group object of which the current user is not a member.

    if ($obj_type eq 'RT::User' && $object->Id != $self->CurrentUser->UserObj->Id) {
        $RT::Logger->debug("Permission denied for user other than self");
        return undef;
    }

    if (   $obj_type eq 'RT::Group'
        && !$object->HasMemberRecursively($self->CurrentUser->PrincipalObj)
        && !$self->CurrentUser->HasRight( Object => $RT::System, Right => 'SuperUser' ) ) {
        $RT::Logger->debug("Permission denied, ".$self->CurrentUser->Name.
                           " is not a member of group");
        return undef;
    }

    return $object;
}

sub Privacy {
    my $self = shift;
    return $self->_build_privacy;
}

sub SetPrivacy {
    my $self = shift;
    my $privacy = shift;
    my ($object_type, $object_id) = split '-', $privacy, 2;
    $RT::Handle->BeginTransaction();
    if ( $self->ObjectType ne $object_type ) {
        my ($ret, $msg) = $self->SetObjectType($object_type);
        unless ( $ret ) {
            $RT::Handle->Rollback();
            return ($ret, $msg);
        }
    }

    if ( $self->ObjectId != $object_id ) {
        my ($ret, $msg) = $self->SetObjectId($object_id);
        unless ( $ret ) {
            $RT::Handle->Rollback();
            return ($ret, $msg);
        }
    }
    $RT::Handle->Commit();
    return( 1, 'Privacy updated' ); # loc
}

sub IsVisibleTo {
    my $self    = shift;
    my $to      = shift;
    my $privacy = $self->Privacy || '';

    # if the privacies are the same, then they can be seen. this handles
    # a personal setting being visible to that user.
    return 1 if $privacy eq $to;

    # If the setting is systemwide, then any user can see it.
    return 1 if $privacy =~ /^RT::System/;

    # Only privacies that are RT::System can be seen by everyone.
    return 0 if $to =~ /^RT::System/;

    # If the setting is group-wide...
    if ($privacy =~ /^RT::Group-(\d+)$/) {
        my $setting_group = RT::Group->new($self->CurrentUser);
        $setting_group->Load($1);

        if ($to =~ /-(\d+)$/) {
            my $to_id = $1;

            # then any principal that is a member of the setting's group can see
            # the setting
            return $setting_group->HasMemberRecursively($to_id);
        }
    }

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

# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2024 Best Practical Solutions, LLC
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

  RT::Dashboard - an RT Dashboard object

=head1 SYNOPSIS

  use RT::Dashboard

=head1 DESCRIPTION

An RT Dashboard object.

=head1 METHODS


=cut

package RT::Dashboard;

use strict;
use warnings;

use base 'RT::Record';
use Role::Basic 'with';
with
    "RT::Record::Role::ObjectContent" => { -rename   => { SetContent => '_SetContent' } },
    "RT::Record::Role::Principal"     => { -excludes => [qw/SavedSearches Dashboards/] };

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

=head2 Create PARAMHASH

Create takes a hash of values and creates a row in the database.  Available
keys are:

=over 4

=item Name

=item Description

=item PrincipalId

=item Content

=back

Returns a tuple of (status, msg) on failure and (id, msg) on success.

=cut

sub Create {
    my $self = shift;
    my %args = (
        Name               => '',
        Description        => '',
        PrincipalId        => $self->CurrentUser->Id,
        Content            => '',
        RecordTransaction  => 1,
        SyncLinks          => 1,
        @_,
    );

    # Check ACL
    return ( 0, $self->loc('Permission Denied') ) unless $self->CurrentUser->Id == RT->System->Id || grep { $args{PrincipalId} == $_->Id } $self->ObjectsForCreating;

    my ( $ret, $msg ) = $self->ValidateName( $args{'Name'}, map { $_ => $args{$_} } qw/PrincipalId/ );
    return ( $ret, $msg ) unless $ret;

    $args{Description} ||= $args{Name};

    my %attrs = map { $_ => 1 } $self->ReadableAttributes;

    $RT::Handle->BeginTransaction;

    ( $ret, $msg ) = $self->SUPER::Create( map { $_ => $args{$_} } grep exists $args{$_}, keys %attrs );

    if (!$ret) {
        $RT::Handle->Rollback();
        return ( $ret, $self->loc( 'Dashboard could not be created: [_1]', $msg ) );
    }

    if ( $args{Content} ) {
        my ( $ret, $msg ) = $self->SetContent( $args{Content}, RecordTransaction => 0, SyncLinks => $args{SyncLinks} );
        if (!$ret) {
            $RT::Handle->Rollback();
            return ( $ret, $self->loc( 'Dashboard could not be created: [_1]', $msg ) );
        }
    }

    if ( $args{'RecordTransaction'} ) {
        $self->_NewTransaction( Type => "Create" );
    }

    $RT::Handle->Commit;
    return ( $self->Id, $self->loc("Dashboard created") );
}

=head2 ValidateName

Name must be unique for each principal.

Returns either (0, "failure reason") or 1 depending on whether the given
name is valid.

=cut

sub ValidateName {
    my $self = shift;
    my $name = shift;
    my %args = @_;

    return ( 0, $self->loc('Name is required') ) unless defined $name && length $name;

    my $Temp = RT::Dashboard->new( RT->SystemUser );
    $Temp->LoadByCols(
        Name     => $name,
        map { $_ => $args{$_} || $self->__Value($_) } qw/PrincipalId/,
    );

    if ( $Temp->id && ( !$self->id || $Temp->id != $self->id ) ) {
        return ( 0, $self->loc('Name in use') );
    }
    else {
        return 1;
    }
}

sub SetName {
    my $self  = shift;
    my $value = shift;

    my ( $val, $message ) = $self->ValidateName($value);
    if ($val) {
        return $self->_Set( Field => 'Name', Value => $value );
    }
    else {
        return ( 0, $message );
    }
}

=head2 Portlets

Returns the list of this dashboard's portlets, each a hashref with key
C<portlet_type> being C<search> or C<component>.

=cut

sub Portlets {
    my $self     = shift;
    my $elements = shift || ( $self->Content || {} )->{Elements};
    my @widgets;
    for my $element (@$elements) {
        if ( ref $element && $element->{Elements} ) {
            if ( ref $element && ref $element->{Elements}[0] eq 'ARRAY' ) {
                for my $list ( @{ $element->{Elements} } ) {
                    push @widgets, @$list;
                }
            }
            else {
                push @widgets, @{ $element->{Elements} };
            }
        }
        else {
            push @widgets, $element;
        }
    }
    return @widgets;
}

=head2 Dashboards

Returns a list of loaded sub-dashboards

=cut

sub Dashboards {
    my $self = shift;
    return map {
        my $dashboard = RT::Dashboard->new($self->CurrentUser);
        $dashboard->LoadById($_->{id});
        $dashboard
    } grep { $_->{portlet_type} eq 'dashboard' } $self->Portlets;
}

=head2 SavedSearches

Returns a list of loaded saved searches

=cut

sub SavedSearches {
    my $self = shift;
    return map {
        my $search = RT::SavedSearch->new( $self->CurrentUser );
        $search->Load( $_->{id} );
        $search
    } grep { $_->{portlet_type} eq 'search' } $self->Portlets;
}

*Searches = \&SavedSearches;

=head2 PossibleHiddenSearches

This will return a list of saved searches that are potentially not visible by
all users for whom the dashboard is visible. You may pass in a privacy to
use instead of the dashboard's privacy.

=cut

sub PossibleHiddenSearches {
    my $self = shift;
    my $principal_id = shift || $self->PrincipalId;

    return grep { !$_->IsVisibleTo($principal_id) } $self->Searches, $self->Dashboards;
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

sub _Set {
    my $self = shift;
    my %args = (
        Field => undef,
        Value => undef,
        @_
    );

    return (0, $self->loc("Permission Denied")) unless $self->CurrentUserCanModify;

    return $self->SUPER::_Set(@_);
}

sub _CurrentUserCan {
    my $self   = shift;

    return 1 if $self->CurrentUser->Id == RT->System->Id;

    my $object = @_ % 2 ? shift : $self->PrincipalObj->Object;
    if ( !$object ) {
        RT->Logger->warning("Invalid object");
        return 0;
    }

    my %args = @_;
    return 1 if $self->IsSelfService && ( $args{FullRight} || $args{Right} || '' ) =~ /^See/;

    # PrincipalObj->Object is also an RT::User for RT::System principal, let's make it more distinctive here.
    $object = RT->System if $object->Id == RT->System->Id;

    # users can not see other users' user-level dashboards
    if ( $object->isa('RT::User') && $object->Id != $self->CurrentUser->Id ) {
        $RT::Logger->warning("User #". $self->CurrentUser->Id ." tried to load container user #". $object->id);
        return 0;
    }

    # only group members can get the group's saved searches
    if ( $object->isa('RT::Group') && !$object->HasMemberRecursively($self->CurrentUser->Id) ) {
        return 0;
    }

    my $right;
    if ( $args{FullRight} ) {
        $right = $args{FullRight};
    }
    else {
        my $level;
        if    ( $object->isa('RT::User') )   { $level = 'Own' }
        elsif ( $object->isa('RT::Group') )  { $level = 'Group' }
        elsif ( $object->isa('RT::System') ) { $level = '' }
        else {
            $RT::Logger->error("Unknown object $object");
            return 0;
        }
        $right = join '', $args{Right}, $level, 'Dashboard';
    }

    # all rights, except group rights, are global
    $object = $RT::System unless $object->isa('RT::Group');

    return $self->CurrentUser->HasRight(
        Right  => $right,
        Object => $object,
    );
}

sub CurrentUserCanSee {
    my $self   = shift;
    my $object = shift;

    # If $object is not an object, it's called by _Value with a field name
    $self->_CurrentUserCan( ref $object ? $object : (), Right => 'See' );
}

sub CurrentUserCanCreate {
    my $self   = shift;
    my $object = shift;

    $self->_CurrentUserCan( $object || (), Right => 'Create' );
}

sub CurrentUserCanModify {
    my $self   = shift;
    my $object = shift;

    $self->_CurrentUserCan( $object || (), Right => 'Modify' );
}

sub CurrentUserCanDelete {
    my $self   = shift;
    my $object = shift;

    my $can = $self->_CurrentUserCan( $object || (), Right => 'Delete' );

    # Don't allow to delete system default dashboard
    if ($can) {
        my $dashboards = RT::System->new( RT->SystemUser )->Attributes;
        $dashboards->Limit( FIELD => 'Name', OPERATOR => 'ENDSWITH', VALUE => 'DefaultDashboard' );
        $dashboards->Limit( FIELD => 'Content', VALUE => $self->Id );
        return 0 if $dashboards->First;
    }

    return $can;
}

sub CurrentUserCanSubscribe {
    my $self    = shift;
    my $object  = shift;

    $self->_CurrentUserCan( $object || (), FullRight => 'SubscribeDashboard' );
}

=head2 Subscription

Returns the L<RT::Attribute> representing the current user's subscription
to this dashboard if there is one; otherwise, returns C<undef>.

=cut

sub Subscription {
    my $self = shift;

    # no subscription to unloaded dashboards
    return unless $self->id;

    my $subscription = RT::DashboardSubscription->new( $self->CurrentUser );
    $subscription->LoadByCols( DashboardId => $self->Id, UserId => $self->CurrentUser->Id );

    return $subscription->Id ? $subscription : undef;
}

=head2 ObjectsForLoading

Returns a list of objects that can be used to load this dashboard. It
is ACL checked.

=cut

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
    my $dashboards = $groups->Join(
        ALIAS1 => 'main',
        FIELD1 => 'id',
        TABLE2 => 'Dashboards',
        FIELD2 => 'PrincipalId',
    );
    push @objects, @{ $groups->ItemsArrayRef };

    # Finally, if you have been granted the SeeDashboard right (which
    # you could have by way of global user right or global group right),
    # you can see system dashboards.
    push @objects, RT::System->new($CurrentUser)
        if $CurrentUser->HasRight(Object => $RT::System, Right => 'SeeDashboard');

    return @objects;
}

=head2 ObjectsForCreating

Returns a list of objects that can be used to create this dashboard. It
is ACL checked.

=cut

sub ObjectsForCreating {
    my $self = shift;
    return grep { $self->CurrentUserCanCreate($_) } $self->_PrivacyObjects;
}

=head2 ObjectsForModifying

Returns a list of objects that can be used to modify this dashboard. It
is ACL checked.

=cut

sub ObjectsForModifying {
    my $self = shift;
    return grep { $self->CurrentUserCanModify($_) } $self->_PrivacyObjects;
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

Disable the dashboard.
Returns a tuple of status and message, where status is true upon success.

=cut

sub Delete {
    my $self = shift;
    return (0, $self->loc("Permission Denied")) unless $self->CurrentUserCanDelete;
    my ($ret) = $self->SetDisabled(1);
    return wantarray ? ( $ret, $self->loc('Dashboard disabled') ) : $ret;
}

=head2 IsVisibleTo PrincipalId

Returns true if it is visible to the principal.
This does not deal with ACLs, this only looks at membership.

=cut

sub IsVisibleTo {
    my $self    = shift;
    my $to      = shift;
    my $from = $self->PrincipalId || '';

    # if the principals are the same, then they can be seen. this handles
    # a personal setting being visible to that user.
    return 1 if $from == $to;

    # If the saved search is systemwide, then any user can see it.
    return 1 if $from == RT->System->Id;

    # Only systemwide saved searches can be seen by everyone.
    return 0 if $to == RT->System->Id;

    # If the setting is group-wide...
    my $principal_obj = $self->PrincipalObj;
    return 1 if $principal_obj->IsGroup && $principal_obj->Object->HasMemberRecursively($to);

    return 0;
}

sub SetContent {
    my $self    = shift;
    my $content = shift;
    my ( $ret, $msg ) = $self->_SetContent($content, @_);

    my %args = ( SyncLinks => 1, @_ );
    if ( $ret && $args{SyncLinks} ) {
        my %searches = map { $_->{id} => 1 } grep { $_->{portlet_type} eq 'search' } $self->Portlets;

        my $links = $self->DependsOn;
        $links->Limit( FIELD => 'Target', OPERATOR => 'STARTSWITH', VALUE => 'savedsearch:' );
        while ( my $link = $links->Next ) {
            next if delete $searches{ $link->TargetObj->id };
            my ( $ret, $msg ) = $link->Delete;
            if ( !$ret ) {
                RT->Logger->error( "Couldn't delete link #" . $link->id . ": $msg" );
            }
        }

        for my $id ( keys %searches ) {
            my $link   = RT::Link->new( $self->CurrentUser );
            my $search = RT::SavedSearch->new( $self->CurrentUser );
            $search->Load($id);
            if ( $search->id ) {
                my ( $ret, $msg ) = $link->Create(
                    Type   => 'DependsOn',
                    Base   => 'dashboard:' . $self->id,
                    Target => "savedsearch:$id"
                );
                if ( !$ret ) {
                    RT->Logger->error( "Couldn't create link for dashboard #:" . $self->id . ": $msg" );
                }
            }
        }
    }
    return wantarray ? ( $ret, $msg ) : $ret;
}

sub FindDependencies {
    my $self = shift;
    my ( $walker, $deps ) = @_;

    $self->SUPER::FindDependencies( $walker, $deps );
    $deps->Add( out => $self->PrincipalObj );

    for my $component ( $self->Portlets ) {
        if ( $component->{portlet_type} eq 'search' ) {
            my $search = RT::SavedSearch->new( $self->CurrentUser );
            $search->LoadById( $component->{id} );
            $deps->Add( out => $search );
        }
        elsif ( $component->{portlet_type} eq 'dashboard' ) {
            my $dashboard = RT::Dashboard->new( $self->CurrentUser );
            $dashboard->LoadById( $component->{id} );
            $deps->Add( out => $dashboard );
        }
    }

    # Subscriptions
    my $subscriptions = RT::DashboardSubscriptions->new( $self->CurrentUser );
    $subscriptions->FindAllRows;
    $subscriptions->Limit( FIELD => 'DashboardId', VALUE => $self->Id );
    $deps->Add( in => $subscriptions );

    # Links
    my $links = RT::Links->new( $self->CurrentUser );
    $links->Limit(
        SUBCLAUSE       => "either",
        FIELD           => $_,
        VALUE           => $self->URI,
        ENTRYAGGREGATOR => 'OR',
    ) for qw/Base Target/;
    $deps->Add( in => $links );
}

=head2 URI

Returns this dashboard's URI

=cut

sub URI {
    my $self = shift;
    require RT::URI::dashboard;
    my $uri  = RT::URI::dashboard->new( $self->CurrentUser );
    return $uri->URIForObject($self);
}

=head2 IsSelfService

Returns true if this dashboard is for selfservice, 0 otherwise.

=cut

sub IsSelfService {
    my $self = shift;
    return ( $self->__Value('Name') // '' ) eq 'SelfService' ? 1 : 0;
}

sub __DependsOn {
    my $self = shift;
    my %args = (
        Shredder     => undef,
        Dependencies => undef,
        @_,
    );
    my $deps = $args{'Dependencies'};
    my $list = [];

    # subscriptions
    my $objs = RT::DashboardSubscriptions->new( $self->CurrentUser );
    $objs->FindAllRows;
    $objs->Limit( FIELD => 'DashboardId', VALUE => $self->Id );
    push @$list, $objs;

    $deps->_PushDependencies(
        BaseObject    => $self,
        Flags         => RT::Shredder::Constants::DEPENDS_ON,
        TargetObjects => $list,
        Shredder      => $args{'Shredder'}
    );
    return $self->SUPER::__DependsOn(%args);
}

sub Table { "Dashboards" }

sub _CoreAccessible {
    {
        id            => { read => 1, type => 'int(11)', default => '' },
        Name          => { read => 1, write => 1, sql_type => 12, length => 255, is_blob => 0,  is_numeric => 0,  type => 'varchar(255)', default => '' },
        Description   => { read => 1, write => 1, sql_type => 12, length => 255, is_blob => 0,  is_numeric => 0,  type => 'varchar(255)', default => '' },
        PrincipalId   => { read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '' },
        Creator       => { read => 1, type => 'int(11)', default => '0', auto => 1 },
        Created       => { read => 1, type => 'datetime', default => '',  auto => 1 },
        LastUpdatedBy => { read => 1, type => 'int(11)', default => '0', auto => 1 },
        LastUpdated   => { read => 1, type => 'datetime', default => '',  auto => 1 },
        Disabled      => { read => 1, write => 1, sql_type => 5, length => 6, is_blob => 0, is_numeric => 1, type => 'smallint(6)', default => '0' },
    }
}

RT::Base->_ImportOverlays();

1;

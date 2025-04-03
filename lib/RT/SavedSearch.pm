# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2025 Best Practical Solutions, LLC
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

RT::SavedSearch - an RT SavedSearch object

=head1 SYNOPSIS

  use RT::SavedSearch

=head1 DESCRIPTION

An RT SavedSearch object

=cut

package RT::SavedSearch;

use strict;
use warnings;
use 5.26.3;

use base 'RT::Record';
use Role::Basic 'with';
with "RT::Record::Role::ObjectContent", "RT::Record::Role::Principal" => { -excludes => [ qw/SavedSearches Dashboards/ ] };

=head1 NAME

RT::SavedSearch - Represents a config setting

=cut

=head1 METHODS

=head2 Create PARAMHASH

Create takes a hash of values and creates a row in the database.  Available
keys are:

=over 4

=item Name

=item Description

=item Type

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
        Type               => 'Ticket',
        PrincipalId        => $self->CurrentUser->Id,
        Content            => '',
        RecordTransaction  => 1,
        @_,
    );

    # Check ACL
    return ( 0, $self->loc('Permission Denied') )
        unless $self->CurrentUser->Id == RT->System->Id
        || grep { $args{PrincipalId} == $_->Id } $self->ObjectsForCreating;

    my ( $ret, $msg ) = $self->ValidateName( $args{'Name'}, map { $_ => $args{$_} } qw/Type PrincipalId/ );
    return ( $ret, $msg ) unless $ret;

    $args{Description} ||= $args{Name};

    my %attrs = map { $_ => 1 } $self->ReadableAttributes;

    $RT::Handle->BeginTransaction;

    ( $ret, $msg ) = $self->SUPER::Create( map { $_ => $args{$_} } grep exists $args{$_}, keys %attrs );

    if (!$ret) {
        $RT::Handle->Rollback();
        return ( $ret, $self->loc( 'Saved search could not be created: [_1]', $msg ) );
    }

    if ( $args{Content} ) {
        my ( $ret, $msg ) = $self->SetContent( $args{Content}, RecordTransaction => 0 );
        if (!$ret) {
            $RT::Handle->Rollback();
            return ( $ret, $self->loc( 'Saved search could not be created: [_1]', $msg ) );
        }
    }

    if ( $args{'RecordTransaction'} ) {
        $self->_NewTransaction( Type => "Create" );
    }

    $RT::Handle->Commit;
    return ( $self->Id, $self->loc("Saved search created") );
}

=head2 ValidateName

Name must be unique for each principal and search type.

Returns either (0, "failure reason") or 1 depending on whether the given
name is valid.

=cut

sub ValidateName {
    my $self = shift;
    my $name = shift;
    my %args = @_;

    return ( 0, $self->loc('Name is required') ) unless defined $name && length $name;

    my $Temp = RT::SavedSearch->new( RT->SystemUser );
    $Temp->LoadByCols(
        Name     => $name,
        map { $_ => $args{$_} || $self->__Value($_) } qw/Type PrincipalId/,
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


=head2 Delete

Disable object.

=cut

sub Delete {
    my $self = shift;
    return (0, $self->loc("Permission Denied")) unless $self->CurrentUserCanDelete;
    my ($ret) = $self->SetDisabled(1);
    return wantarray ? ( $ret, $self->loc('SavedSearch disabled') ) : $ret;
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

=head2 _Value

Checks L</CurrentUserCanSee> before calling C<SUPER::_Value>.

=cut

sub _Value {
    my $self = shift;
    return unless $self->CurrentUserCanSee(@_);
    return $self->SUPER::_Value(@_);
}

=head2 EscapeDescription STRING

Returns C<STRING> with all square brackets except those in C<[_1]> escaped,
ready for passing as the first argument to C<loc()>.

=cut

sub EscapeDescription {
    my $self = shift;
    my $desc = shift;
    if ($desc) {
        # We only use [_1] in saved search descriptions, so let's escape other "["
        # and "]" unless they are escaped already.
        $desc =~ s/(?<!~)\[(?!_1\])/~[/g;
        $desc =~ s/(?<!~)(?<!\[_1)\]/~]/g;
    }
    return $desc;
}


### Internal methods

# _PrivacyObjects: returns a list of objects that can be used to load, create,
# etc. saved searches from. You probably want to use the wrapper methods like
# ObjectsForLoading, ObjectsForCreating, etc.

sub _PrivacyObjects {
    my $self        = shift;
    my $CurrentUser = $self->CurrentUser;

    my $groups = RT::Groups->new($CurrentUser);
    $groups->LimitToUserDefinedGroups;
    $groups->WithCurrentUser;

    return ( $CurrentUser->UserObj, @{ $groups->ItemsArrayRef() }, RT->System );
}

sub ObjectsForLoading {
    my $self = shift;
    return grep { $self->CurrentUserCanSee($_) } $self->_PrivacyObjects;
}

sub ObjectsForCreating {
    my $self = shift;
    return grep { $self->CurrentUserCanCreate($_) } $self->_PrivacyObjects;
}

=head2 ShortenerObj

Return the corresponding shortener object

=cut

sub ShortenerObj {
    my $self = shift;
    require RT::Shortener;
    my $shortener = RT::Shortener->new( $self->CurrentUser );
    $shortener->LoadOrCreate( Content => 'SavedSearchId=' . $self->Id, Permanent => 1 );
    return $shortener;
}

sub Table { "SavedSearches" }

sub _CoreAccessible {
    {
        id            => { read => 1, type => 'int(11)', default => '' },
        Name          => { read => 1, write => 1, sql_type => 12, length => 255, is_blob => 0, is_numeric => 0, type => 'varchar(255)', default => '' },
        Description   => { read => 1, write => 1, sql_type => 12, length => 255, is_blob => 0, is_numeric => 0, type => 'varchar(255)', default => '' },
        Type          => { read => 1, write => 1, sql_type => 12, length => 64,  is_blob => 0,  is_numeric => 0,  type => 'varchar(64)', default => '' },
        PrincipalId   => { read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '' },
        Creator       => { read => 1, type => 'int(11)', default => '0', auto => 1 },
        Created       => { read => 1, type => 'datetime', default => '', auto => 1 },
        LastUpdatedBy => { read => 1, type => 'int(11)', default => '0', auto => 1 },
        LastUpdated   => { read => 1, type => 'datetime', default => '', auto => 1 },
        Disabled      => { read => 1, write => 1, sql_type => 5, length => 6, is_blob => 0, is_numeric => 1, type => 'smallint(6)', default => '0' },
    }
}

# ACLs

sub _CurrentUserCan {
    my $self = shift;

    return 1 if $self->CurrentUser->HasRight( Right => 'SuperUser', Object => RT->System );

    my $object = @_ % 2 ? shift : $self->PrincipalObj->Object;
    if ( !$object ) {
        RT->Logger->warning("Invalid object");
        return 0;
    }

    # PrincipalObj->Object is also an RT::User for RT::System, let's make it more distinctive here.
    $object = RT->System if $object->Id == RT->System->Id;

    my %args = @_;

    # users can not see other users' user-level saved searches
    if ( $object->isa('RT::User') && $object->Id != $self->CurrentUser->Id ) {
        RT->Logger->warning("Permission denied: User #". $self->CurrentUser->Id ." does not have rights to load container user #". $object->id);
        return 0;
    }

    # only group members can get the group's saved searches
    if ( $object->isa('RT::Group') && !$object->HasMemberRecursively($self->CurrentUser->Id) ) {
        return 0;
    }

    my $level;
    if    ( $object->isa('RT::User') )   { $level = 'Own' }
    elsif ( $object->isa('RT::Group') )  { $level = 'Group' }
    elsif ( $object->isa('RT::System') ) { $level = '' }
    else {
        $RT::Logger->error("Unknown object $object");
        return 0;
    }
    my $right = join '', $args{Right}, $level, 'SavedSearch';

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

    $self->_CurrentUserCan( $object || (), Right => 'Admin' );
}

*CurrentUserCanModify = *CurrentUserCanDelete = \&CurrentUserCanCreate;

sub CurrentUserCanCreateAny {
    my $self = shift;
    my @objects;

    my $CurrentUser = $self->CurrentUser;
    return 1
        if $CurrentUser->HasRight(Object => $RT::System, Right => 'AdminOwnSavedSearch');

    my $groups = RT::Groups->new($CurrentUser);
    $groups->LimitToUserDefinedGroups;
    $groups->ForWhichCurrentUserHasRight(
        Right             => 'AdminGroupSavedSearch',
        IncludeSuperusers => 1,
    );
    return 1 if $groups->Count;

    return 1
        if $CurrentUser->HasRight(Object => $RT::System, Right => 'AdminSavedSearch');

    return 0;
}

=head2 URI

Returns this saved search's URI

=cut

sub URI {
    my $self = shift;
    require RT::URI::savedsearch;
    my $uri  = RT::URI::savedsearch->new( $self->CurrentUser );
    return $uri->URIForObject($self);
}

sub FindDependencies {
    my $self = shift;
    my ( $walker, $deps ) = @_;

    $self->SUPER::FindDependencies( $walker, $deps );
    $deps->Add( out => $self->PrincipalObj );
}

=head2 URI

Returns this saved search's corresponding collection Class like C<RT::Tickets>

=cut

sub Class {
    my $self  = shift;
    state $class = {
        Ticket                 => 'RT::Tickets',
        Asset                  => 'RT::Assets',
        TicketTransaction      => 'RT::Transactions',
        TicketChart            => 'RT::Tickets',
        AssetChart             => 'RT::Assets',
        TicketTransactionChart => 'RT::Transactions',
    };
    return $class->{ $self->Type };
}

RT::Base->_ImportOverlays();

1;

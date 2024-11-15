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

  RT::DashboardSubscription - an RT DashboardSubscription object

=head1 SYNOPSIS

  use RT::DashboardSubscription

=head1 DESCRIPTION

An RT DashboardSubscription object.

=head1 METHODS


=cut

package RT::DashboardSubscription;

use strict;
use warnings;

use base 'RT::Record';
use Role::Basic 'with';
with "RT::Record::Role::ObjectContent";

=head2 Create PARAMHASH

Create takes a hash of values and creates a row in the database.  Available
keys are:

=over 4

=item UserId

=item DashboardId

=item Content

=back

Returns a tuple of (status, msg) on failure and (id, msg) on success.

=cut

sub Create {
    my $self = shift;
    my %args = (
        UserId            => $self->CurrentUser->Id,
        DashboardId       => undef,
        Content           => '',
        RecordTransaction => 1,
        @_,
    );

    my $dashboard = RT::Dashboard->new( $self->CurrentUser );
    $dashboard->Load($args{DashboardId});
    return ( 0, $self->loc( 'Dashboard [_1] not found', $args{DashboardId} ) ) unless $dashboard->Id;
    return ( 0, $self->loc('Permission Denied') )
        unless $dashboard->CurrentUserCanSee && $dashboard->CurrentUserCanSubscribe;

    return ( 0, $self->loc('Permission Denied') )
        unless $self->CurrentUser->HasRight( Right => 'SuperUser', Object => RT->System )
        || $args{UserId} == $self->CurrentUser->Id;

    my %attrs = map { $_ => 1 } $self->ReadableAttributes;

    $RT::Handle->BeginTransaction;

    my ( $ret, $msg ) = $self->SUPER::Create( map { $_ => $args{$_} } grep exists $args{$_}, keys %attrs );

    if (!$ret) {
        $RT::Handle->Rollback();
        return ( $ret, $self->loc( 'Dashboard subscription could not be created: [_1]', $msg ) );
    }

    if ( $args{Content} ) {
        my ( $ret, $msg ) = $self->SetContent( $args{Content}, RecordTransaction => 0 );
        if (!$ret) {
            $RT::Handle->Rollback();
            return ( $ret, $self->loc( 'Dashboard subscription could not be created: [_1]', $msg ) );
        }
    }

    if ( $args{'RecordTransaction'} ) {
        $self->_NewTransaction( Type => "Create" );
    }

    $RT::Handle->Commit;
    return ( $self->Id, $self->loc("Dashboard subscription created") );
}

sub _Set {
    my $self = shift;
    my %args = @_;

    return ( 0, $self->loc('Permission Denied') )
        unless $self->CurrentUser->HasRight( Right => 'SuperUser', Object => RT->System )
        || ( $args{UserId} == $self->CurrentUser->Id && $args{Field} !~ /^(?:UserId|DashboardId)$/ );
    return $self->SUPER::_Set(@_);
}

=head2 DashboardObj

Returns the corresponding dashboard object of current subscription.

=cut

sub DashboardObj {
    my $self = shift;
    my $dashboard = RT::Dashboard->new( $self->CurrentUser );
    $dashboard->Load( $self->DashboardId );
    return $dashboard;
}

=head2 UserObj

Returns the corresponding user object of current subscription.

=cut

sub UserObj {
    my $self = shift;
    my $user = RT::User->new( $self->CurrentUser );
    $user->Load( $self->UserId );
    return $user;
}

sub FindDependencies {
    my $self = shift;
    my ( $walker, $deps ) = @_;

    $self->SUPER::FindDependencies( $walker, $deps );
    $deps->Add( out => $self->UserObj );
    $deps->Add( out => $self->DashboardObj );
}

sub Table { "DashboardSubscriptions" }

sub _CoreAccessible {
    {
        id            => { read => 1, type => 'int(11)', default => '' },
        UserId        => { read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '' },
        DashboardId   => { read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '' },
        Creator       => { read => 1, type => 'int(11)', default => '0', auto => 1 },
        Created       => { read => 1, type => 'datetime', default => '',  auto => 1 },
        LastUpdatedBy => { read => 1, type => 'int(11)', default => '0', auto => 1 },
        LastUpdated   => { read => 1, type => 'datetime', default => '',  auto => 1 },
        Disabled      => { read => 1, write => 1, sql_type => 5, length => 6, is_blob => 0, is_numeric => 1, type => 'smallint(6)', default => '0' },
    }
}

sub CurrentUserCanSee {
    my $self = shift;
    return $self->CurrentUser->HasRight( Right => 'SuperUser', Object => RT->System )
        || ( $self->UserObj->Id == $self->CurrentUser->Id );
}

sub CurrentUserCanModify {
    my $self = shift;
    return $self->CurrentUser->HasRight( Right => 'SuperUser', Object => RT->System )
        || ( $self->UserObj->Id == $self->CurrentUser->Id );
}

RT::Base->_ImportOverlays();

1;

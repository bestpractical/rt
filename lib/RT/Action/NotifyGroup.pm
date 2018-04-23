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

RT::Action::NotifyGroup - RT Action that sends notifications to groups and/or users

=head1 DESCRIPTION

RT action module that allow you to notify particular groups and/or users.
Distribution is shipped with C<rt-email-group-admin> script that
is command line tool for managing NotifyGroup scrip actions. For more
more info see its documentation.

=cut

package RT::Action::NotifyGroup;

use strict;
use warnings;
use base qw(RT::Action::Notify);

require RT::User;
require RT::Group;

=head1 METHODS

=head2 SetRecipients

Sets the recipients of this message to Groups and/or Users.
Respects RT's NotifyActor configuration.

To send email to the selected recipients regardless of RT's NotifyActor
configuration, include AlwaysNotifyActor in the list of arguments. Or to
always suppress email to the selected recipients regardless of RT's
NotifyActor configuration, include NeverNotifyActor in the list of arguments.

=cut

sub SetRecipients {
    my $self = shift;

    my $arg = $self->Argument;
    foreach( $self->__SplitArg( $arg ) ) {
        $self->_HandleArgument( $_ );
    }

    $self->{'seen_ueas'} = {};

    return 1;
}

sub _HandleArgument {
    my $self = shift;
    my $instance = shift;

    return if $instance eq 'AlwaysNotifyActor'
           || $instance eq 'NeverNotifyActor';

    if ( $instance !~ /\D/ ) {
        my $obj = RT::Principal->new( $self->CurrentUser );
        $obj->Load( $instance );
        return $self->_HandlePrincipal( $obj );
    }

    my $group = RT::Group->new( $self->CurrentUser );
    $group->LoadUserDefinedGroup( $instance );
    # to check disabled and so on
    return $self->_HandlePrincipal( $group->PrincipalObj )
        if $group->id;

    require Email::Address;

    my $user = RT::User->new( $self->CurrentUser );
    if ( $instance =~ /^$Email::Address::addr_spec$/ ) {
        $user->LoadByEmail( $instance );
        return $self->__PushUserAddress( $instance )
            unless $user->id;
    } else {
        $user->Load( $instance );
    }
    return $self->_HandlePrincipal( $user->PrincipalObj )
        if $user->id;

    $RT::Logger->error(
        "'$instance' is not principal id, group name, user name,"
        ." user email address or any email address"
    );

    return;
}

sub _HandlePrincipal {
    my $self = shift;
    my $obj = shift;
    unless( $obj->id ) {
        $RT::Logger->error( "Couldn't load principal #$obj" );
        return;
    }
    if( $obj->Disabled ) {
        $RT::Logger->info( "Principal #$obj is disabled => skip" );
        return;
    }
    if( !$obj->PrincipalType ) {
        $RT::Logger->crit( "Principal #$obj has empty type" );
    } elsif( lc $obj->PrincipalType eq 'user' ) {
        $self->__HandleUserArgument( $obj->Object );
    } elsif( lc $obj->PrincipalType eq 'group' ) {
        $self->__HandleGroupArgument( $obj->Object );
    } else {
        $RT::Logger->info( "Principal #$obj has unsupported type" );
    }
    return;
}

sub __HandleUserArgument {
    my $self = shift;
    my $obj = shift;
    
    my $uea = $obj->EmailAddress;
    unless( $uea ) {
        $RT::Logger->warning( "User #". $obj->id ." has no email address" );
        return;
    }
    $self->__PushUserAddress( $uea );
}

sub __HandleGroupArgument {
    my $self = shift;
    my $obj = shift;

    my $members = $obj->UserMembersObj;
    while( my $m = $members->Next ) {
        $self->__HandleUserArgument( $m );
    }
}

sub __SplitArg {
    return grep length, map {s/^\s+//; s/\s+$//; $_} split /,/, $_[1];
}

sub __PushUserAddress {
    my $self = shift;
    my $uea = shift;
    push @{ $self->{'To'} }, $uea unless $self->{'seen_ueas'}{ $uea }++;
    return;
}


RT::Base->_ImportOverlays();

1;

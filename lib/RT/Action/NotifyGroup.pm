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

RT::Action::NotifyGroup - RT Action that sends notifications to groups and/or users

=head1 DESCRIPTION

RT action module that allow you to notify particular groups and/or users.
Distribution is shipped with C<rt-notify-group-admin> script that
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

=cut

sub SetRecipients {
    my $self = shift;

    my $arg = $self->Argument;

    my $old_arg = eval { Storable::thaw( $arg ) };
    unless( $@ ) {
        $arg = $self->__ConvertOldArg( $old_arg );
    }

    foreach( $self->__SplitArg( $arg ) ) {
        $self->_HandleArgument( $_ );
    }

    my $creator = $self->TransactionObj->CreatorObj->EmailAddress();
    unless( $RT::NotifyActor ) {
        @{ $self->{'To'} } = grep ( !/^\Q$creator\E$/, @{ $self->{'To'} } );
    }

    $self->{'seen_ueas'} = {};

    return 1;
}

sub _HandleArgument {
    my $self = shift;
    my $instance = shift;
    
    my $obj = RT::Principal->new( $RT::SystemUser );
    $obj->Load( $instance );
    unless( $obj->id ) {
        $RT::Logger->error( "Couldn't load principal #$instance" );
        return;
    }
    if( $obj->Disabled ) {
        $RT::Logger->info( "Principal #$instance is disabled => skip" );
        return;
    }
    if( !$obj->PrincipalType ) {
        $RT::Logger->crit( "Principal #$instance has empty type" );
    } elsif( lc $obj->PrincipalType eq 'user' ) {
        $self->__HandleUserArgument( $obj->Object );
    } elsif( lc $obj->PrincipalType eq 'group' ) {
        $self->__HandleGroupArgument( $obj->Object );
    } else {
        $RT::Logger->info( "Principal #$instance has unsupported type" );
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
    return split /[^0-9]+/, $_[1];
}

sub __ConvertOldArg {
    my $self = shift;
    my $arg = shift;
    my @res;
    foreach my $r ( @{ $arg } ) {
        my $obj;
        next unless $r->{'Type'};
        if( lc $r->{'Type'} eq 'user' ) {
            $obj = RT::User->new( $RT::SystemUser );
        } elsif ( lc $r->{'Type'} eq 'user' ) {
            $obj = RT::Group->new( $RT::SystemUser );
        } else {
            next;
        }
        $obj->Load( $r->{'Instance'} );
        my $id = $obj->id;
        next unless( $id );

        push @res, $id;
    }

    return join ';', @res;
}

sub __PushUserAddress {
    my $self = shift;
    my $uea = shift;
    push @{ $self->{'To'} }, $uea unless $self->{'seen_ueas'}{ $uea }++;
    return;
}


=head1 AUTHOR

Ruslan U. Zakirov E<lt>ruz@bestpractical.comE<gt>

L<RT::Action::NotifyGroupAsComment>, F<rt-notify-group-admin>

=cut

1;

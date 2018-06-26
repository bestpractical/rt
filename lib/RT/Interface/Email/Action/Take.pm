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

package RT::Interface::Email::Action::Take;

use strict;
use warnings;

use Role::Basic 'with';
with 'RT::Interface::Email::Role';

=head1 NAME

RT::Interface::Email::Action::Take - Take tickets via the mail gateway

=head1 SYNOPSIS

This plugin, if placed in L<RT_Config/@MailPlugins>, allows the mail
gateway to specify a take action:

    | rt-mailgate --action take-correspond --queue General --url http://localhost/

This can alternately (and more flexibly) be accomplished with a Scrip.

=cut

sub CheckACL {
    my %args = (
        Message     => undef,
        CurrentUser => undef,
        Ticket      => undef,
        Queue       => undef,
        Action      => undef,
        @_,
    );

    return unless lc $args{Action} eq "take";

    unless ( $args{Ticket}->Id ) {
        MailError(
            Subject     => "Message not recorded: $args{Subject}",
            Explanation => "Could not find a ticket with id $args{TicketId}",
            FAILURE     => 1,
        );
    }

    my $principal = $args{CurrentUser}->PrincipalObj;
    return 1 if $principal->HasRight( Object => $args{'Ticket'}, Right  => 'OwnTicket' );

    my $email = $args{CurrentUser}->UserObj->EmailAddress;
    my $qname = $args{Queue}->Name;
    my $tid   = $args{Ticket}->id;
    MailError(
        Subject     => "Permission Denied",
        Explanation => "$email has no right to own ticket $tid in queue $qname",
        FAILURE     => 1,
    );
}

sub HandleTake {
    my %args = (
        Message     => undef,
        Ticket      => undef,
        Queue       => undef,
        @_,
    );

    my $From = Encode::decode( "UTF-8", $args{Message}->head->get("From") );

    my ( $status, $msg ) = $args{'Ticket'}->SetOwner( $args{Ticket}->CurrentUser->id );
    return if $status;

    MailError(
        Subject     => "Ticket not taken",
        Explanation => $msg,
        FAILURE     => 1,
    );
}

1;


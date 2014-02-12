# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2015 Best Practical Solutions, LLC
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

package RT::Interface::Email::Auth::MailFrom;

use strict;
use warnings;

use Role::Basic 'with';
with 'RT::Interface::Email::Role';

use RT::Interface::Email;

# This is what the ordinary, non-enhanced gateway does at the moment.

sub GetCurrentUser {
    my %args = (
        Message => undef,
        @_,
    );

    # We don't need to do any external lookups
    my ( $Address, $Name, @errors ) = RT::Interface::Email::ParseSenderAddressFromHead( $args{'Message'}->head );
    $RT::Logger->warning("Failed to parse ".join(', ', @errors))
        if @errors;

    unless ( $Address ) {
        $RT::Logger->error("Couldn't parse or find sender's address");
        FAILURE("Couldn't parse or find sender's address");
    }

    my $CurrentUser = RT::CurrentUser->new;
    $CurrentUser->LoadByEmail( $Address );
    $CurrentUser->LoadByName( $Address ) unless $CurrentUser->Id;
    if ( $CurrentUser->Id ) {
        $RT::Logger->debug("Mail from user #". $CurrentUser->Id ." ($Address)" );
        return $CurrentUser;
    }


    my $user = RT::User->new( RT->SystemUser );
    $user->LoadOrCreateByEmail(
        RealName     => $Name,
        EmailAddress => $Address,
        Comments     => 'Autocreated on ticket submission',
    );

    $CurrentUser = RT::CurrentUser->new;
    $CurrentUser->Load( $user->id );

    return $CurrentUser;
}


sub CheckACL {
    my %args = (
        ErrorsTo    => undef,
        Message     => undef,
        CurrentUser => undef,
        Ticket      => undef,
        Queue       => undef,
        Action      => undef,
        @_,
    );

    my $principal = $args{CurrentUser}->PrincipalObj;
    my $email     = $args{CurrentUser}->UserObj->EmailAddress;

    my $msg;
    if ( $args{'Ticket'} && $args{'Ticket'}->Id ) {
        my $qname = $args{'Queue'}->Name;
        my $tid   = $args{'Ticket'}->id;
        # We have a ticket. that means we're commenting or corresponding
        if ( $args{'Action'} =~ /^comment$/i ) {

            # check to see whether if they can comment on the ticket
            return 1 if $principal->HasRight( Object => $args{'Ticket'}, Right => 'CommentOnTicket' );
            $msg = "$email has no right to comment on ticket $tid in queue $qname";
        }
        elsif ( $args{'Action'} =~ /^correspond$/i ) {

            # check to see whether "Everybody" or "Unprivileged users" can correspond on tickets
            return 1 if $principal->HasRight( Object => $args{'Ticket'}, Right  => 'ReplyToTicket' );
            $msg = "$email has no right to reply to ticket $tid in queue $qname";
        }
        elsif ( $args{'Action'} =~ /^take$/i ) {

            # check to see whether "Everybody" or "Unprivileged users" can correspond on tickets
            return 1 if $principal->HasRight( Object => $args{'Ticket'}, Right  => 'OwnTicket' );
            $msg = "$email has no right to own ticket $tid in queue $qname";
        }
        elsif ( $args{'Action'} =~ /^resolve$/i ) {

            # check to see whether "Everybody" or "Unprivileged users" can correspond on tickets
            return 1 if $principal->HasRight( Object => $args{'Ticket'}, Right  => 'ModifyTicket' );
            $msg = "$email has no right to resolve ticket $tid in queue $qname";
        }
        else {
            $RT::Logger->warning("Action '". ($args{'Action'}||'') ."' is unknown");
            return;
        }
    }

    # We're creating a ticket
    elsif ( $args{'Action'} =~ /^(comment|correspond)$/i ) {
        my $qname = $args{'Queue'}->Name;

        # check to see whether "Everybody" or "Unprivileged users" can create tickets in this queue
        return 1 if $principal->HasRight( Object => $args{'Queue'}, Right  => 'CreateTicket' );
        $msg = "$email has no right to create tickets in queue $qname";
    }
    else {
        $RT::Logger->warning("Action '". ($args{'Action'}||'') ."' is unknown with no ticket");
        return;
    }


    MailError(
        To          => $args{ErrorsTo},
        Subject     => "Permission Denied",
        Explanation => $msg,
        MIMEObj     => $args{Message},
    );
    FAILURE( $msg );
}

RT::Base->_ImportOverlays();

1;

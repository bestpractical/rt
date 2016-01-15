# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2016 Best Practical Solutions, LLC
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

use RT::Interface::Email qw(ParseSenderAddressFromHead CreateUser);

# This is what the ordinary, non-enhanced gateway does at the moment.

sub GetCurrentUser {
    my %args = ( Message     => undef,
                 CurrentUser => undef,
                 AuthLevel   => undef,
                 Ticket      => undef,
                 Queue       => undef,
                 Action      => undef,
                 @_ );


    # We don't need to do any external lookups
    my ( $Address, $Name, @errors ) = ParseSenderAddressFromHead( $args{'Message'}->head );
    $RT::Logger->warning("Failed to parse ".join(', ', @errors))
        if @errors;

    unless ( $Address ) {
        $RT::Logger->error("Couldn't parse or find sender's address");
        return ( $args{'CurrentUser'}, -1 );
    }

    my $CurrentUser = RT::CurrentUser->new;
    $CurrentUser->LoadByEmail( $Address );
    $CurrentUser->LoadByName( $Address ) unless $CurrentUser->Id;
    if ( $CurrentUser->Id ) {
        $RT::Logger->debug("Mail from user #". $CurrentUser->Id ." ($Address)" );
        return ( $CurrentUser, 1 );
    }

    # If the user can't be loaded, we may need to create one. Figure out the acl situation.
    my $unpriv = RT->UnprivilegedUsers();
    unless ( $unpriv->Id ) {
        $RT::Logger->crit("Couldn't find the 'Unprivileged' internal group");
        return ( $args{'CurrentUser'}, -1 );
    }

    my $everyone = RT::Group->new( RT->SystemUser );
    $everyone->LoadSystemInternalGroup('Everyone');
    unless ( $everyone->Id ) {
        $RT::Logger->crit("Couldn't find the 'Everyone' internal group");
        return ( $args{'CurrentUser'}, -1 );
    }

    $RT::Logger->debug("Going to create user with address '$Address'" );

    # but before we do that, we need to make sure that the created user would have the right
    # to do what we're doing.
    if ( $args{'Ticket'} && $args{'Ticket'}->Id ) {
        my $qname = $args{'Queue'}->Name;
        # We have a ticket. that means we're commenting or corresponding
        if ( $args{'Action'} =~ /^comment$/i ) {

            # check to see whether "Everyone" or "Unprivileged users" can comment on tickets
            unless ( $everyone->PrincipalObj->HasRight( Object => $args{'Queue'},
                                                        Right => 'CommentOnTicket' )
                     || $unpriv->PrincipalObj->HasRight( Object => $args{'Queue'},
                                                         Right => 'CommentOnTicket' ) )
            {
                $RT::Logger->debug("Unprivileged users have no right to comment on ticket in queue '$qname'");
                return ( $args{'CurrentUser'}, 0 );
            }
        }
        elsif ( $args{'Action'} =~ /^correspond$/i ) {

            # check to see whether "Everybody" or "Unprivileged users" can correspond on tickets
            unless ( $everyone->PrincipalObj->HasRight( Object => $args{'Queue'},
                                                        Right  => 'ReplyToTicket' )
                     || $unpriv->PrincipalObj->HasRight( Object => $args{'Queue'},
                                                         Right  => 'ReplyToTicket' ) )
            {
                $RT::Logger->debug("Unprivileged users have no right to reply to ticket in queue '$qname'");
                return ( $args{'CurrentUser'}, 0 );
            }
        }
        elsif ( $args{'Action'} =~ /^take$/i ) {

            # check to see whether "Everybody" or "Unprivileged users" can correspond on tickets
            unless ( $everyone->PrincipalObj->HasRight( Object => $args{'Queue'},
                                                        Right  => 'OwnTicket' )
                     || $unpriv->PrincipalObj->HasRight( Object => $args{'Queue'},
                                                         Right  => 'OwnTicket' ) )
            {
                $RT::Logger->debug("Unprivileged users have no right to own ticket in queue '$qname'");
                return ( $args{'CurrentUser'}, 0 );
            }

        }
        elsif ( $args{'Action'} =~ /^resolve$/i ) {

            # check to see whether "Everybody" or "Unprivileged users" can correspond on tickets
            unless ( $everyone->PrincipalObj->HasRight( Object => $args{'Queue'},
                                                        Right  => 'ModifyTicket' )
                     || $unpriv->PrincipalObj->HasRight( Object => $args{'Queue'},
                                                         Right  => 'ModifyTicket' ) )
            {
                $RT::Logger->debug("Unprivileged users have no right to resolve ticket in queue '$qname'");
                return ( $args{'CurrentUser'}, 0 );
            }

        }
        else {
            $RT::Logger->warning("Action '". ($args{'Action'}||'') ."' is unknown");
            return ( $args{'CurrentUser'}, 0 );
        }
    }

    # We're creating a ticket
    elsif ( $args{'Queue'} && $args{'Queue'}->Id ) {
        my $qname = $args{'Queue'}->Name;

        # check to see whether "Everybody" or "Unprivileged users" can create tickets in this queue
        unless ( $everyone->PrincipalObj->HasRight( Object => $args{'Queue'},
                                                    Right  => 'CreateTicket' )
                 || $unpriv->PrincipalObj->HasRight( Object => $args{'Queue'},
                                                     Right  => 'CreateTicket' ) )
        {
            $RT::Logger->debug("Unprivileged users have no right to create ticket in queue '$qname'");
            return ( $args{'CurrentUser'}, 0 );
        }
    }

    $CurrentUser = CreateUser( undef, $Address, $Name, $Address, $args{'Message'} );

    return ( $CurrentUser, 1 );
}

RT::Base->_ImportOverlays();

1;

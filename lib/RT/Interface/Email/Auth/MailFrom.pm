# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2007 Best Practical Solutions, LLC
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
# http://www.gnu.org/copyleft/gpl.html.
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
use RT::Interface::Email qw(parse_sender_address_from_head create_user);

# This is what the ordinary, non-enhanced gateway does at the moment.

sub get_current_user {
    my %args = (
        Message     => undef,
        CurrentUser => undef,
        AuthLevel   => undef,
        Ticket      => undef,
        queue       => undef,
        Action      => undef,
        @_
    );

    # We don't need to do any external lookups
    my ( $Address, $name )
        = parse_sender_address_from_head( $args{'Message'}->head );
    unless ($Address) {
        Jifty->log->error("Couldn't find sender's address");
        return ( $args{'CurrentUser'}, -1 );
    }

    my $CurrentUser = RT::CurrentUser->new( email => $Address );
    unless ( $CurrentUser->id ) {
        $CurrentUser = RT::CurrentUser->new( name => $Address );
    }
    if ( $CurrentUser->id ) {
        Jifty->log->debug(
            "Mail from user #" . $CurrentUser->id . " ($Address)" );
        return ( $CurrentUser, 1 );
    }

# If the user can't be loaded, we may need to create one. Figure out the acl situation.
    my $unpriv = RT::Model::Group->new( current_user => RT->system_user );
    $unpriv->load_system_internal_group('Unprivileged');
    unless ( $unpriv->id ) {
        Jifty->log->fatal("Couldn't find the 'Unprivileged' internal group");
        return ( $args{'CurrentUser'}, -1 );
    }

    my $everyone = RT::Model::Group->new( current_user => RT->system_user );
    $everyone->load_system_internal_group('Everyone');
    unless ( $everyone->id ) {
        Jifty->log->fatal("Couldn't find the 'Everyone' internal group");
        return ( $args{'CurrentUser'}, -1 );
    }

    Jifty->log->debug("Going to create user with address '$Address'");

# but before we do that, we need to make sure that the Created user would have the right
# to do what we're doing.
    if ( $args{'Ticket'} && $args{'Ticket'}->id ) {
        my $qname = $args{'queue'}->name;

        # We have a ticket. that means we're commenting or corresponding
        if ( $args{'Action'} =~ /^comment$/i ) {

# check to see whether "Everyone" or "Unprivileged users" can comment on tickets
            unless (
                $everyone->principal_object->has_right(
                    object => $args{'queue'},
                    right  => 'CommentOnTicket'
                )
                || $unpriv->principal_object->has_right(
                    object => $args{'queue'},
                    right  => 'CommentOnTicket'
                )
                )
            {
                Jifty->log->debug(
                    "Unprivileged users have no right to comment on ticket in queue '$qname'"
                );
                return ( $args{'CurrentUser'}, 0 );
            }
        } elsif ( $args{'Action'} =~ /^correspond$/i ) {

# check to see whether "Everybody" or "Unprivileged users" can correspond on tickets
            unless (
                $everyone->principal_object->has_right(
                    object => $args{'queue'},
                    right  => 'ReplyToTicket'
                )
                || $unpriv->principal_object->has_right(
                    object => $args{'queue'},
                    right  => 'ReplyToTicket'
                )
                )
            {
                Jifty->log->debug(
                    "Unprivileged users have no right to reply to ticket in queue '$qname'"
                );
                return ( $args{'CurrentUser'}, 0 );
            }
        } elsif ( $args{'Action'} =~ /^take$/i ) {

# check to see whether "Everybody" or "Unprivileged users" can correspond on tickets
            unless (
                $everyone->principal_object->has_right(
                    object => $args{'queue'},
                    right  => 'OwnTicket'
                )
                || $unpriv->principal_object->has_right(
                    object => $args{'queue'},
                    right  => 'OwnTicket'
                )
                )
            {
                Jifty->log->debug(
                    "Unprivileged users have no right to own ticket in queue '$qname'"
                );
                return ( $args{'CurrentUser'}, 0 );
            }

        } elsif ( $args{'Action'} =~ /^resolve$/i ) {

# check to see whether "Everybody" or "Unprivileged users" can correspond on tickets
            unless (
                $everyone->principal_object->has_right(
                    object => $args{'queue'},
                    right  => 'ModifyTicket'
                )
                || $unpriv->principal_object->has_right(
                    object => $args{'queue'},
                    right  => 'ModifyTicket'
                )
                )
            {
                Jifty->log->debug(
                    "Unprivileged users have no right to resolve ticket in queue '$qname'"
                );
                return ( $args{'CurrentUser'}, 0 );
            }

        } else {
            Jifty->log->warn(
                "Action '" . ( $args{'Action'} || '' ) . "' is unknown" );
            return ( $args{'CurrentUser'}, 0 );
        }
    }

    # We're creating a ticket
    elsif ( $args{'queue'} && $args{'queue'}->id ) {
        my $qname = $args{'queue'}->name;

# check to see whether "Everybody" or "Unprivileged users" can create tickets in this queue
        unless (
            $everyone->principal_object->has_right(
                object => $args{'queue'},
                right  => 'CreateTicket'
            )
            || $unpriv->principal_object->has_right(
                object => $args{'queue'},
                right  => 'ModifyTicket'
            )
            )
        {
            Jifty->log->debug(
                "Unprivileged users have no right to create ticket in queue '$qname'"
            );
            return ( $args{'CurrentUser'}, 0 );
        }
    }

    $CurrentUser
        = create_user( undef, $Address, $name, $Address, $args{'Message'} );

    return ( $CurrentUser, 1 );
}

1;

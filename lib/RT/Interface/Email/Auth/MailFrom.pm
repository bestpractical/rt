# BEGIN LICENSE BLOCK
# 
# Copyright (c) 1996-2003 Jesse Vincent <jesse@bestpractical.com>
# 
# (Except where explictly superceded by other copyright notices)
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
# Unless otherwise specified, all modifications, corrections or
# extensions to this work which alter its source code become the
# property of Best Practical Solutions, LLC when submitted for
# inclusion in the work.
# 
# 
# END LICENSE BLOCK
package RT::Interface::Email::Auth::MailFrom;
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
    my ( $Address, $Name ) = ParseSenderAddressFromHead( $args{'Message'}->head );
    my $CurrentUser = RT::CurrentUser->new();
    $CurrentUser->LoadByEmail($Address);

    unless ( $CurrentUser->Id ) {
        $CurrentUser->LoadByName($Address);
    }

    if ( $CurrentUser->Id ) {
        return ( $CurrentUser, 1 );
    }
    


    # If the user can't be loaded, we may need to create one. Figure out the acl situation.
    my $unpriv = RT::Group->new($RT::SystemUser);
    $unpriv->LoadSystemInternalGroup('Unprivileged');
    unless ( $unpriv->Id ) {
        $RT::Logger->crit( "Auth::MailFrom couldn't find the 'Unprivileged' internal group" );
        return ( $args{'CurrentUser'}, -1 );
    }

    my $everyone = RT::Group->new($RT::SystemUser);
    $everyone->LoadSystemInternalGroup('Everyone');
    unless ( $everyone->Id ) {
        $RT::Logger->crit( "Auth::MailFrom couldn't find the 'Everyone' internal group");
        return ( $args{'CurrentUser'}, -1 );
    }

    # but before we do that, we need to make sure that the created user would have the right
    # to do what we're doing.
    if ( $args{'Ticket'} && $args{'Ticket'}->Id ) {
        # We have a ticket. that means we're commenting or corresponding
        if ( $args{'Action'} =~ /^comment$/i ) {

            # check to see whether "Everybody" or "Unprivileged users" can comment on tickets
            unless ( $everyone->PrincipalObj->HasRight(
                                                      Object => $args{'Queue'},
                                                      Right => 'CommentOnTicket'
                     )
                     || $unpriv->PrincipalObj->HasRight(
                                                      Object => $args{'Queue'},
                                                      Right => 'CommentOnTicket'
                     )
              ) {
                return ( $args{'CurrentUser'}, 0 );
            }
        }
        elsif ( $args{'Action'} =~ /^correspond$/i ) {

            # check to see whether "Everybody" or "Unprivileged users" can correspond on tickets
            unless ( $everyone->PrincipalObj->HasRight(Object => $args{'Queue'},
                                                       Right  => 'ReplyToTicket'
                     )
                     || $unpriv->PrincipalObj->HasRight(
                                                       Object => $args{'Queue'},
                                                       Right  => 'ReplyToTicket'
                     )
              ) {
                return ( $args{'CurrentUser'}, 0 );
            }

        }
        else {
            return ( $args{'CurrentUser'}, 0 );
        }
    }

    # We're creating a ticket
    elsif ( $args{'Queue'} && $args{'Queue'}->Id ) {

        # check to see whether "Everybody" or "Unprivileged users" can create tickets in this queue
        unless ( $everyone->PrincipalObj->HasRight( Object => $args{'Queue'},
                                                    Right  => 'CreateTicket' )
                 || $unpriv->PrincipalObj->HasRight( Object => $args{'Queue'},
                                                     Right  => 'CreateTicket' )
          ) {
            return ( $args{'CurrentUser'}, 0 );
        }

    }

    $CurrentUser = CreateUser( undef, $Address, $Name, $args{'Message'} );

    return ( $CurrentUser, 1 );
}

eval "require RT::Interface::Email::Auth::MailFrom_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Interface/Email/Auth/MailFrom_Vendor.pm});
eval "require RT::Interface::Email::Auth::MailFrom_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Interface/Email/Auth/MailFrom_Local.pm});

1;

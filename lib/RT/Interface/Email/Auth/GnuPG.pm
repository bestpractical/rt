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
package RT::Interface::Email::Auth::GnuPG;

use strict;
use warnings;

=head2 get_current_user

To use the gnupg-secured mail gateway, you need to do the following:

Set up a GnuPG key directory with a pubring containing only the keys
you care about and specify the following in your SiteConfig.pm

    Set(%GnuPGOptions, homedir => '/opt/rt3/var/data/GnuPG');
    Set(@MailPlugins, 'Auth::MailFrom', 'Auth::GnuPG', ...other filter...);

=cut

sub apply_before_decode { return 1 }

use RT::Crypt::GnuPG;
use RT::EmailParser ();

sub get_current_user {
    my %args = (
        message         => undef,
        raw_message_ref => undef,
        @_
    );

    $args{'message'}->head->delete($_) for qw(X-RT-GnuPG-status X-RT-Incoming-Encryption
        X-RT-Incoming-Signature X-RT-Privacy);

    my $msg = $args{'message'}->dup;

    my ( $status, @res ) = verify_decrypt( entity => $args{'message'} );
    if ( $status && !@res ) {
        $args{'message'}->head->add( 'X-RT-Incoming-Encryption' => 'Not encrypted' );

        return 1;
    }

    # FIXME: Check if the message is encrypted to the address of
    # _this_ queue. send rejecting mail otherwise.

    unless ($status) {
        Jifty->log->error("Had a problem during decrypting and verifying");
        my $reject = handle_errors( message => $args{'message'}, result => \@res );
        return ( 0, 'rejected because of problems during decrypting and verifying' )
            if $reject;
    }

    # attach the original encrypted message
    $args{'message'}->attach(
        Type        => 'application/x-rt-original-message',
        Disposition => 'inline',
        Data        => ${ $args{'raw_message_ref'} },
    );

    $args{'message'}->head->add( 'X-RT-GnuPG-status' => $_->{'status'} ) foreach @res;
    $args{'message'}->head->add( 'X-RT-Privacy' => 'PGP' );

    # XXX: first entity only for now
    if (@res) {
        my $decrypted;
        my @status = RT::Crypt::GnuPG::parse_status( $res[0]->{'status'} );
        for (@status) {
            if ( $_->{operation} eq 'decrypt' && $_->{status} eq 'DONE' ) {
                $decrypted = 1;
            }
            if ( $_->{operation} eq 'verify' && $_->{status} eq 'DONE' ) {
                $args{'message'}->head->add( 'X-RT-Incoming-Signature' => $_->{user_string} );
            }
        }

        $args{'message'}->head->add(
              'X-RT-Incoming-Encryption' => $decrypted
            ? 'Success'
            : 'Not encrypted'
        );
    }

    return 1;
}

sub handle_errors {
    my %args = (
        message => undef,
        result  => [],
        @_
    );

    my $reject = 0;

    my %sent_once = ();
    foreach my $run ( @{ $args{'result'} } ) {
        my @status = RT::Crypt::GnuPG::parse_status( $run->{'status'} );
        unless ( $sent_once{'no_private_key'} ) {
            unless (
                check_no_private_key(
                    message => $args{'message'},
                    status  => \@status
                )
                )
            {
                $sent_once{'no_private_key'}++;
                $reject = 1;
            }
        }
        unless ( $sent_once{'bad_data'} ) {
            unless (
                check_bad_data(
                    message => $args{'message'},
                    status  => \@status
                )
                )
            {
                $sent_once{'bad_data'}++;
                $reject = 1;
            }
        }
    }
    return $reject;
}

sub check_no_private_key {
    my %args = ( message => undef, status => [], @_ );
    my @status = @{ $args{'status'} };

    my @decrypts = grep $_->{'operation'} eq 'decrypt', @status;
    return 1 unless @decrypts;
    foreach my $action (@decrypts) {

        # if at least one secrete key exist then it's another error
        return 1
            if grep !$_->{'user'}{'secret_key_missing'},
            @{ $action->{'encrypted_to'} };
    }

    Jifty->log->error("Couldn't decrypt a message: have no private key");

    my $address = ( RT::Interface::Email::parse_sender_address_from_head( $args{'message'}->head ) )[0];
    my ($status) = RT::Interface::Email::send_email_using_template(
        to        => $address,
        template  => 'Error: no private key',
        arguments => {
            message    => $args{'message'},
            ticket_obj => $args{'ticket'},
        },
        in_reply_to => $args{'message'},
    );
    unless ($status) {
        Jifty->log->error("Couldn't send 'Error: no private key'");
    }
    return 0;
}

sub check_bad_data {
    my %args = ( message => undef, status => [], @_ );
    my @bad_data_messages
        = map $_->{'message'},
        grep $_->{'status'} ne 'DONE' && $_->{'operation'} eq 'data',
        @{ $args{'status'} };
    return 1 unless @bad_data_messages;

    Jifty->log->error( "Couldn't process a message: " . join ', ', @bad_data_messages );

    my $address = ( RT::Interface::Email::parse_sender_address_from_head( $args{'message'}->head ) )[0];
    my ($status) = RT::Interface::Email::send_email_using_template(
        to        => $address,
        template  => 'Error: bad GnuPG data',
        arguments => {
            messages   => [@bad_data_messages],
            ticket_obj => $args{'ticket'},
        },
        in_reply_to => $args{'message'},
    );
    unless ($status) {
        Jifty->log->error("Couldn't send 'Error: bad GnuPG data'");
    }
    return 0;
}

sub verify_decrypt {
    my %args = (
        entity => undef,
        @_
    );

    my @res = RT::Crypt::GnuPG::verify_decrypt(%args);
    unless (@res) {
        Jifty->log->debug("No more encrypted/signed parts");
        return 1;
    }

    Jifty->log->debug('Found GnuPG protected parts');

    # return on any error
    if ( grep $_->{'exit_code'}, @res ) {
        Jifty->log->debug("Error during verify/decrypt operation");
        return ( 0, @res );
    }

    # nesting
    my ( $status, @nested ) = verify_decrypt(%args);
    return $status, @res, @nested;
}

1;


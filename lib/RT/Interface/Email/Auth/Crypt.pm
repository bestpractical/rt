# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2019 Best Practical Solutions, LLC
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

package RT::Interface::Email::Auth::Crypt;

use strict;
use warnings;

=head1 NAME

RT::Interface::Email::Auth::Crypt - decrypting and verifying protected emails

=head2 DESCRIPTION

This mail plugin decrypts and verifies incoming emails. Supported
encryption protocols are GnuPG and SMIME.

This code is independant from code that encrypts/sign outgoing emails, so
it's possible to decrypt data without bringing in encryption. To enable
it put the module in the mail plugins list:

    Set(@MailPlugins, 'Auth::MailFrom', 'Auth::Crypt', ...other filters...);

C<Auth::Crypt> will not function without C<Auth::MailFrom> listed before
it.

=head3 GnuPG

To use the gnupg-secured mail gateway, you need to do the following:

Set up a GnuPG key directory with a pubring containing only the keys
you care about and specify the following in your SiteConfig.pm

    Set(%GnuPGOptions, homedir => '/opt/rt4/var/data/GnuPG');

Read also: L<RT::Crypt> and L<RT::Crypt::GnuPG>.

=head3 SMIME

To use the SMIME-secured mail gateway, you need to do the following:

Set up a SMIME key directory with files containing keys for queues'
addresses and specify the following in your SiteConfig.pm

    Set(%SMIME,
        Enable => 1,
        OpenSSL => '/usr/bin/openssl',
        Keyring => '/opt/rt4/var/data/smime',
        CAPath  => '/opt/rt4/var/data/smime/signing-ca.pem',
        Passphrase => {
            'queue.address@example.com' => 'passphrase',
            '' => 'fallback',
        },
    );

Read also: L<RT::Crypt> and L<RT::Crypt::SMIME>.

=cut

sub ApplyBeforeDecode { return 1 }

use RT::Crypt;
use RT::EmailParser ();

sub GetCurrentUser {
    my %args = (
        Message       => undef,
        RawMessageRef => undef,
        Queue         => undef,
        Actions       => undef,
        @_
    );

    # we clean all possible headers
    my @headers =
        qw(
            X-RT-Incoming-Encryption
            X-RT-Incoming-Signature X-RT-Privacy
            X-RT-Sign X-RT-Encrypt
        ),
        map "X-RT-$_-Status", RT::Crypt->Protocols;
    foreach my $p ( $args{'Message'}->parts_DFS ) {
        $p->head->delete($_) for @headers;
    }

    my (@res) = RT::Crypt->VerifyDecrypt(
        %args,
        Entity => $args{'Message'},
    );
    if ( !@res ) {
        if (RT->Config->Get('Crypt')->{'RejectOnUnencrypted'}) {
            EmailErrorToSender(
                %args,
                Template  => 'Error: unencrypted message',
                Arguments => { Message  => $args{'Message'} },
            );
            return (-1, 'rejected because the message is unencrypted with RejectOnUnencrypted enabled');
        }
        else {
            $args{'Message'}->head->replace(
                'X-RT-Incoming-Encryption' => 'Not encrypted'
            );
        }
        return 1;
    }

    if ( grep {$_->{'exit_code'}} @res ) {
        my @fail = grep {$_->{status}{Status} ne "DONE"}
                   map { my %ret = %{$_}; map {+{%ret, status => $_}} RT::Crypt->ParseStatus( Protocol => $_->{Protocol}, Status => $_->{status})}
                   @res;
        for my $fail ( @fail ) {
            $RT::Logger->warning("Failure during ".$fail->{Protocol}." ". lc($fail->{status}{Operation}) . ": ". $fail->{status}{Message});
        }
        my $reject = HandleErrors( Message => $args{'Message'}, Result => \@res );
        return (0, 'rejected because of problems during decrypting and verifying')
            if $reject;
    }

    # attach the original encrypted message
    $args{'Message'}->attach(
        Type        => 'application/x-rt-original-message',
        Disposition => 'inline',
        Data        => ${ $args{'RawMessageRef'} },
    );

    my @found;
    my @check_protocols = RT::Crypt->EnabledOnIncoming;
    foreach my $part ( $args{'Message'}->parts_DFS ) {
        my $decrypted;

        foreach my $protocol ( @check_protocols ) {
            my @status = grep defined && length,
                map Encode::decode( "UTF-8", $_), $part->head->get( "X-RT-$protocol-Status" );
            next unless @status;

            push @found, $protocol;

            for ( map RT::Crypt->ParseStatus( Protocol => $protocol, Status => "$_" ), @status ) {
                if ( $_->{Operation} eq 'Decrypt' && $_->{Status} eq 'DONE' ) {
                    $decrypted = 1;
                }
                if ( $_->{Operation} eq 'Verify' && $_->{Status} eq 'DONE' ) {
                    $part->head->replace(
                        'X-RT-Incoming-Signature' => Encode::encode( "UTF-8", $_->{UserString} )
                    );
                }
            }
        }

        $part->head->replace(
            'X-RT-Incoming-Encryption' =>
                $decrypted ? 'Success' : 'Not encrypted'
        );
    }

    my %seen;
    $args{'Message'}->head->replace( 'X-RT-Privacy' => Encode::encode( "UTF-8", $_ ) )
        foreach grep !$seen{$_}++, @found;

    return 1;
}

sub HandleErrors {
    my %args = (
        Message => undef,
        Result => [],
        @_
    );

    my $reject = 0;

    my %sent_once = ();
    foreach my $run ( @{ $args{'Result'} } ) {
        my @status = RT::Crypt->ParseStatus( Protocol => $run->{'Protocol'}, Status => $run->{'status'} );
        unless ( $sent_once{'NoPrivateKey'} ) {
            unless ( CheckNoPrivateKey( Message => $args{'Message'}, Status => \@status ) ) {
                $sent_once{'NoPrivateKey'}++;
                $reject = 1 if RT->Config->Get('Crypt')->{'RejectOnMissingPrivateKey'};
            }
        }
        unless ( $sent_once{'BadData'} ) {
            unless ( CheckBadData( Message => $args{'Message'}, Status => \@status ) ) {
                $sent_once{'BadData'}++;
                $reject = 1 if RT->Config->Get('Crypt')->{'RejectOnBadData'};
            }
        }
    }
    return $reject;
}

sub CheckNoPrivateKey {
    my %args = (Message => undef, Status => [], @_ );
    my @status = @{ $args{'Status'} };

    my @decrypts = grep $_->{'Operation'} eq 'Decrypt', @status;
    return 1 unless @decrypts;
    foreach my $action ( @decrypts ) {
        # if at least one secrete key exist then it's another error
        return 1 if
            grep !$_->{'User'}{'SecretKeyMissing'},
                @{ $action->{'EncryptedTo'} };
    }

    $RT::Logger->error("Couldn't decrypt a message: have no private key");

    return EmailErrorToSender(
        %args,
        Template  => 'Error: no private key',
        Arguments => { Message   => $args{'Message'} },
    );
}

sub CheckBadData {
    my %args = (Message => undef, Status => [], @_ );
    my @bad_data_messages = 
        map $_->{'Message'},
        grep $_->{'Status'} ne 'DONE' && $_->{'Operation'} eq 'Data',
        @{ $args{'Status'} };
    return 1 unless @bad_data_messages;

    return EmailErrorToSender(
        %args,
        Template  => 'Error: bad encrypted data',
        Arguments => { Messages  => [ @bad_data_messages ] },
    );
}

sub EmailErrorToSender {
    my %args = (@_);

    $args{'Arguments'} ||= {};
    $args{'Arguments'}{'TicketObj'} ||= $args{'Ticket'};

    my $address = (RT::Interface::Email::ParseSenderAddressFromHead( $args{'Message'}->head ))[0];
    my ($status) = RT::Interface::Email::SendEmailUsingTemplate(
        To        => $address,
        Template  => $args{'Template'},
        Arguments => $args{'Arguments'},
        InReplyTo => $args{'Message'},
    );
    unless ( $status ) {
        $RT::Logger->error("Couldn't send '$args{'Template'}''");
    }
    return 0;
}

RT::Base->_ImportOverlays();

1;

# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2025 Best Practical Solutions, LLC
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

package RT::Authen::Passkey;

use strict;
use warnings;

use Authen::WebAuthn;
use Crypt::URandom;
use MIME::Base64 qw(encode_base64url);
use URI;

=head1 NAME

RT::Authen::Passkey - WebAuthn passkey ceremony driver for RT

=head2 RPID

Returns the WebAuthn Relying Party ID, derived from C<$WebDomain>.
Per the spec, this must equal the origin's effective domain; RT
validates assertions against a single canonical origin (see L</Origin>),
so RPID is fixed to the configured hostname.

=cut

sub RPID {
    return RT->Config->Get('WebDomain');
}

=head2 Origin

Returns the canonical origin (scheme + host [+ port]) used to construct
challenge ceremony options and as the L<Authen::WebAuthn> C<origin>
parameter. Derived from C<$WebURL>.

=cut

sub Origin {
    my $uri = URI->new( RT->Config->Get('WebURL') )->canonical;
    return $uri->scheme . '://' . $uri->authority;
}

sub _ChallengeBytes {
    return Crypt::URandom::urandom(32);
}

# Browser-side ceremony timeout in milliseconds. Drives both this number
# and the server-side challenge lifetime from a single config knob so the
# two halves of the timeout never disagree.
sub _CeremonyTimeoutMs {
    return ( RT->Config->Get('PasskeyChallengeTimeout') // 300 ) * 1000;
}

=head2 BuildRegistrationOptions User => USER, Name => NAME, ExcludeCredentials => EXCLUDE_CREDENTIALS

Produces the C<publicKey> options hash to send to the browser for
C<navigator.credentials.create()>. Returns C<($options_hashref, $challenge_raw)>.
Caller is responsible for storing C<$challenge_raw> in the session before
sending the options to the browser.

=cut

sub BuildRegistrationOptions {
    my ( $class, %args ) = @_;
    my $user    = $args{User} or return;
    my $name    = $args{Name}               // 'Passkey';
    my $exclude = $args{ExcludeCredentials} // [];

    my $challenge = $class->_ChallengeBytes;

    my $rp_name = RT->Config->Get('rtname') || 'RT';

    # Mint a WebAuthn user handle the first time this user enrolls.
    # Subsequent enrollments reuse the stored value so every
    # authenticator on the account shares the same userHandle. _Value
    # gates the read on CurrentUserCanSee so the field's read => 0
    # overlay is honored; SetRandomPasskeyUserHandle gates the write.
    my $handle = $user->_Value('PasskeyUserHandle') // '';
    unless ( length $handle ) {
        my ( $ok ) = $user->SetRandomPasskeyUserHandle;
        return unless $ok;
        $handle = $user->_Value('PasskeyUserHandle');
    }

    return {
        challenge => encode_base64url($challenge),
        rp        => {
            id   => $class->RPID,
            name => $rp_name,
        },
        user => {
            id          => $handle,
            name        => $user->Name,
            displayName => $user->RealName || $user->Name,
        },
        pubKeyCredParams => [
            { type => 'public-key', alg => -7 },      # ES256
            { type => 'public-key', alg => -257 },    # RS256
            { type => 'public-key', alg => -8 },      # EdDSA
        ],
        excludeCredentials     => [ map { { type => 'public-key', id => $_ } } @$exclude ],
        authenticatorSelection => {
            residentKey      => 'required',
            userVerification => 'required',
        },
        attestation => 'none',
        timeout     => $class->_CeremonyTimeoutMs,
    }, $challenge;
}

=head2 BuildAssertionOptions

Produces the C<publicKey> options hash for C<navigator.credentials.get()>.
Returns C<($options_hashref, $challenge_raw)>.

=cut

sub BuildAssertionOptions {
    my $class     = shift;
    my $challenge = $class->_ChallengeBytes;
    return {
        challenge => encode_base64url($challenge),
        rpId      => $class->RPID,
        # Empty by design: the login page has no username field, so the
        # browser must offer every resident credential it has for this
        # RP. Listing the user's stored credentials here would (a)
        # require knowing who is logging in before they say so, defeating
        # the usernameless flow, and (b) leak whether a given account has
        # passkeys registered.
        allowCredentials => [],
        userVerification => 'required',
        timeout          => $class->_CeremonyTimeoutMs,
    }, $challenge;
}

=head2 ValidateRegistration

Takes a paramhash with C<Challenge>, C<ClientDataJSONB64>, and
C<AttestationObjectB64>. Wraps L<Authen::WebAuthn>'s
C<validate_registration>. Returns C<($ret, $data, $err)> where C<$data>
is a hashref with keys C<credential_id> (b64url), C<credential_pubkey>
(b64url), and C<signature_count>.

=cut

sub ValidateRegistration {
    my ( $class, %args ) = @_;
    my $challenge_b64 = encode_base64url( $args{Challenge} );

    my $rp = Authen::WebAuthn->new(
        rp_id  => $class->RPID,
        origin => $class->Origin,
    );

    my $result = eval {
        $rp->validate_registration(
            challenge_b64          => $challenge_b64,
            requested_uv           => 'required',
            client_data_json_b64   => $args{ClientDataJSONB64},
            attestation_object_b64 => $args{AttestationObjectB64},
        );
    };
    if ( my $err = $@ ) {
        chomp $err;
        return ( 0, undef, $err );
    }

    return (
        1,
        {   credential_id     => $result->{credential_id},
            credential_pubkey => $result->{credential_pubkey},
            signature_count   => $result->{signature_count} // 0,
        },
        undef
    );
}

=head2 ValidateAssertion

Wraps L<Authen::WebAuthn>'s C<validate_assertion>. Required arguments:
C<Challenge> (raw bytes), C<CredentialPubKeyB64>, C<StoredSignCount>,
C<ClientDataJSONB64>, C<AuthenticatorDataB64>, C<SignatureB64>. Returns
C<($ret, $data, $err)> where C<$data> has C<signature_count>.

=cut

sub ValidateAssertion {
    my ( $class, %args ) = @_;
    my $challenge_b64 = encode_base64url( $args{Challenge} );

    my $rp = Authen::WebAuthn->new(
        rp_id  => $class->RPID,
        origin => $class->Origin,
    );

    my $result = eval {
        $rp->validate_assertion(
            challenge_b64          => $challenge_b64,
            credential_pubkey_b64  => $args{CredentialPubKeyB64},
            stored_sign_count      => $args{StoredSignCount},
            requested_uv           => 'required',
            client_data_json_b64   => $args{ClientDataJSONB64},
            authenticator_data_b64 => $args{AuthenticatorDataB64},
            signature_b64          => $args{SignatureB64},
        );
    };
    if ( my $err = $@ ) {
        chomp $err;
        return ( 0, undef, $err );
    }

    return ( 1, { signature_count => $result->{signature_count} // 0, }, undef );
}

require RT::Base;
RT::Base->_ImportOverlays();

1;

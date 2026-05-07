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

package RT::Test::Passkey;

use strict;
use warnings;

use Crypt::PK::ECC;
use Crypt::Digest::SHA256 qw(sha256);
use Crypt::URandom;
use CBOR::XS;
use JSON         qw(encode_json);
use MIME::Base64 qw(encode_base64url);

use RT::Authen::Passkey;

=head1 NAME

RT::Test::Passkey - in-test WebAuthn soft authenticator

=head1 SYNOPSIS

    my $authn = RT::Test::Passkey->new_authenticator;
    my $resp = $authn->register(
        challenge_b64 => $c, rp_id => "rt.example.com",
        origin => "https://rt.example.com:8080",
        user_handle_b64 => $uh,
    );
    # $resp has client_data_json_b64, attestation_object_b64,
    # credential_id_b64, public_key_b64

    my $resp = $authn->assert(
        challenge_b64 => $c, rp_id => "rt.example.com",
        origin => "https://rt.example.com:8080",
        credential_id_b64 => $cid,
        user_handle_b64 => $uh,
    );
    # $resp has client_data_json_b64, authenticator_data_b64,
    # signature_b64, user_handle_b64, credential_id_b64

=cut

# A soft authenticator instance: { pk => Crypt::PK::ECC, credential_id => bytes, sign_count => N }
# All bytes inside the object are RAW; encoding to base64url happens at API edges.

sub new_authenticator {
    my $class = shift;
    my $pk    = Crypt::PK::ECC->new;
    $pk->generate_key('prime256v1');
    return bless {
        pk            => $pk,
        credential_id => Crypt::URandom::urandom(32),
        sign_count    => 0,
    }, $class;
}

# Build a COSE-encoded EC2 P-256 public key from the keypair.
sub _cose_public_key {
    my $self = shift;
    my $hash = $self->{pk}->key2hash;
    my $x    = pack( 'H*', $hash->{pub_x} );
    my $y    = pack( 'H*', $hash->{pub_y} );
    return CBOR::XS->new->encode(
        {   1  =>  2,    # kty: EC2
            3  => -7,    # alg: ES256
            -1 =>  1,    # crv: P-256
            -2 => $x,
            -3 => $y,
        }
    );
}

# Build the authenticatorData byte string.
# $kind eq 'register' includes attestedCredentialData.
sub _build_auth_data {
    my ( $self, %args ) = @_;
    my $rp_id_hash = sha256( $args{rp_id} );
    my $flags      = 0x01 | 0x04;              # UP (0x01) + UV (0x04)
    if ( $args{kind} eq 'register' ) {
        $flags |= 0x40;                        # AT (attested credential data)
    }
    my $sign_count_packed = pack( 'N', $args{sign_count} );

    my $auth_data = $rp_id_hash . pack( 'C', $flags ) . $sign_count_packed;

    if ( $args{kind} eq 'register' ) {
        my $cose    = $self->_cose_public_key;
        my $cred_id = $self->{credential_id};

        # AAGUID slot is required by the WebAuthn wire format but RT
        # does not store or display it, so emit 16 zero bytes.
        my $attested = ( "\x00" x 16 ) . pack( 'n', length($cred_id) ) . $cred_id . $cose;
        $auth_data .= $attested;
    }
    return $auth_data;
}

=head2 register %args

Produces a registration response. Required args: C<challenge_b64>,
C<rp_id>, C<origin>, C<user_handle_b64>. Returns hashref with
C<client_data_json_b64>, C<attestation_object_b64>,
C<credential_id_b64>, C<public_key_b64>.

=cut

sub register {
    my ( $self, %args ) = @_;

    my $client_data = encode_json(
        {   type      => 'webauthn.create',
            challenge => $args{challenge_b64},
            origin    => $args{origin},
        }
    );

    my $auth_data = $self->_build_auth_data(
        rp_id      => $args{rp_id},
        sign_count => 0,
        kind       => 'register',
    );

    my $att_obj = CBOR::XS->new->encode(
        {   fmt      => 'none',
            attStmt  => {},
            authData => $auth_data,
        }
    );

    return {
        client_data_json_b64   => encode_base64url($client_data),
        attestation_object_b64 => encode_base64url($att_obj),
        credential_id_b64      => encode_base64url( $self->{credential_id} ),
        public_key_b64         => encode_base64url( $self->_cose_public_key ),
    };
}

=head2 assert %args

Produces an assertion response. Required args: C<challenge_b64>,
C<rp_id>, C<origin>. The optional C<user_handle_b64> is round-tripped
verbatim into the response so tests can drive both correct and
mismatched userHandle paths; it is not validated. Returns hashref with
C<client_data_json_b64>, C<authenticator_data_b64>, C<signature_b64>,
C<user_handle_b64>, C<credential_id_b64>.

=cut

sub assert {
    my ( $self, %args ) = @_;

    $self->{sign_count}++;

    my $client_data = encode_json(
        {   type      => 'webauthn.get',
            challenge => $args{challenge_b64},
            origin    => $args{origin},
        }
    );

    my $auth_data = $self->_build_auth_data(
        rp_id      => $args{rp_id},
        sign_count => $self->{sign_count},
        kind       => 'assert',
    );

    my $client_data_hash = sha256($client_data);
    my $signed           = $auth_data . $client_data_hash;
    my $signature        = $self->{pk}->sign_message( $signed, 'SHA256' );

    return {
        client_data_json_b64   => encode_base64url($client_data),
        authenticator_data_b64 => encode_base64url($auth_data),
        signature_b64          => encode_base64url($signature),
        user_handle_b64        => $args{user_handle_b64},
        credential_id_b64      => encode_base64url( $self->{credential_id} ),
    };
}

=head2 set_sign_count $n

Forces the soft authenticator's internal counter (used by tests that
exercise counter regression handling).

=cut

sub set_sign_count {
    my ( $self, $n ) = @_;
    $self->{sign_count} = $n;
}

require RT::Base;
RT::Base->_ImportOverlays();

1;

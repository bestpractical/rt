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

package RT::MFA::TOTP;

use strict;
use warnings;

use Auth::GoogleAuth;
use Crypt::AuthEnc::GCM;
use Crypt::URandom;
use Imager::QRCode;
use Imager::Color;
use MIME::Base64 qw(encode_base64);

# Per-account TOTP verification rate limit. Override in RT_SiteConfig.pm or
# a plugin, e.g.:
#     $RT::MFA::TOTP::MAX_VERIFY_ATTEMPTS = 10;
#     $RT::MFA::TOTP::LOCKOUT_INTERVAL    = 30 * 60;
our $MAX_VERIFY_ATTEMPTS = 5;
our $LOCKOUT_INTERVAL    = 15 * 60;

=head1 NAME

RT::MFA::TOTP - TOTP multi-factor authentication helpers

=head2 GenerateSecret

Returns a new random base32-encoded TOTP shared secret.

=cut

sub GenerateSecret {
    my $class = shift;
    my $auth  = Auth::GoogleAuth->new;
    return uc $auth->generate_secret32;
}

=head2 QRCodeURI Secret => $secret, User => $user_obj

Returns the C<otpauth://totp/...> URI for use with authenticator apps.
Uses RT's site name as the issuer and the user's email address (or Name
if no email) as the account identifier.

=cut

sub QRCodeURI {
    my ( $class, %args ) = @_;
    my $secret = $args{Secret};
    my $user   = $args{User};

    my $issuer  = RT->Config->Get('rtname') || 'RT';
    my $account = $user->EmailAddress       || $user->Name;

    my $auth = Auth::GoogleAuth->new(
        {   secret32 => $secret,
            issuer   => $issuer,
            key_id   => $account,
        }
    );
    return $auth->otpauth;
}

=head2 QRCodeDataURL Secret => $secret, User => $user_obj

Returns the QR code as a C<data:image/png;base64,...> string suitable for
embedding directly in an HTML C<< <img> >> tag.

=cut

sub QRCodeDataURL {
    my ( $class, %args ) = @_;
    my $uri = $class->QRCodeURI(%args);

    my $qrcode = Imager::QRCode->new(
        size          => 4,
        margin        => 3,
        level         => 'M',
        casesensitive => 1,
        lightcolor    => Imager::Color->new( 255, 255, 255 ),
        darkcolor     => Imager::Color->new( 0,   0,   0 ),
    );

    my $img = $qrcode->plot($uri);
    my $data;
    $img->write( data => \$data, type => 'png' );

    return 'data:image/png;base64,' . encode_base64( $data, '' );
}

=head2 VerifyCode Secret => $secret, Code => $code, Drift => $n, User => $user_obj

Verifies a 6-digit TOTP code against the given base32 secret.
C<Drift> is the number of 30-second TOTP windows accepted on each
side of the current step (default: C<0>, meaning only the current
window). Use C<1> to also accept one window before and one after,
C<2> for two in each direction, etc. Maximum allowed value is C<5>
(equivalent to a total of 11 accepted windows).

When C<User> is provided, the method also enforces replay protection by
tracking the time window of the last successfully used code. Any code
whose matching window is at or before the last-used window is rejected,
preventing reuse even when multiple codes are valid simultaneously due
to the drift setting.

Returns true if the code is valid, false otherwise.

=cut

sub VerifyCode {
    my ( $class, %args ) = @_;
    my $secret = $args{Secret};
    my $code   = $args{Code};
    my $drift  = $args{Drift} // 0;
    my $user   = $args{User};

    return 0 unless defined $code && $code =~ /^\d{6}$/;

    my $interval = 30;

    my $now  = time;
    my $auth = Auth::GoogleAuth->new( { secret32 => $secret } );

    # Find which time window the code matches, checking from newest to
    # oldest so we record the highest valid window for replay protection.
    my $matched_window;
    for my $offset ( reverse( -$drift .. $drift ) ) {
        my $ts = $now + $offset * $interval;
        if ( RT::Util::constant_time_eq( $code, $auth->code( undef, $ts, $interval ) ) ) {
            $matched_window = int( $ts / $interval );
            last;
        }
    }
    return 0 unless defined $matched_window;

    # Replay protection: reject codes from windows at or before the last used
    if ($user) {
        my $attr = $user->FirstAttribute('TOTPLastUsedWindow');
        if ( $attr && defined $attr->Content && $matched_window <= $attr->Content ) {
            return 0;
        }
        $user->SetAttribute(
            Name    => 'TOTPLastUsedWindow',
            Content => $matched_window,
        );
    }

    return 1;
}

require RT::Base;
RT::Base->_ImportOverlays();

1;

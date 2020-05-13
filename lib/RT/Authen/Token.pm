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

package RT::Authen::Token;

use strict;
use warnings;

use RT::System;

'RT::System'->AddRight(Staff => ManageAuthTokens => 'Manage authentication tokens'); # loc

use RT::AuthToken;
use RT::AuthTokens;

sub UserForAuthString {
    my $self = shift;
    my $authstring = shift;
    my $user = shift;

    my ($user_id, $cleartext_token) = RT::AuthToken->ParseAuthString($authstring);
    return unless $user_id;

    my $user_obj = RT::CurrentUser->new;
    $user_obj->Load($user_id);
    return if !$user_obj->Id || $user_obj->Disabled;

    if (length $user) {
        my $check_user = RT::CurrentUser->new;
        $check_user->Load($user);
        return unless $check_user->Id && $user_obj->Id == $check_user->Id;
    }

    my $tokens = RT::AuthTokens->new(RT->SystemUser);
    $tokens->LimitOwner(VALUE => $user_id);
    while (my $token = $tokens->Next) {
        if ($token->IsToken($cleartext_token)) {
            $token->UpdateLastUsed;
            return ($user_obj, $token);
        }
    }

    return;
}

=head1 NAME

RT-Authen-Token - token-based authentication

=head1 DESCRIPTION

Allow for users to generate and login with authentication tokens. Users
with the C<ManageAuthTokens> permission will see a new "Auth Tokens"
menu item under "Logged in as ____" -> Settings. On that page they will
be able to generate new tokens and modify or revoke existing tokens.

Once you have an authentication token, you may use it in place of a
password to log into RT. (Additionally, L<REST2> allows for using auth
tokens with the C<Authorization: token> HTTP header.) One common use
case is to use an authentication token as an application-specific
password, so that you may revoke that application's access without
disturbing other applications. You also need not change your password,
since the application never received it.

If you have the C<AdminUsers> permission, along with
C<ManageAuthTokens>, you may generate, modify, and revoke tokens for
other users as well by visiting Admin -> Users -> Select -> (user) ->
Auth Tokens.

Authentication tokens are stored securely (hashed and salted) in the
database just like passwords, and so cannot be recovered after they are
generated.

=head2 Update your Apache configuration

If you are running RT under Apache, add the following directive to your RT
Apache configuration to allow RT to access the Authorization header.

    SetEnvIf Authorization "(.*)" HTTP_AUTHORIZATION=$1
=cut

1;

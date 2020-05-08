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

package RT::REST2::Middleware::Auth;

use strict;
use warnings;

use base 'Plack::Middleware';

our @auth_priority = qw(
    login_from_cookie
    login_from_authtoken
    login_from_basicauth
);

sub call {
    my ($self, $env) = @_;

    RT::ConnectToDatabase();
    for my $method (@auth_priority) {
        last if $env->{'rt.current_user'} = $self->$method($env);
    }

    if ($env->{'rt.current_user'}) {
        return $self->app->($env);
    }
    else {
        return $self->unauthorized($env);
    }
}

sub login_from_cookie {
    my ($self, $env) = @_;

    # allow reusing authentication from the ordinary web UI so that
    # among other things our JS can use REST2
    if ($env->{HTTP_COOKIE}) {
        no warnings 'redefine';

        # this is foul but LoadSessionFromCookie doesn't have a hook for
        # saying "look up cookie in my $env". this beats duplicating
        # LoadSessionFromCookie
        local *RT::Interface::Web::RequestENV = sub { return $env->{$_[0]} }
            if RT::Handle::cmp_version($RT::VERSION, '4.4.0') >= 0;

        # similar but for 4.2
        local %ENV = %$env
            if RT::Handle::cmp_version($RT::VERSION, '4.4.0') < 0;

        local *HTML::Mason::Commands::session;

        RT::Interface::Web::LoadSessionFromCookie();
        if (RT::Interface::Web::_UserLoggedIn) {
            return $HTML::Mason::Commands::session{CurrentUser};
        }
    }

    return;
}

sub login_from_authtoken {
    my ($self, $env) = @_;

    # needs RT::Authen::Token extension
    return unless RT::AuthToken->can('Create');

    # Authorization: token 1-14-abcdef header
    my ($authstring) = ($env->{HTTP_AUTHORIZATION}||'') =~ /^token (.*)$/i;

    # or ?token=1-14-abcdef query parameter
    $authstring ||= Plack::Request->new($env)->parameters->{token};

    if ($authstring) {
        my ($user_obj, $token) = RT::Authen::Token->UserForAuthString($authstring);
        return $user_obj;
    }

    return;
}

sub login_from_basicauth {
    my ($self, $env) = @_;

    require MIME::Base64;
    if (($env->{HTTP_AUTHORIZATION}||'') =~ /^basic (.*)$/i) {
        my($user, $pass) = split /:/, (MIME::Base64::decode($1) || ":"), 2;
        my $cu = RT::CurrentUser->new;
        $cu->Load($user);
        if ($cu->id and $cu->IsPassword($pass)) {
            return $cu;
        }
        else {
            RT->Logger->info("Failed login for $user");
            return;
        }
    }

    return;
}

sub _looks_like_browser {
    my $self = shift;
    my $env = shift;

    return 1 if $env->{HTTP_COOKIE};
    return 1 if $env->{HTTP_USER_AGENT} =~ /Mozilla/;
    return 0;
}

sub unauthorized {
    my $self = shift;
    my $env = shift;

    if ($self->_looks_like_browser($env)) {
        my $url = RT->Config->Get('WebPath') . '/';
        return [
            302,
            [ 'Location' => $url ],
            [ "Login required" ],
        ];
    }
    else {
        my $body = 'Authorization required';
        return [
            401,
            [ 'Content-Type' => 'text/plain',
              'Content-Length' => length $body ],
            [ $body ],
        ];
    }
}

1;

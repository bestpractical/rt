package RT::Extension::REST2::Middleware::Auth;

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

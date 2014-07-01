use strict;
use warnings;
use RT;
use RT::Test plan => 'no_plan';

sub stop_server {
    my $mech = shift;

    # Ensure we're logged in for the final warnings check
    $$mech->auth("root");

    # Force the warnings check before we stop the server
    undef $$mech;

    RT::Test->stop_server;
}

diag "Continuous + Fallback";
{
    RT->Config->Set( DevelMode => 0 );
    RT->Config->Set( WebRemoteUserAuth => 1 );
    RT->Config->Set( WebRemoteUserAuthContinuous => 1 );
    RT->Config->Set( WebFallbackToRTLogin => 1 );
    RT->Config->Set( WebRemoteUserAutocreate => 0 );

    my ( $url, $m ) = RT::Test->started_ok( basic_auth => 'anon' );

    diag "Internal auth";
    {
        # Empty REMOTE_USER
        $m->auth("");

        # First request gets the login form
        $m->get_ok($url, "No basic auth is OK");
        $m->content_like(qr/Login/, "Login form");

        # Log in using RT's form
        $m->submit_form_ok({
            with_fields => {
                user => 'root',
                pass => 'password',
            },
        }, "Submitted login form");
        ok $m->logged_in_as("root"), "Logged in as root";

        # Still logged in on another request without REMOTE_USER
        $m->follow_link_ok({ text => 'My Tickets' });
        ok $m->logged_in_as("root"), "Logged in as root";

        ok $m->logout, "Logged out";

        # We're definitely logged out?
        $m->get_ok($url);
        $m->content_like(qr/Login/, "Login form");
    }

    diag "External auth";
    {
        # REMOTE_USER of root
        $m->auth("root");

        # Automatically logged in as root without Login page
        $m->get_ok($url);
        ok $m->logged_in_as("root"), "Logged in as root";

        # Still logged in on another request
        $m->follow_link_ok({ text => 'My Tickets' });
        ok $m->logged_in_as("root"), "Still logged in as root";

        # Drop credentials and...
        $m->auth("");

        # ...see if RT notices
        $m->get($url);
        is $m->status, 403, "403 Forbidden from RT";

        # Next request gets us the login form
        $m->get_ok($url);
        $m->content_like(qr/Login/, "Login form");
    }

    diag "External auth with invalid user, login internally";
    {
        # REMOTE_USER of invalid
        $m->auth("invalid");

        # Login internally via the login link
        $m->get("$url/Search/Build.html");
        is $m->status, 403, "403 Forbidden";
        $m->follow_link_ok({ url_regex => qr'NoAuth/Login\.html' }, "follow logout link");
        $m->content_like(qr/Login/, "Login form");

        # Log in using RT's form
        $m->submit_form_ok({
            with_fields => {
                user => 'root',
                pass => 'password',
            },
        }, "Submitted login form");
        ok $m->logged_in_as("root"), "Logged in as root";
        like $m->uri, qr'Search/Build\.html', "at our originally requested page";

        # Still logged in on another request
        $m->follow_link_ok({ text => 'Tools' });
        ok $m->logged_in_as("root"), "Logged in as root";

        ok $m->logout, "Logged out";

        $m->next_warning_like(qr/Couldn't find internal user for 'invalid'/, "found warning for first request");
        $m->next_warning_like(qr/Couldn't find internal user for 'invalid'/, "found warning for second request");
    }

    stop_server(\$m);
}

diag "Fallback OFF";
{
    RT->Config->Set( DevelMode => 0 );
    RT->Config->Set( WebRemoteUserAuth => 1 );
    RT->Config->Set( WebRemoteUserContinuous => 0 );
    RT->Config->Set( WebFallbackToRTLogin => 0 );
    RT->Config->Set( WebRemoteUserAutocreate => 0 );

    my ( $url, $m ) = RT::Test->started_ok( basic_auth => 'anon' );

    diag "No remote user";
    {
        $m->auth("");
        $m->get($url);
        is $m->status, 403, "Forbidden";
    }

    stop_server(\$m);
}

diag "WebRemoteUserAutocreate";
{
    RT->Config->Set( DevelMode => 0 );
    RT->Config->Set( WebRemoteUserAuth => 1 );
    RT->Config->Set( WebRemoteUserContinuous => 1 );
    RT->Config->Set( WebFallbackToRTLogin => 0 );
    RT->Config->Set( WebRemoteUserAutocreate => 1 );
    RT->Config->Set( UserAutocreateDefaultsOnLogin => { Organization => "BPS" } );

    my ( $url, $m ) = RT::Test->started_ok( basic_auth => 'anon' );

    diag "New user";
    {
        $m->auth("anewuser");
        $m->get_ok($url);
        ok $m->logged_in_as("anewuser"), "Logged in as anewuser";

        my $user = RT::User->new( RT->SystemUser );
        $user->Load("anewuser");
        ok $user->id, "Found newly created user";
        is $user->Organization, "BPS", "Found Organization from UserAutocreateDefaultsOnLogin hash";
        ok $user->Privileged, "Privileged by default";
    }

    stop_server(\$m);
    RT->Config->Set(
        UserAutocreateDefaultsOnLogin => {
            Privileged   => 0,
            EmailAddress => 'foo@example.com',
        },
    );
    ( $url, $m ) = RT::Test->started_ok( basic_auth => 'anon' );

    diag "Create unprivileged users";
    {
        $m->auth("unpriv");
        $m->get_ok($url);
        ok $m->logged_in_as("unpriv"), "Logged in as an unpriv user";
        like $m->uri->path, RT->Config->Get('SelfServiceRegex'), "SelfService URL";

        my $user = RT::User->new( RT->SystemUser );
        $user->Load("unpriv");
        ok $user->id, "Found newly created user";
        ok !$user->Privileged, "Unprivileged per config";
        is $user->EmailAddress, 'foo@example.com', "Email address per config";
    }

    diag "User creation failure";
    {
        $m->auth("conflicting");
        $m->get($url);
        is $m->status, 403, "Forbidden";
        $m->next_warning_like(qr/Couldn't auto-create user 'conflicting' when attempting WebRemoteUser: Email address in use/, 'found failed auth warning');

        my $user = RT::User->new( RT->SystemUser );
        $user->Load("conflicting");
        ok !$user->id, "Couldn't find conflicting user";
    }

    stop_server(\$m);
}


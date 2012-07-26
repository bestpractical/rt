use strict;
use warnings;
use RT;
use RT::Test plan => 'no_plan';
use MIME::Base64 qw//;

sub auth {
    return Authorization => "Basic " .
        MIME::Base64::encode( join(":", @_) );
}

sub logged_in_as {
    my $mech = shift;
    my $user = shift || '';

    unless ($mech->status == 200) {
        diag "Error: status is ". $mech->status;
        return 0;
    }

    RT::Interface::Web::EscapeUTF8(\$user);
    unless ($mech->content =~ m{<span class="current-user">\Q$user\E</span>}i) {
        diag "Error: page has no user name";
        return 0;
    }
    return 1;
}

sub stop_server {
    my $mech = shift;

    # Ensure we're logged in for the final warnings check
    $$mech->default_header( auth("root") );

    # Force the warnings check before we stop the server
    undef $$mech;

    RT::Test->stop_server;
}

diag "Continuous + Fallback";
{
    RT->Config->Set( DevelMode => 0 );
    RT->Config->Set( WebExternalAuth => 1 );
    RT->Config->Set( WebExternalAuthContinuous => 1 );
    RT->Config->Set( WebFallbackToInternalAuth => 1 );
    RT->Config->Set( WebExternalAuto => 0 );

    my ( $url, $m ) = RT::Test->started_ok( basic_auth => 'anon' );

    diag "Internal auth";
    {
        # Empty REMOTE_USER
        $m->default_header( auth("") );

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
        ok logged_in_as($m, "root"), "Logged in as root";

        # Still logged in on another request without REMOTE_USER
        $m->follow_link_ok({ text => 'My Tickets' });
        ok logged_in_as($m, "root"), "Logged in as root";

        ok $m->logout, "Logged out";

        # We're definitely logged out?
        $m->get_ok($url);
        $m->content_like(qr/Login/, "Login form");
    }

    diag "External auth";
    {
        # REMOTE_USER of root
        $m->default_header( auth("root") );

        # Automatically logged in as root without Login page
        $m->get_ok($url);
        ok logged_in_as($m, "root"), "Logged in as root";

        # Still logged in on another request
        $m->follow_link_ok({ text => 'My Tickets' });
        ok logged_in_as($m, "root"), "Still logged in as root";

        # Drop credentials and...
        $m->default_header( auth("") );

        # ...see if RT notices
        $m->get($url);
        is $m->status, 403, "403 Forbidden from RT";
        is $m->content, '', "No content returned";
        # XXX should this be a 403?

        # Next request gets us the login form
        $m->get_ok($url);
        $m->content_like(qr/Login/, "Login form");
    }

    stop_server(\$m);
}


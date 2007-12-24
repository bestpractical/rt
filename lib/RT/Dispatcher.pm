
use warnings;
use strict;
package RT::Dispatcher;

use Jifty::Dispatcher -base;

use RT;
RT->load_config;
use RT::Interface::Web;
use RT::Interface::Web::Handler;
RT::I18N->init();

before qr/.*/ => run {
RT::InitSystemObjects();

};

before qr/.*/ => run {
if ( int RT->Config->Get('AutoLogoff') ) {
    my $now = int(time/60);
    # XXX TODO 4.0 port this;
    my $last_update;
    if ( $last_update && ($now - $last_update - RT->Config->Get('AutoLogoff')) > 0 ) {
        # clean up sessions, but we should leave the session id
    }

    # save session on each request when AutoLogoff is turned on
}

};

before qr'/(?!login)' => run {
    tangent '/login' unless (Jifty->web->current_user->id);
};

before qr/(.*)/ => run {
    my $path = $1;
# This code canonicalize_s time inputs in hours into minutes
# If it's a noauth file, don't ask for auth.

    # Set the proper encoding for the current Language handle
#    content_type("text/html; charset=utf-8");

    return;
    # XXX TODO 4.0 implmeent self service smarts
# If the user isn't privileged, they can only see SelfService
unless ( Jifty->web->current_user->user_object && Jifty->web->current_user->user_object->privileged ) {

    # if the user is trying to access a ticket, redirect them
    if (    $path =~ '^(/+)Ticket/Display.html' && get('id')) {
        RT::Interface::Web::Redirect( RT->Config->Get('WebURL') ."SelfService/Display.html?id=".get('id'));
    }

    # otherwise, drop the user at the SelfService default page
    elsif ( $path !~ '^(/+)SelfService/' ) {
        RT::Interface::Web::Redirect( RT->Config->Get('WebURL') ."SelfService/" );
    }
}

}


after qr/.*/ => run {
    RT::Interface::Web::Handler::CleanupRequest()
};


# Backward compatibility with old RT URLs

before '/NoAuth/Logout.html' => run { redirect '/logout' };

1;

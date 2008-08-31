# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2007 Best Practical Solutions, LLC
#                                          <jesse@bestpractical.com>
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
# http://www.gnu.org/copyleft/gpl.html.
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
    RT::init_system_objects();

};

before qr/.*/ => run {
    if ( int RT->config->get('AutoLogoff') ) {
        my $now = int( time / 60 );

        # XXX TODO 4.0 port this;
        my $last_update;
        if ( $last_update
            && ( $now - $last_update - RT->config->get('AutoLogoff') ) > 0 )
        {

            # clean up sessions, but we should leave the session id
        }

        # save session on each request when AutoLogoff is turned on
    }

};

before qr/.*/ => run {
    Jifty->web->new_action(
        moniker   => 'login',
        class     => 'Login',
        arguments => {
            email    => Jifty->web->request->arguments->{'user'},
            password => Jifty->web->request->arguments->{'pass'}
        }
        )->run
        if ( Jifty->web->request->arguments->{'user'}
        && Jifty->web->request->arguments->{'pass'} );
};

# XXX TODO XXX SECURITY RISK - this regex is WRONG AND UNSAFE
before qr'^/(?!login)' => run {
    tangent '/login'
        unless ( Jifty->web->current_user->id
        || Jifty->web->request->path =~ /NoAuth/i
        || Jifty->web->request->path =~ m{^/__jifty/(css|js)} );
};

before qr/(.*)/ => run {
    my $path = Jifty->web->request->path;

    # This code canonicalize_s time inputs in hours into minutes
    # If it's a noauth file, don't ask for auth.

    # Set the proper encoding for the current Language handle
    #    content_type("text/html; charset=utf-8");

    return;

    # XXX TODO 4.0 implmeent self service smarts
    # If the user isn't privileged, they can only see SelfService
    unless ( Jifty->web->current_user->user_object
        && Jifty->web->current_user->user_object->privileged )
    {

        # if the user is trying to access a ticket, redirect them
        if ( $path =~ '^(/+)Ticket/Display.html' && get('id') ) {
            RT::Interface::Web::redirect( RT->config->get('WebURL') . "SelfService/Display.html?id=" . get('id') );
        }

        # otherwise, drop the user at the SelfService default page
        elsif ( $path !~ '^(/+)SelfService/' ) {
            RT::Interface::Web::redirect( RT->config->get('WebURL') . "SelfService/" );
        }
    }

}

after qr/.*/ => run {
    RT::Interface::Web::Handler::cleanup_request();
};

# Backward compatibility with old RT URLs

before '/NoAuth/Logout.html' => run { redirect '/logout' };

1;

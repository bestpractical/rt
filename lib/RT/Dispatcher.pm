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
use RT::Interface::Web;
use RT::Interface::Web::Handler;

before qr/.*/ => run {
    if ( int RT->config->get('auto_logoff') ) {
        my $now = int( time / 60 );

        # XXX TODO 4.0 port this;
        my $last_update;
        if ( $last_update
            && ( $now - $last_update - RT->config->get('auto_logoff') ) > 0 )
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
            username    => Jifty->web->request->arguments->{'user'},
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
        || Jifty->web->request->path =~ RT->config->get('web_no_auth_regex')
        || Jifty->web->request->path =~ m{^/Elements/Header$}
        || Jifty->web->request->path =~ m{^/Elements/Footer$}
        || Jifty->web->request->path =~ m{^/Elements/Logo$}
        || Jifty->web->request->path =~ m{^/__jifty/test_warnings$}
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
            Jifty->web->redirect( Jifty->web->url . "SelfService/Display.html?id=" . get('id') );
        }

        # otherwise, drop the user at the SelfService default page
        elsif ( $path !~ '^(/+)SelfService/' ) {
            Jifty->web->redirect( Jifty->web->url . "SelfService/" );
        }
    }

}

before qr/.*/ => run {

    my $args = Jifty->web->request->arguments;

    # This code canonicalizes time inputs in hours into minutes
    foreach my $field ( keys %$args ) {
        next unless $field =~ /^(.*)-TimeUnits$/i && $args->{$1};
        my $local = $1;
        $args->{$local} =~ s{\b (?: (\d+) \s+ )? (\d+)/(\d+) \b}
                      {($1 || 0) + $3 ? $2 / $3 : 0}xe;
        if ( $args->{$field} && $args->{$field} =~ /hours/i ) {
            $args->{$local} *= 60;
        }
        delete $args->{$field};
    }
};

after qr/.*/ => run {
    RT::Interface::Web::Handler::cleanup_request();
};

on qr{^/$} => run {
    if (Jifty->config->framework('SetupMode')) {
        Jifty->find_plugin('Jifty::Plugin::SetupWizard')
            or die "The SetupWizard plugin needs to be used with SetupMode";

        show '/__jifty/admin/setupwizard';
    }

    # Make them log in first, otherwise they'll appear to be logged in
    # for one click as RT_System
    # Instead of this, we may want to log them in automatically as the
    # root user as a convenience
    tangent '/login' if !Jifty->web->current_user->id
                     || Jifty->web->current_user->id == RT->system_user->id;

    show '/index.html';
};

on qr{^/Dashboards/(\d+)} => run {
    Jifty->web->request->argument( id => $1 );
    show( '/Dashboards/Render.html' );
};

on qr{^/Ticket/Graphs/(\d+)} => run {
    Jifty->web->request->argument( id => $1 );
    show( '/Ticket/Graphs/Render' );
};

before qr{^/Search/Build.html} => run {
    my $querystring      = '';
    my $selected_clauses = Jifty->web->request->argument('clauses');
    my ( $saved_search, $current_search, $results ) = RT::Interface::Web::QueryBuilder->setup_query();

    my $tree = RT::Interface::Web::QueryBuilder::Tree->new('AND');
    push @$results, $tree->parse_sql( query => $current_search->{query} );

    my $current_values
        = [ ( $tree->get_displayed_nodes() )[ ref $selected_clauses ? @$selected_clauses : $selected_clauses ] ];

    push @$results, RT::Interface::Web::QueryBuilder->process_query( $tree, $current_values );

    my $queues       = $tree->get_referenced_queues;
    my $parsed_query = $tree->get_query_option_list($current_values);

    $current_search->{'query'} = join ' ', map $_->{'TEXT'}, @$parsed_query;

    #  Deal with format changes
    my ( $available_columns, $current_format );
    ( $current_search->{'format'}, $available_columns, $current_format )
        = RT::Interface::Web::QueryBuilder->build_format_string(
        %{ Jifty->web->request->arguments },
        queues => $queues,
        format => $current_search->{'format'}
        );

    # if we're asked to save the current search, save it
    push @$results, RT::Interface::Web::QueryBuilder->save_search( $current_search, $saved_search )
        if ( Jifty->web->request->argument('saved_search_save') || Jifty->web->request->argument('saved_search_copy') );

    #  Push the updates into the session so we don't lose 'em
    Jifty->web->session->set( 'CurrentSearchHash', { %$saved_search, %$current_search, } );

    #  Build a query_string for the tabs
    if ( Jifty->web->request->argument('new_query') ) {
        $querystring = 'new_query=1';
    } elsif ( $current_search->{'query'} ) {
        $querystring = RT::Interface::Web->format_query_params(%$current_search);
    }

    Jifty->web->redirect( Jifty->web->url . "Search/Results.html?" . $querystring )
        if ( Jifty->web->request->argument('do_search') );

    set current_search    => $current_search;
    set current_format    => $current_format;
    set available_columns => $available_columns;
    set saved_search      => $saved_search;
    set results           => $results;
    set parsed_query      => $parsed_query;
    set querystring       => $querystring;
    set queues            => $queues;

};



# Backward compatibility with old RT URLs

before '/NoAuth/Logout.html' => run { redirect '/logout' };

1;

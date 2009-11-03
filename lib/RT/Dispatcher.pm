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

sub page_nav {
	return Jifty->web->page_navigation();
}


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
            username => Jifty->web->request->arguments->{'user'},
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

    # This code canonicalize_s time inputs in hours into minutes
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
    if ( Jifty->config->framework('SetupMode') ) {
        Jifty->find_plugin('Jifty::Plugin::SetupWizard')
            or die "The SetupWizard plugin needs to be used with SetupMode";

        show '/__jifty/admin/setupwizard';
    }

    # Make them log in first, otherwise they'll appear to be logged in
    # for one click as RT_System
    # Instead of this, we may want to log them in automatically as the
    # root user as a convenience
    tangent '/login'
        if !Jifty->web->current_user->id
            || Jifty->web->current_user->id == RT->system_user->id;

    show '/index.html';
};

on qr{^/Dashboards/(\d+)} => run {
    Jifty->web->request->argument( id => $1 );
    show('/Dashboards/Render.html');
};

on qr{^/Ticket/Graphs/(\d+)} => run {
    Jifty->web->request->argument( id => $1 );
    show('/Ticket/Graphs/Render');
};

before qr{.*} => run {
    Jifty->web->navigation->child( _('Homepage'),      url => '/' );
    Jifty->web->navigation->child( _('Simple Search'), url => '/Search/Simple.html' );
    Jifty->web->navigation->child( _('Tickets'),       url => '/Search/Build.html' );
    my $tools = Jifty->web->navigation->child( _('Tools'), url => '/Tools/index.html' );
    $tools->child( _('Dashboards'), url => '/Dashboards/index.html' );

    my $reports = $tools->child( _('Reports'), url => '/Tools/Reports/index.html' );
    $reports->child( _('Resolved by owner'),       url => '/Tools/Reports/ResolvedByOwner.html', );
    $reports->child( _('Resolved in date range'),  url => '/Tools/Reports/ResolvedByDates.html', );
    $reports->child( _('Created in a date range'), url => '/Tools/Reports/CreatedByDates.html', );

    $tools->child( _('My Day'), url => '/Tools/MyDay.html' );

    if (   Jifty->web->current_user->user_object
        && Jifty->web->current_user->has_right( right => 'ShowConfigTab', object => RT->system ) )
    {
        my $admin = Jifty->web->navigation->child( Config => label => _('Configuration'), url => '/Admin/' );
        $admin->child( _('Users'),         url => '/Admin/Users/', );
        $admin->child( _('Groups'),        url => '/Admin/Groups/', );
        $admin->child( _('Queues'),        url => '/Admin/Queues/', );
        $admin->child( _('Custom Fields'), url => '/Admin/CustomFields/', );
        $admin->child( _('Rules'),         url => '/admin/rules/', );

        my $admin_global = $admin->child( _('Global'), url => '/Admin/Global/', );

        $admin_global->child( _('Templates'), url => '/Admin/Global/Templates.html', );
        my $workflows = $admin_global->child( _('Workflows'), url => '/Admin/Global/Workflows/index.html', );
        {
            $workflows->child( _('Overview')     => url => "/Admin/Global/Workflows/index.html" );
            $workflows->child( _('Localization') => url => "/Admin/Global/Workflows/Localization.html" );
            $workflows->child( _('Mappings')     => url => "/Admin/Global/Workflows/Mappings.html" );
        }

        my $cfadmin = $admin_global->child( _('Custom Fields'), url => '/Admin/Global/CustomFields/index.html', );
        {
            $cfadmin->child(
                _('Users') => text => _('Select custom fields for all users'),
                url        => 'Admin/Global/CustomFields/Users.html'
            );

            $cfadmin->child(
                _('Groups') => text => _('Select custom fields for all user groups'),
                url         => 'Admin/Global/CustomFields/Groups.html'
            );

            $cfadmin->child(
                _('Queues') => text => _('Select custom fields for all queues'),
                url         => 'Admin/Global/CustomFields/Queues.html'
            );

            $cfadmin->child(
                _('Tickets') => text => _('Select custom fields for tickets in all queues'),
                url => 'Admin/Global/CustomFields/Queue-Tickets.html'
            );

            $cfadmin->child(
                _('Ticket Transactions') => text => _('Select custom fields for transactions on tickets in all queues'),
                url => 'Admin/Global/CustomFields/Queue-Transactions.html'
            );

        }

        $admin_global->child( _('Group rights'),   url => '/Admin/Global/GroupRights.html', );
        $admin_global->child( _('User rights'),    url => '/Admin/Global/UserRights.html', );
        $admin_global->child( _('RT at a glance'), url => '/Admin/Global/MyRT.html', );
        $admin_global->child( _('Jifty'),          url => '/Admin/Global/Jifty.html', );
        $admin_global->child( _('System'),         url => '/Admin/Global/System.html', );

        my $admin_tools = $admin->child( _('Tools'), url => '/Admin/Tools/', );
        $admin_tools->child( _('System Configuration'), url => '/Admin/Tools/Configuration.html', );
        $admin_tools->child( _('Shredder'),             url => '/Admin/Tools/Shredder', );
    }
    if (Jifty->web->current_user->user_object
        && Jifty->web->current_user->has_right(
            right  => 'ModifySelf',
            object => RT->system
        )
        )
    {
        my $prefs = Jifty->web->navigation->child( _('Preferences'), url => '/Prefs/Other.html' );

        $prefs->child( _('Settings'),       url => '/Prefs/Other.html', );
        $prefs->child( _('About me'),       url => '/User/Prefs.html', );
        $prefs->child( _('Search options'), url => '/Prefs/SearchOptions.html', );
        $prefs->child( _('RT at a glance'), url => '/Prefs/MyRT.html', );
    }

    if (   Jifty->web->current_user->user_object
        && Jifty->web->current_user->has_right( right => 'ShowApprovalsTab', object => RT->system ) )
    {
        Jifty->web->navigation->child( _('Approval'), url => '/Approvals/' );
    }
};

before qr'Dashboards/(\d*)?' => sub {
	page_nav->child( _('Select'), url => "/Dashboards/index.html" );
	require RT::Dashboard; # not a record class, so not autoloaded :/
    if ( RT::Dashboard->new->_privacy_objects( create => 1 ) ) {
        page_nav->child( _('Create') => url => "/Dashboards/Modify.html?create=1" );
    }

    if ( my $id = ($1 || Jifty->web->request->argument('id') )) {
        my $obj = RT::Dashboard->new();
        $obj->load_by_id($id);
        if ( $obj and $obj->id ) {
            my $tabs = page_nav->child( "this" => label => $obj->name, url    => "/Dashboards/Modify.html?id=" . $obj->id);
            $tabs->child( _('Basics'),       url => "/Dashboards/Modify.html?id=" . $obj->id );
            $tabs->child( _('Queries'),      url => "/Dashboards/Queries.html?id=" . $obj->id );
            $tabs->child( _('Subscription'), url => "/Dashboards/Subscription.html?dashboard_id=" . $obj->id ) if $obj->current_user_can_subscribe;
            $tabs->child( _('Show'), url => "Dashboards/" . $obj->id . "/" . $obj->name )

        }
    }
};


before '/SelfService' => sub {

    my $queues = RT::Model::QueueCollection->new();
    $queues->find_all_rows;

    my $queue_count = 0;
    my $queue_id    = 1;

    while ( my $queue = $queues->next ) {
        next unless $queue->current_user_has_right('CreateTicket');
        $queue_id = $queue->id;
        $queue_count++;
        last if ( $queue_count > 1 );
    }

	my $TOP = Jifty->web->navigation();

	$TOP->child( _('Open tickets'),   url => '/SelfService/', );
    $TOP->child( _('Closed tickets'), url => '/SelfService/Closed.html', );
    if ( $queue_count > 1 ) {
        $TOP->child( _('New ticket'), url => '/SelfService/CreateTicketInQueue.html' );
    } else {
        $TOP->child( _('New ticket'), url => '/SelfService/Create.html?queue=' . $queue_id );
    }

    if (Jifty->web->current_user->has_right( right  => 'ModifySelf', object => RT->system)) {
        $TOP->child( _('Preferences'), url => '/SelfService/Prefs.html' );
    }

	# XXX TODO RENDER GOTO TICKET WIDGET
	#Jifty->web->navigation->child( B =>  html => $m->scomp('GotoTicket'))
};

before 'Admin/Queues' => sub {
        if ( Jifty->web->current_user->has_right( object => RT->system, right => 'AdminQueue' ) ) {
            page_nav->child( _('Select'), url => "/Admin/Queues/" );
            page_nav->child( _('Create'), url       => "/Admin/Queues/Modify.html?create=1");
        }
    if ( my $id = Jifty->web->request->argument('id') ) {
        my $queue_obj = RT::Model::Queue->new();
        $queue_obj->load($id);

        my $queue = page_nav->child( $queue_obj->name => url => "/Admin/Queues/Modify.html?id=" . $id );
        $queue->child( _('Basics'),    url => "/Admin/Queues/Modify.html?id=" . $id );
        $queue->child( _('Watchers'),  url => "/Admin/Queues/People.html?id=" . $id );
        $queue->child( _('Templates'), url => "/Admin/Queues/Templates.html?id=" . $id );

        $queue->child( _('Ticket Custom Fields'), url => '/Admin/Queues/CustomFields.html?sub_type=RT::Model::Ticket&id=' . $id );

        $queue->child( _('Transaction Custom Fields'),
            url => '/Admin/Queues/CustomFields.html?sub_type=RT::Model::Ticket-RT::Model::Transaction&id=' . $id );

        $queue->child( _('Group rights'), url => "/Admin/Queues/GroupRights.html?id=" . $id );
        $queue->child( _('User rights'),  url => "/Admin/Queues/UserRights.html?id=" . $id );
    }
};

before '/Admin/Users' => sub {
if (Jifty->web->current_user->has_right( object => RT->system, right => 'AdminUsers')) {
page_nav->child(_('Select'), url => "/Admin/Users/");
page_nav->child(_('Create'), url => "/Admin/Users/Modify.html?create=1", separator => 1);
}
    if ( my $id = Jifty->web->request->argument('id') ) {
	warn "loading user $id";
        my $obj = RT::Model::User->new();
        $obj->load($id);
		my $tabs = page_nav->child('current' => label => $obj->name, url => "/Admin/Users/Modify.html?id=".$id,);
	       $tabs->child(_('Basics'), url => "/Admin/Users/Modify.html?id=".$id);
	       $tabs->child(_('Memberships'), url => "/Admin/Users/Memberships.html?id=".$id);
	       $tabs->child(_('History'), url => "/Admin/Users/History.html?id=".$id);
	       $tabs->child(_('RT at a glance'), url => "/Admin/Users/MyRT.html?id=".$id);
    if ( RT->config->get('gnupg')->{'enable'} ) {
			$tabs->child(_('GnuPG'), url  => "/Admin/Users/GnuPG.html?id=".$id);
        }
    }

};

before 'Admin/Groups' => sub {

page_nav->child( _('Select') => url  => "/Admin/Groups/");
page_nav->child( _('Create') => url      => "/Admin/Groups/Modify.html?create=1", separator => 1);
    if ( my $id = Jifty->web->request->argument('id') ) {
        my $obj = RT::Model::User->new();
        $obj->load($id);
        my $tabs = page_nav->child( $obj->name, url => "/Admin/CustomFields/Modify.html?id=" . $id );
        $tabs->child( _('Basics') => url  => "/Admin/Groups/Modify.html?id=" . $obj->id );
        $tabs->child( _('Members') => url  => "/Admin/Groups/Members.html?id=" . $obj->id );
        $tabs->child( _('Group rights') => url  => "/Admin/Groups/GroupRights.html?id=" . $obj->id );
        $tabs->child( _('User rights') => url  => "/Admin/Groups/UserRights.html?id=" . $obj->id );
        $tabs->child( _('History') => url  => "/Admin/Groups/History.html?id=" . $obj->id );
    }
};


before 'Admin/CustomFields/' => sub {
    if ( Jifty->web->current_user->has_right( object => RT->system, right => 'AdminCustomField' ) ) {
        page_nav->child( _('Select'), url => "/Admin/CustomFields/" );
        page_nav->child(
            _('Create') =>
            url       => "/Admin/CustomFields/Modify.html?create=1",
        );

    }
    if ( my $id = Jifty->web->request->argument('id') ) {
        my $obj = RT::Model::CustomField->new();
        $obj->load($id);
        my $tabs = page_nav->child( $obj->name, url => "/Admin/CustomFields/Modify.html?id=" . $id );

        $tabs->child( _('Basics')       => url => "/Admin/CustomFields/Modify.html?id=" . $id );
        $tabs->child( _('Group rights') => url => "/Admin/CustomFields/GroupRights.html?id=" . $id );
        $tabs->child( _('User rights')  => url => "/Admin/CustomFields/UserRights.html?id=" . $id );

        if ( $obj->lookup_type =~ /^RT::Model::Queue-/io ) {
            $tabs->child( _('Applies to'), url => "/Admin/CustomFields/Objects.html?id=" . $id );
        }

    }

};

before 'Admin/Global/Workflows' => sub {
    if ( my $id = Jifty->web->request->argument('name') ) {

		my $base = '/Admin/Global/Workflows';

        my $schema = RT::Workflow->new->load($id);

        if ($schema) {
            my $qs_name = URI->new->query_form( name => $schema->name );
            my $workflow = page_nav->child( $schema->name, url => "$base/Summary.html?$qs_name" );
            $workflow->child( _("Summary")     => url => "$base/Summary.html?$qs_name" );
            $workflow->child( _("Statuses")    => url => "$base/Statuses.html?$qs_name" );
            $workflow->child( _("Transitions") => url => "$base/Transitions.html?$qs_name" );
            $workflow->child( _("Interface")   => url => "$base/Interface.html?$qs_name" );
        }
    }
    };

before 'Admin/Rules' => sub {
        page_nav->child(_('Select'), url  => "/Admin/Rules/");
        page_nav->child(_('Create'), url  => "/Admin/Rules/Modify.html?create=1");
};

before qr'(?:Ticket|Search)/' => sub {
	my $self = shift;
    if ( my $id = Jifty->web->request->argument('id') ) {
        my $obj = RT::Model::Ticket->new();
        $obj->load($id);

        my $tabs = page_nav->child(
            "#" . $id => class => "currentnav",
            url       => "/Ticket/Display.html?id=" . $id
        );

        $tabs->child( _('Display') => url => "/Ticket/Display.html?id=" . $id );

        $tabs->child( _('History') => url => "/Ticket/History.html?id=" . $id );
        $tabs->child( _('Basics')  => url => "/Ticket/Modify.html?id=" . $id );

        $tabs->child( _('Dates') => url => "/Ticket/ModifyDates.html?id=" . $id );
        $tabs->child( _('People'), url => "/Ticket/ModifyPeople.html?id=" . $id );
        $tabs->child( _('Links'),  url => "/Ticket/ModifyLinks.html?id=" . $id );
        $tabs->child( _('Jumbo'),  url => "/Ticket/ModifyAll.html?id=" . $id );

        my %can = ( ModifyTicket => $obj->current_user_has_right('ModifyTicket') );

        if ( $can{'ModifyTicket'} or $obj->current_user_has_right('ReplyToTicket') ) {
            $tabs->child( _('Reply'), url => "/Ticket/Update.html?action=respond&id=" . $id );
        }

        if ( $can{'ModifyTicket'} ) {
            my $current = $obj->status;
            my $schema  = $obj->queue->status_schema;
            my $i       = 1;
            foreach my $next ( $schema->transitions($current) ) {
                my $action = $schema->transition_action( $current => $next );
                next if $action eq 'hide';

                my $url = 'Ticket/';
                if ($action) {

                #XXX TODO
                #$url .= "Update.html?" . URI->new->query_form( action => $action, default_status => $next, id => $id );
                } else {

                    #XXX TODO
                    # $url .= "Display.html?" .URI->new->query_form(Status => $next, id => $id );
                }
                $tabs->child( _( $schema->transition_label( $current => $next ) ) => url => $url );
            }

        }
        if ( $obj->current_user_has_right('OwnTicket') ) {
            if ( $obj->owner_obj->id == RT->nobody->id ) {
                $tabs->child( _('Take') => url => "/Ticket/Display.html?action=take&id=" . $id )
                    if ( $can{'ModifyTicket'} or $obj->current_user_has_right('TakeTicket') );
            } elsif ( $obj->owner_obj->id != Jifty->web->current_user->id ) {
                $tabs->child( _('Steal') => url => "/Ticket/Display.html?action=steal&id=" . $id )
                    if ( $can{'ModifyTicket'}
                    or $obj->current_user_has_right('StealTicket') );
            }
        }

        if ( $can{'ModifyTicket'} or $obj->current_user_has_right('CommentOnTicket') ) {
            $tabs->child( _('Comment') => url => "/Ticket/Update.html?action=comment&id=" . $id );
        }

        # $actions->{'_ZZ'} = { html => $m->scomp( '/Ticket/Elements/Bookmark', id => $obj->id ), };

        my $id = $obj->id();

        if ( defined Jifty->web->session->get('tickets') ) {

            # we have to update session data if we get new ItemMap
            my $updatesession = 1 unless ( Jifty->web->session->get('tickets')->{'item_map'} );

            my $item_map = Jifty->web->session->get('tickets')->item_map;

            if ($updatesession) {
                Jifty->web->session->get('tickets')->prep_for_serialization();
            }

            # Don't display prev links if we're on the first ticket
            if ( $item_map->{$id}->{prev} ) {
                page_nav->child(
                    '<< ' . _('First') => class => "nav",
                    url                => "Ticket/Display.html?id=" . $item_map->{first}
                );
                page_nav->child(
                    '< ' . _('Prev') => class => "nav",
                    url              => "Ticket/Display.html?id=" . $item_map->{$id}->{prev}
                );

                # Don't display next links if we're on the last ticket
                if ( $item_map->{$id}->{next} ) {
                    page_nav->child(
                        _('next') . ' >' => class => "nav",
                        url              => "Ticket/Display.html?id=" . $item_map->{$id}->{next}
                    );
                    page_nav->child(
                        _('Last') . ' >>' => class => "nav",
                        url               => "Ticket/Display.html?id=" . $item_map->{last}
                    );
                }
            }

            my $args      = '';
            my $has_query = '';
            my %query_args;

            my $search = Jifty->web->session->get('CurrentSearchHash') || {};
            my $search_id = Jifty->web->request->argument('saved_search_id') || $search->{'searchid'} || '';

            $has_query = 1 if ( Jifty->web->request->argument('query') or $search->{'query'} );

            %query_args = (

                saved_search_id => ( $search_id eq 'new' ) ? undef : $search_id,
                query         => Jifty->web->request->argument('query')         || $search->{'query'},
                format        => Jifty->web->request->argument('format')        || $search->{'format'},
                order_by      => Jifty->web->request->argument('order_by')      || $search->{'order_by'},
                order         => Jifty->web->request->argument('order')         || $search->{'order'},
                page          => Jifty->web->request->argument('page')          || $search->{'page'},
                rows_per_page => Jifty->web->request->argument('rows_per_page') || $search->{'rows_per_page'}
            );

            $args = "?" . URI->new->query_form(%query_args);

            $search->child( _('New Search')  => url => "Search/Build.html?NewQuery=1" );
            $search->child( _('Edit Search') => url => "Search/Build.html" . ( ($has_query) ? $args : '' ) );
            $search->child( _('Advanced')    => url => "Search/Edit.html$args" );

            if ($has_query) {
                if ($self->{path} =~ qr|^Search/Results.html| &&    #XXX TODO better abstraction
                    Jifty->web->current_user->has_right( right => 'SuperUser', object => RT->system )
                    )
                {
                    my $shred_args = URI->new->query_param(
                        search          => 1,
                        plugin          => 'Tickets',
                        'Tickets:query' => $query_args{'query'},
                        'Tickets:limit' => $query_args{'rows'}
                    );

                    page_nav->child( 'shredder' =>  label => _('Shredder'), url => 'Admin/Tools/Shredder/?' . $shred_args );
                }

                page_nav->child( _('Show Results') => url => "Search/Results.html$args" );

                page_nav->child( _('Bulk Update') => url => "Search/Bulk.html$args" );

            }
        }
    }
};

before 'User/Group' => sub {
    if ( my $id = Jifty->web->request->argument('id') ) {
        my $obj = RT::Model::User->new();
        $obj->load($id);
        my $group = page_nav->child( url => "/User/Groups/Modify.html?id=" . $obj->id );
        $group->child( _('Basics'),  url => "/User/Groups/Modify.html?id=" . $obj->id );
        $group->child( _('Members'), url => "/User/Groups/Members.html?id=" . $obj->id );

    }
    page_nav( _('Select group') => url => "/User/Groups/index.html" );
    page_nav( _('New group') => url => "/User/Groups/Modify.html?create=1", separator => 1 );

};

before 'Prefs' => sub {
	my $tabs;
	my $searches = RT::System->new->saved_searches();

	page_nav->child(  'Quick search' => label => _('Quick search'), url => '/Prefs/Quicksearch.html');

	for my $search (@$searches) {
	page_nav->child(
        $search->[0],
        url  => "/Prefs/Search.html?" .URI->new->query_form( name => ref($search->[1]).'-'.$search->[1]->id));
    }
};


under '/' => sub {

# Top level tabs /Elements/Tabs
warn "Adding create ticket and simplesearch are todo";
my $basetopactions = {
	a => { html => '',#$m->scomp('/Elements/CreateTicket')
		},
	b => { html => ''#$m->scomp('/Elements/SimpleSearch')
		}
	};

};

# Backward compatibility with old RT URLs

before '/NoAuth/Logout.html' => run { redirect '/logout' };

1;

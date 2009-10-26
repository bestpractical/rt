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
        $admin->child( _('Users'),  url => '/Admin/Users/', );
        $admin->child( _('Groups'), url => '/Admin/Groups/', );
        $admin->child( _('Queues'),        url => '/Admin/Queues/', );
        $admin->child( _('Custom Fields'), url => '/Admin/CustomFields/', );
        $admin->child( _('Rules'),         url => '/admin/rules/', );

        my $admin_global = $admin->child( _('Global'), url => '/Admin/Global/', );

        $admin_global->child( _('Templates'), url => '/Admin/Global/Templates.html', );
       my $workflows =  $admin_global->child( _('Workflows'), url => '/Admin/Global/Workflows/index.html', );
		{
    $workflows->child( _('Select') .'/'. _('Create') =>  url => "/Admin/Global/Workflows/index.html");
    $workflows->child( _('Localization') =>  url => "/Admin/Global/Workflows/Localization.html");
    $workflows->child( _('Mappings') => url => "/Admin/Global/Workflows/Mappings.html");
		}


        $admin_global->child( _('Custom Fields'), url => '/Admin/Global/CustomFields/index.html', );
        $admin_global->child( _('Group rights'),   url => '/Admin/Global/GroupRights.html', );
        $admin_global->child( _('User rights'),    url => '/Admin/Global/UserRights.html', );
        $admin_global->child( _('RT at a glance'), url => '/Admin/Global/MyRT.html', );
        $admin_global->child( _('Jifty'),          url => '/Admin/Global/Jifty.html', );
        $admin_global->child( _('System'),         url => '/Admin/Global/System.html', );

        my $admin_tools = $admin->child( _('Tools'), url => '/Admin/Tools/',);
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

        $prefs->child( _('Settings'), url => '/Prefs/Other.html', );
        $prefs->child( _('About me'),       url => '/User/Prefs.html', );
        $prefs->child( _('Search options'), url => '/Prefs/SearchOptions.html', );
        $prefs->child( _('RT at a glance'), url => '/Prefs/MyRT.html', );
    }

    if (Jifty->web->current_user->user_object && Jifty->web->current_user->has_right( right  => 'ShowApprovalsTab', object => RT->system)) {
        Jifty->web->navigation->child( _('Approval'), url => '/Approvals/' );
    }
};

before 'Dashboards/' => sub {
    my $dashboard_list = Jifty->web->page_navigation( _('Select'), url => "/Dashboards/index.html" );

    if ( RT::Dashboard->new->_privacy_objects( create => 1 )) {
        Jifty->web->page_navigation->child( _('Create') => url       => "/Dashboards/Modify.html?create=1");
    }
};


before '/SelfService' => sub {

    my $queues = RT::Model::QueueCollection->new( current_user => Jifty->web->current_user );
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
	#Jifty->web->navigation->child( B =>  html => $m->scomp('GotoTicket')
};

before 'Admin/Queues' => sub {
    my $tabs;
    if ( my $id = Jifty->web->request->argument('id') ) {
        my $queue_obj = RT::Model::Queue->new();
        $queue_obj->load($id);

        if ( Jifty->web->current_user->has_right( object => RT->system, right => 'AdminQueue' ) ) {
            Jifty->web->page_navigation->child( _('Select'), url => "/Admin/Queues/" );
            Jifty->web->page_navigation->child( _('Create'), url       => "/Admin/Queues/Modify.html?create=1");
        }
        my $queue = Jifty->web->page_navigation->child( $queue_obj->name => url => "/Admin/Queues/Modify.html?id=" . $id );
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

before 'Admin/Users' => sub {
if (Jifty->web->current_user->has_right( object => RT->system, right => 'AdminUsers')) {
Jifty->web->navigation->child(_('Select'), url => "/Admin/Users/");
Jifty->web->navigation->child(_('Create'), url => "/Admin/Users/Modify.html?create=1", separator => 1);
}
    if ( my $id = Jifty->web->request->argument('id') ) {
        my $obj = RT::Model::User->new();
        $obj->load($id);
		my $user = $user_admin->child($obj->Name, url => "/Admin/Users/Modify.html?id=".$id,);
	       $user->child(_('Basics'), url => "/Admin/Users/Modify.html?id=".$id);
	       $user->child(_('Memberships'), url => "/Admin/Users/Memberships.html?id=".$id);
	       $user->child(_('History'), url => "/Admin/Users/History.html?id=".$id);
	       $user->child(_('RT at a glance'), url => "/Admin/Users/MyRT.html?id=".$id);
	}
    if ( RT->config->get('gnupg')->{'enable'} ) {
Jifty->web->navigation->child(_('GnuPG'), url  => "Admin/Users/GnuPG.html?id=".$id,
        };
    }

};

before 'Admin/Groups' => sub {

Jifty->web->page_navigation->child( _('Select') => url  => "Admin/Groups/");
Jifty->web->page_navigation->child( _('Create') => url      => "Admin/Groups/Modify.html?create=1", separator => 1);
    if ( my $id = Jifty->web->request->argument('id') ) {
        my $obj = RT::Model::User->new();
        $obj->load($id);
        $tabs = Jifty->web->page_navigation->child( $obj->name, url => "Admin/CustomFields/Modify.html?id=" . $id );
        $tabs->child( _('Basics') => url  => "Admin/Groups/Modify.html?id=" . $obj->id );
        $tabs->child( _('Members') => url  => "Admin/Groups/Members.html?id=" . $obj->id );
        $tabs->child( _('Group rights') => url  => "Admin/Groups/GroupRights.html?id=" . $obj->id );
        $tabs->child( _('User rights') => url  => "Admin/Groups/UserRights.html?id=" . $obj->id );
        $tabs->child( _('History') => url  => "Admin/Groups/History.html?id=" . $obj->id );
    }
};
before 'Admin/CustomFields/' => sub {
    if ( Jifty->web->current_user->has_right( object => RT->system, right => 'AdminCustomField' ) ) {
        Jifty->web->page_navigation->child( _('Select'), url => "/Admin/CustomFields/" );
        Jifty->web->page_navigation->child(
            _('Create') =>
            url       => "/Admin/CustomFields/Modify.html?create=1",
        );

    }
    if ( my $id = Jifty->web->request->argument('id') ) {
        my $obj = RT::Model::CustomField->new();
        $obj->load($id);
        $cftabs = Jifty->web->page_navigation->child( $obj->name, url => "Admin/CustomFields/Modify.html?id=" . $id );

        $cftabs->child( _('Basics')       => url => "Admin/CustomFields/Modify.html?id=" . $id );
        $cftabs->child( _('Group rights') => url => "Admin/CustomFields/GroupRights.html?id=" . $id );
        $cftabs->child( _('User rights')  => url => "/Admin/CustomFields/UserRights.html?id=" . $id );

        if ( $obj->lookup_type =~ /^RT::Model::Queue-/io ) {
            $cftabs->child( _('Applies to'), url => "Admin/CustomFields/Objects.html?id=" . $id );
        }

    }

};


before 'User/Group' => sub {

    if ( my $id = Jifty->web->request->argument('id') ) {
        my $obj = RT::Model::User->new();
        $obj->load($id);
        my $group = Jifty->web->page_navigation->child( url => "/User/Groups/Modify.html?id=" . $obj->id );
        $group->child( _('Basics'),  url => "/User/Groups/Modify.html?id=" . $obj->id );
        $group->child( _('Members'), url => "/User/Groups/Members.html?id=" . $obj->id );

    }
    Jifty->web->page_navigation( _('Select group') => url => "/User/Groups/index.html" );
    Jifty->web->page_navigation( _('New group') => url => "/User/Groups/Modify.html?create=1", separator => 1 );

};
=for later Navigation

# Top level tabs /Elements/Tabs
my $basetopactions = {
	a => { html => $m->scomp('/Elements/CreateTicket')
		},
	b => { html => $m->scomp('/Elements/SimpleSearch')
		}
	};



# /Tools/Dashboards tabs
if ( $dashboard_obj and $dashboard_obj->id ) {
			$dash =	Jifty->web->navigation->child( "this" => label   => $dashboard_obj->name, url    => "Dashboards/Modify.html?id=" . $dashboard_obj->id);
            $dash->child(_('Basics'), url  => "Dashboards/Modify.html?id=" . $dashboard_obj->id);
            $dash->child(_('Queries'), url  => "Dashboards/Queries.html?id=" . $dashboard_obj->id);
            $dash->child(_('Subscription'), url  => "Dashboards/Subscription.html?dashboard_id=" . $dashboard_obj->id);
            $dash->child(_('Show'), url  => "Dashboards/" . $dashboard_obj->id . "/".$dashboard_obj->name)

        }

    delete $tabs->{"this"}{"subtabs"}{"c_Subscription"} unless $dashboard_obj->current_user_can_subscribe;

    $tabs->{"this"}{"subtabs"}{"z_Preview"}{url} = $real_subtab
        if $real_subtab =~ /Render/
        || $real_subtab =~ /Dashboard\/\d+/;
}




# /SelfService Tabs



# /Admin/CustomFields tabs
#/Admin/Global/Workflows tabs

if ( $schema ) {
    my $qs_name = $m->comp( '/Elements/QueryString', name => $schema->name );

		$workflow = Jifty->web->page_navigation( $schema->name, url => "$base/Summary.html?$qs_name");
            $workflow->child( _("Summary") => url  => "$base/Summary.html?$qs_name");
            $workflow->child( _("Statuses") => url  => "$base/Statuses.html?$qs_name");
            $workflow->child( _("Transitions") => url  => "$base/Transitions.html?$qs_name");
            $workflow->child( _("Interface") => url  => "$base/Interface.html?$qs_name");
        );
    };
}

# /Ticket/Elements/Tabs

my $current_toptab = "Search/Build.html"; my $searchtabs = {};

if ($ticket) {

    my $id = $ticket->id();

    if ( defined Jifty->web->session->get('tickets') ) {

        # we have to update session data if we get new ItemMap
        my $updatesession = 1 unless ( Jifty->web->session->get('tickets')->{'item_map'} );

        my $item_map = Jifty->web->session->get('tickets')->item_map;

        if ($updatesession) {
            Jifty->web->session->get('tickets')->prep_for_serialization();
        }

        # Don't display prev links if we're on the first ticket
        if ( $item_map->{ $ticket->id }->{prev} ) {
Jifty->web->page_navigation->child( '<< ' . _('First') => class => "nav", url  => "Ticket/Display.html?id=" . $item_map->{first});
Jifty->web->page_navigation->child( '< ' . _('Prev') => class => "nav", url  => "Ticket/Display.html?id=" . $item_map->{ $ticket->id }->{prev});

        # Don't display next links if we're on the last ticket
        if ( $item_map->{ $ticket->id }->{next} ) {
            Jifty->web->page_navigation->child(
                _('next') . ' >' => class => "nav",
                url              => "Ticket/Display.html?id=" . $item_map->{ $ticket->id }->{next}
            );
            Jifty->web->page_navigation->child(
                _('Last') . ' >>' => class => "nav",
                url               => "Ticket/Display.html?id=" . $item_map->{last}
            );

            my $ticket = Jifty->web->page_navigation->child(
                "#" . $id => class => "currentnav",
                url       => "Ticket/Display.html?id=" . $ticket->id,
            );

            $ticket->child( _('Display') => url => "Ticket/Display.html?id=" . $id );

            $ticket->child( _('History') => url => "Ticket/History.html?id=" . $id );
            $ticket->child( _('Basics')  => url => "Ticket/Modify.html?id=" . $id );

            $ticket->child( _('Dates') => url => "Ticket/ModifyDates.html?id=" . $id );
            $ticket->child( _('People'), url => "Ticket/ModifyPeople.html?id=" . $id );
            $ticket->child( _('Links'),  url => "Ticket/ModifyLinks.html?id=" . $id );
            $ticket->child( _('Jumbo'),  url => "Ticket/ModifyAll.html?id=" . $id );

        }
    my %can = ( ModifyTicket => $ticket->current_user_has_right('ModifyTicket'));

    if ( $can{'ModifyTicket'} or $ticket->current_user_has_right('ReplyToTicket') ) {
		Jifty->web->navigation->child( _('Reply'), url  => "Ticket/Update.html?action=respond&id=" . $id )
    }

    if ( $can{'ModifyTicket'} ) {
        my $current = $ticket->status;
        my $schema = $ticket->queue->status_schema;
        my $i = 1;
        foreach my $next ( $schema->transitions( $current ) ) {
            my $action = $schema->transition_action( $current => $next );
            next if $action eq 'hide';

            my $url = 'Ticket/';
            if ( $action ) {
                $url .= "Update.html?". $m->comp( '/Elements/QueryString', action => $action, default_status => $next, id => $id);
            } else {
                $url .= "Display.html?". $m->comp( '/Elements/QueryString', Status => $next, id => $id);
            }
			Jifty->web->page_navigation->child( _( $schema->transition_label( $current => $next ) ) => url => $url);
        }
    }

    if ( $ticket->current_user_has_right('OwnTicket') ) {
        if ( $ticket->owner_obj->id == RT->nobody->id ) {
				Jifty->web->page_navigation->child( _('Take') => url  => "Ticket/Display.html?action=take&id=" . $id );
                if $can{'ModifyTicket'}
                    or $ticket->current_user_has_right('TakeTicket');
        } elsif ( $ticket->owner_obj->id != Jifty->web->current_user->id ) {
				Jifty->web->page_navigation->child( _('Steal') => url  => "Ticket/Display.html?action=steal&id=" . $id )
                if $can{'ModifyTicket'}
                    or $ticket->current_user_has_right('StealTicket');
        }
    }

    if (   $can{'ModifyTicket'} or $ticket->current_user_has_right('CommentOnTicket') ) {
Jifty->web->page_navigation->child( _('Comment') => url  => "Ticket/Update.html?action=comment&id=" . $id );
    }

    $actions->{'_ZZ'}
        = { html => $m->scomp( '/Ticket/Elements/Bookmark', id => $ticket->id ),
        };

}

my $args = '';
my $has_query = '';
my %query_args;
my $search = Jifty->web->session->get('CurrentSearchHash') || {};
my $search_id = $ARGS{'saved_search_id'} ||  && ->{'searchid'} || '';

$has_query = 1 if ( $ARGS{'query'} or  && ->{'query'} );


%query_args = (

        saved_search_id => ($search_id eq 'new') ? undef : $search_id,
        query  => $ARGS{'query'}  || $search->{'query'},
        format => $ARGS{'format'} || $search->{'format'},
        order_by => $ARGS{'order_by'} ||  $search->{'order_by'},
        order => $ARGS{'order'} ||  $search->{'order'},
        page  => $ARGS{'page'}  || $search->{'page'},
        rows_per_page  => $ARGS{'rows_per_page'}  || $search->{'rows_per_page'}
    );

    $args = "?" . $m->comp( '/Elements/QueryString', %query_args );

$search->child( _('New Search') => url  => "Search/Build.html?NewQuery=1" );
$search->child( _('Edit Search') => url  => "Search/Build.html" . (($has_query) ? $args : '');
 $search->child( _('Advanced') => url      => "Search/Edit.html$args");


if ($has_query) {

    if ( $current_tab =~ m{Search/Results.html} ) {

        if ( Jifty->web->current_user->has_right( right => 'SuperUser', object => RT->system ) ) {
            my $shred_args = $m->comp(
                '/Elements/QueryString',
                search          => 1,
                plugin          => 'Tickets',
                'Tickets:query' => $query_args{'query');
                'Tickets:limit' => $query_args{'rows'}
            );

Jifty->web->page_navigation->child( _('Shredder') url  => 'Admin/Tools/Shredder/?' . $shred_args );

Jifty->web->page_navigation->child( _('Show Results') => url  => "Search/Results.html$args");

Jifty->web->page_navigation->child( _('Bulk Update') => url  => "Search/Bulk.html$args");

}

# /Admin/Rules
    my $tabs = {


        $rules_admin->child(_('Select'), url  => "Admin/Rules/");
        $rules_admin->child(_('Create'), url  => 'Admin/Rules/Modify.html?create=1');
    };

# /Admin/Users tabs

# Admin/GlobalCustomFields

my $tabs = {



    $cfadmin->child( _('Users') => text  => _('Select custom fields for all users') , url  => 'Admin/Global/CustomFields/Users.html' );

    $cfadmin->child( _('Groups') => text  => _('Select custom fields for all user groups') , url  => 'Admin/Global/CustomFields/Groups.html');

    $cfadmin->child( _('Queues') => text  => _('Select custom fields for all queues') , url  => 'Admin/Global/CustomFields/Queues.html');

    $cfadmin->child( _('Tickets') => text  => _('Select custom fields for tickets in all queues') , url  => 'Admin/Global/CustomFields/Queue-Tickets.html' ;

    $cfadmin->child( _('Ticket Transactions') => text  => _('Select custom fields for transactions on tickets in all queues') , url  => 'Admin/Global/CustomFields/Queue-Transactions.html' =>);

};

# Admin/Groups


# Prefs/
my $tabs;
$searches ||= [$m->comp("/Search/Elements/SearchesForObject", object => RT::System->new())];

$tabs->{a} = { label => _('Quick search'), url => '/Prefs/Quicksearch.html');

for my $search (@$searches) {
Jifty->web->navigation->child(  $search->[0]  =>
        label => $search->[0],
        url  => "Prefs/Search.html?" .$m->comp('/Elements/QueryString', name => ref($search->[1]).'-'.$search->[1]->id),
    };
}


# User/
	     };
=cut

# Now let callbacks add their extra tabs

# Backward compatibility with old RT URLs

before '/NoAuth/Logout.html' => run { redirect '/logout' };

1;

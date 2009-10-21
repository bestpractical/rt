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
    Jifty->web->navigation->child( a => label => _('Homepage'), url => '' );
    Jifty->web->navigation->child(
        ab  => label => _('Simple Search'),
        url => 'Search/Simple.html'
    );
    Jifty->web->navigation->child(
        b   => label => _('Tickets'),
        url => 'Search/Build.html'
    );
    my $tools = Jifty->web->navigation->child( c => label => _('Tools'), url => 'Tools/index.html' );
    $tools->child( a => label => _('Dashboards'), url => 'Dashboards/index.html', );
    my $reports = $tools->child( c => label => _('Reports'), url => 'Tools/Reports/index.html', );
    $reports->child(
        a   => label => _('Resolved by owner'),
        url => 'Tools/Reports/ResolvedByOwner.html',
    );
    $reports->child(
        b   => label => _('Resolved in date range'),
        url => 'Tools/Reports/ResolvedByDates.html',
    );
    $reports->child(
        c   => label => _('Created in a date range'),
        url => 'Tools/Reports/CreatedByDates.html',
    );

    $tools->child( d => label => _('My Day'), url => 'Tools/MyDay.html', );

    if ( Jifty->web->current_user->has_right( right => 'ShowConfigTab', object => RT->system ) ) {
        my $admin = Jifty->web->navigation->child( e => label => _('Configuration'), url => 'Admin/' );
        $admin->child(
            A   => label => _('Users'),
            url => '/Admin/Users/',
        );
        $admin->child(
            B   => label => _('Groups'),
            url => '/Admin/Groups/',
        );
        $admin->child(
            C   => label => _('Queues'),
            url => '/Admin/Queues/',
        );
        $admin->child(
            D   => 'label' => _('Custom Fields'),
            url => '/Admin/CustomFields/',
        );
        $admin->child(
            E   => 'label' => _('Rules'),
            url => '/admin/rules/',
        );
        my $admin_global = $admin->child(
            F   => 'label' => _('Global'),
            url => '/Admin/Global/',
        );

        $admin_global->child(
            B   => label => _('Templates'),
            url => 'Admin/Global/Templates.html',
        );
        $admin_global->child(
            C   => label => _('Workflows'),
            url => 'Admin/Global/Workflows/index.html',
        );

        $admin_global->child(
            F   => label => _('Custom Fields'),
            url => 'Admin/Global/CustomFields/index.html',
        );

        $admin_global->child(
            G   => label => _('Group rights'),
            url => 'Admin/Global/GroupRights.html',
        );
        $admin_global->child(
            H   => label => _('User rights'),
            url => 'Admin/Global/UserRights.html',
        );
        $admin_global->child(
            I   => label => _('RT at a glance'),
            url => 'Admin/Global/MyRT.html',
        );
        $admin_global->child(
            Y   => label => _('Jifty'),
            url => 'Admin/Global/Jifty.html',
        );
        $admin_global->child(
            Z   => label => _('System'),
            url => 'Admin/Global/System.html',
        );

        my $admin_tools = $admin->child(
            G   => 'label' => _('Tools'),
            url => '/Admin/Tools/',
        );
        $admin_tools->child(
            A   => label => _('System Configuration'),
            url => 'Admin/Tools/Configuration.html',
        );
        $admin_tools->child(
            E   => label => _('Shredder'),
            url => 'Admin/Tools/Shredder',
        );
    }
    if (Jifty->web->current_user->has_right(
            right  => 'ModifySelf',
            object => RT->system
        )
        )
    {
        my $prefs = Jifty->web->navigation->child(
            k   => label => _('Preferences'),
            url => 'Prefs/Other.html'
        );

        $prefs->child(
            a   => label => _('Settings'),
            url => 'Prefs/Other.html',
        );

        $prefs->child(
            b   => label => _('About me'),
            url => 'User/Prefs.html',
        );
        $prefs->child(
            f   => label => _('Search options'),
            url => 'Prefs/SearchOptions.html',
        );
        $prefs->child(
            r   => label => _('RT at a glance'),
            url => 'Prefs/MyRT.html',
        );
    }

    if (Jifty->web->current_user->has_right(
            right  => 'ShowApprovalsTab',
            object => RT->system
        )
        )
    {
        Jifty->web->navigation->child(
            p   => label => _('Approval'),
            url => 'Approvals/'
        );
    }
};

=for later Navigation

# Top level tabs /Elements/Tabs
my $basetopactions = {
	a => { html => $m->scomp('/Elements/CreateTicket')
		},
	b => { html => $m->scomp('/Elements/SimpleSearch')
		}
	};




if (!defined $toptabs) {
   $toptabs = $basetabs;
}
if (!defined $topactions) {
   $topactions = $basetopactions;
}

# Now let callbacks add their extra tabs
$m->callback(
    topactions => $topactions,
    toptabs    => $toptabs,
    %ARGS
);

#/Tools tabs
my $tabs = {
};

#/Tools/Reports tabs
my $tabs = {
};




# /Tools/Dashboards tabs
my $tabs;
my $real_subtab = $current_subtab;
if ( $dashboard_obj and $dashboard_obj->id ) {

    my $name = $dashboard_obj->name;

    my $modify  = "Dashboards/Modify.html?id=" . $dashboard_obj->id;
    my $queries = "Dashboards/Queries.html?id=" . $dashboard_obj->id;
    my $render  = "Dashboards/" . $dashboard_obj->id . "/$name";

Jifty->web->navigation->child( "this" =>
        label   => $dashboard_obj->name,
        url    => $modify,
        current_subtab  => $current_subtab,
        Jifty->web->navigation->child( subtabs =>
            Jifty->web->navigation->child( a_Basics =>  label => _('Basics'),
                          url  => $modify,
            );

            Jifty->web->navigation->child( b_Queries =>  label => _('Queries'),
                           url  => $queries,
            );

            Jifty->web->navigation->child( c_Subscription =>  label => _('Subscription'),
                                url  =>
                                    "Dashboards/Subscription.html?dashboard_id=" . $dashboard_obj->id
            );


            Jifty->web->navigation->child( z_Preview =>  label => _('Show'),
                           url  => $render,
            );
        }
    };

    delete $tabs->{"this"}{"subtabs"}{"c_Subscription"}
        unless $dashboard_obj->current_user_can_subscribe;

    $tabs->{"this"}{"subtabs"}{"z_Preview"}{url} = $real_subtab
        if $real_subtab =~ /Render/
        || $real_subtab =~ /Dashboard\/\d+/;

    $current_subtab = $modify;
}

$tabs->{"A"} = { label => _('Select dashboard'),
                 url  => "Dashboards/index.html" };

my $dashboard = RT::Dashboard->new( current_user => Jifty->web->current_user );
my @objects = $dashboard->_privacy_objects(create => 1);

if (@objects) {
Jifty->web->navigation->child( "B" =>  label     => _('New dashboard'),
                     url      => "Dashboards/Modify.html?create=1",
                     separator => 1 };
}




# /SelfService Tabs

<a name="skipnav" id="skipnav" accesskey="8"></a>
<%INIT>
my $queues = RT::Model::QueueCollection->new( current_user => Jifty->web->current_user );
$queues->find_all_rows;

my $queue_count = 0;
my $queue_id = 1;

while (my $queue = $queues->next) {
  next unless $queue->current_user_has_right('CreateTicket');
  $queue_id = $queue->id;
  $queue_count++;
  last if ($queue_count > 1);
}

if ($label) {
$label = _("RT Self Service") . " / " . $label;
} else {
$label = _("RT Self Service");

}
my ($tab);
my $tabs = { Jifty->web->navigation->child( A =>  label => _('Open tickets'),
                        url => 'SelfService/',
                      );
             Jifty->web->navigation->child( B =>  label => _('Closed tickets'),
                         url => 'SelfService/Closed.html',
                       );
           };

if ($queue_count > 1) {
Jifty->web->navigation->child( C =>  label => _('New ticket'),
                       url => 'SelfService/CreateTicketInQueue.html'
                       };
} else {
Jifty->web->navigation->child( C =>  label => _('New ticket'),
                       url => 'SelfService/Create.html?queue=' . $queue_id
                       };
}

if (Jifty->web->current_user->has_right( right => 'ModifySelf',
				       object => RT->system )) {
Jifty->web->navigation->child( Z =>  label => _('Preferences'),
		       url => 'SelfService/Prefs.html'
		       };
}

my $actions = {
	Jifty->web->navigation->child( B =>  html => $m->scomp('GotoTicket')
		}
	};




# /Admin/CustomFields tabs

if ($id) {
    my $cf = RT::Model::CustomField->new( current_user => Jifty->web->current_user );
    $cf->load($id);
    $tabs = {
        Jifty->web->navigation->child( this =>
            label => $cf->name,
            url  => "Admin/CustomFields/Modify.html?id=" . $id,
            current_subtab => $current_tab,

            Jifty->web->navigation->child( subtabs =>

                Jifty->web->navigation->child( C =>  label => _('Basics'),
                       url  => "Admin/CustomFields/Modify.html?id=" . $id,
                );
                Jifty->web->navigation->child( F =>  label => _('Group rights'),
                       url  => "Admin/CustomFields/GroupRights.html?id="
                         . $id, );
                Jifty->web->navigation->child( G =>
                    label => _('User rights'),
                    url => "Admin/CustomFields/UserRights.html?id=" . $id,
                );

            } }

    };


    if ($cf->lookup_type =~ /^RT::Model::Queue-/io) {
Jifty->web->navigation->child( 'this'}->{subtabs}->{D =>
	label => _('Applies to'),
	    url  => "Admin/CustomFields/Objects.html?id=" . $id,
	};
    }
}

if (Jifty->web->current_user->has_right( object => RT->system, right => 'AdminCustomField')) {
Jifty->web->navigation->child( "A" =>  label => _('Select'),
                        url => "Admin/CustomFields/",
                           };
Jifty->web->navigation->child( "B" =>  label => _('Create'),
                        url => "Admin/CustomFields/Modify.html?create=1",
                        separator => 1,
                           };
}

  # Now let callbacks add their extra tabs
  $m->callback( %ARGS, tabs => $tabs );

foreach my $tab (sort keys %{$tabs->{'this'}->{'subtabs'}}) {
    if ($tabs->{'this'}->{'subtabs'}->{$tab}->{'url'} eq $current_tab) {
	$tabs->{'this'}->{'subtabs'}->{$tab}->{'subtabs'} = $subtabs;
	$tabs->{'this'}->{'subtabs'}->{$tab}->{'current_subtab'} = $current_subtab;
    }
}
if( $id ) { $current_tab = "Admin/CustomFields/Modify.html?id=" . $id }

# /Admin tabs


  my $tabs = {



	     };

# /Admin/Global tabs
  my $tabs = {

};


#/Admin/Global/Workflows tabs
#
my $base = "Admin/Global/Workflows";
my $parent_subtab;
my $parent_subtabs = {
    Jifty->web->navigation->child( A =>
        label => _('Select') .'/'. _('Create'),
        url => "$base/index.html",
    );
    Jifty->web->navigation->child( B =>
        label => _('Localization'),
        url => "$base/Localization.html",
    );
    Jifty->web->navigation->child( C =>
        label => _('Mappings'),
        url => "$base/Mappings.html",
    );
};

if ( $schema ) {
    my $qs_name = $m->comp( '/Elements/QueryString', name => $schema->name );
    $current_tab .= "?$qs_name";

    $parent_subtab = "$base/Summary.html?$qs_name";
Jifty->web->navigation->child( 'E' =>
        label          => $schema->name,
        url           => $parent_subtab,
        separator      => 1,
        current_subtab => $current_tab,
        Jifty->web->navigation->child( subtabs =>
            Jifty->web->navigation->child( A =>
                label => _("Summary"),
                url  => "$base/Summary.html?$qs_name",
            );
            Jifty->web->navigation->child( B =>
                label => _("Statuses"),
                url  => "$base/Statuses.html?$qs_name",
            );
            Jifty->web->navigation->child( C =>
                label => _("Transitions"),
                url  => "$base/Transitions.html?$qs_name",
            );
            Jifty->web->navigation->child( D =>
                label => _("Interface"),
                url  => "$base/Interface.html?$qs_name",
            );
        );
    };
}
else {
    $parent_subtab = $current_tab;
}


# /Ticket/Elements/Tabs
my $tabs = {};
my $actions;

my $current_toptab = "Search/Build.html", my $searchtabs = {};

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
Jifty->web->navigation->child( '_a' =>
                class => "nav",
                url  => "Ticket/Display.html?id=" . $item_map->{first);
                label => '<< ' . _('First')
            };
Jifty->web->navigation->child( "_b" =>
                class => "nav",
                url  => "Ticket/Display.html?id="
                    . $item_map->{ $ticket->id }->{prev);
                label => '< ' . _('Prev')
            };
        }

        # Don't display next links if we're on the last ticket
        if ( $item_map->{ $ticket->id }->{next} ) {
Jifty->web->navigation->child( 'd' =>
                class => "nav",
                url  => "Ticket/Display.html?id="
                    . $item_map->{ $ticket->id }->{next);
                label => _('next') . ' >'
            };
Jifty->web->navigation->child( 'e' =>
                class => "nav",
                url  => "Ticket/Display.html?id=" . $item_map->{last);
                label => _('Last') . ' >>'
            };
        }
    }

Jifty->web->navigation->child( "this" =>
        class          => "currentnav",
        url           => "Ticket/Display.html?id=" . $ticket->id,
        label          => "#" . $id,
        current_subtab => $current_subtab
    };

    my $ticket_page_tabs = {
        Jifty->web->navigation->child( _A =>
            label => _('Display'),
            url  => "Ticket/Display.html?id=" . $id,
        );

        Jifty->web->navigation->child( _Ab =>
            label => _('History'),
            url  => "Ticket/History.html?id=" . $id,
        );
        Jifty->web->navigation->child( _B =>
            label => _('Basics'),
            url  => "Ticket/Modify.html?id=" . $id,
        );

        Jifty->web->navigation->child( _C =>
            label => _('Dates'),
            url  => "Ticket/ModifyDates.html?id=" . $id,
        );
        Jifty->web->navigation->child( _D =>
            label => _('People'),
            url  => "Ticket/ModifyPeople.html?id=" . $id,
        );
        Jifty->web->navigation->child( _E =>
            label => _('Links'),
            url  => "Ticket/ModifyLinks.html?id=" . $id,
        );
        Jifty->web->navigation->child( _X =>
            label => _('Jumbo'),
            url  => "Ticket/ModifyAll.html?id=" . $id,
        );

    };

    if ( RT->config->get('enable_reminders') ) {
Jifty->web->navigation->child( _F =>
            label     => _('Reminders'),
            url      => "Ticket/Reminders.html?id=" . $id,
            separator => 1,
        };
    }

    foreach my $tab ( sort keys %{$ticket_page_tabs} ) {
        if ( $ticket_page_tabs->{$tab}->{'url'} eq $current_tab ) {
            $ticket_page_tabs->{$tab}->{"subtabs"} = $subtabs;
            $tabs->{'this'}->{"current_subtab"}
                = $ticket_page_tabs->{$tab}->{"url"};
        }
    }
    $tabs->{'this'}->{"subtabs"} = $ticket_page_tabs;
    $current_tab = "Ticket/Display.html?id=" . $id;

    my %can = ( ModifyTicket => $ticket->current_user_has_right('ModifyTicket'), );

    if ( $can{'ModifyTicket'} or $ticket->current_user_has_right('ReplyToTicket') )
    {
Jifty->web->navigation->child( 'F' =>
            label => _('Reply'),
            url  => "Ticket/Update.html?action=respond&id=" . $id,
        };
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
                $url .= "Update.html?". $m->comp(
                    '/Elements/QueryString',
                    action => $action,
                    default_status => $next,
                    id => $id
                );
            } else {
                $url .= "Display.html?". $m->comp(
                    '/Elements/QueryString',
                    Status => $next,
                    id => $id
                );
            }
Jifty->web->navigation->child( 'G'. $i++ =>
                url => $url,
                label => _( $schema->transition_label( $current => $next ) ),
            };
        }
    }

    if ( $ticket->current_user_has_right('OwnTicket') ) {
        if ( $ticket->owner_obj->id == RT->nobody->id ) {
Jifty->web->navigation->child( 'B' =>
                url  => "Ticket/Display.html?action=take&id=" . $id,
                label => _('Take'),
                }
                if $can{'ModifyTicket'}
                    or $ticket->current_user_has_right('TakeTicket');
        } elsif ( $ticket->owner_obj->id != Jifty->web->current_user->id ) {
Jifty->web->navigation->child( 'C' =>
                url  => "Ticket/Display.html?action=steal&id=" . $id,
                label => _('Steal'),
                }
                if $can{'ModifyTicket'}
                    or $ticket->current_user_has_right('StealTicket');
        }
    }

    if (   $can{'ModifyTicket'}
        or $ticket->current_user_has_right('CommentOnTicket') )
    {
Jifty->web->navigation->child( 'E' =>
            label => _('Comment'),
            url  => "Ticket/Update.html?action=comment&id=" . $id,
        };
    }

    $actions->{'_ZZ'}
        = { html => $m->scomp( '/Ticket/Elements/Bookmark', id => $ticket->id ),
        };

}

if ( ( defined $actions->{A} || defined $actions->{B} || defined $actions->{C} )
    && (   defined $actions->{E}
        || defined $actions->{F}
        || defined $actions->{G} ) )
{

    if    ( defined $actions->{C} ) { $actions->{C}->{separator} = 1 }
    elsif ( defined $actions->{B} ) { $actions->{B}->{separator} = 1 }
    elsif ( defined $actions->{A} ) { $actions->{A}->{separator} = 1 }
}

my $args = '';
my $has_query = '';
my %query_args;
my $search_id = $ARGS{'saved_search_id'}
            || Jifty->web->session->get('CurrentSearchHash') && Jifty->web->session->get('CurrentSearchHash')->{'searchid'} || '';

$has_query = 1 if ( $ARGS{'query'} or Jifty->web->session->get('CurrentSearchHash') && Jifty->web->session->get('CurrentSearchHash')->{'query'} );

%query_args = (

        saved_search_id => ($search_id eq 'new') ? undef : $search_id,
        query  => $ARGS{'query'}  || Jifty->web->session->get('CurrentSearchHash') && Jifty->web->session->get('CurrentSearchHash')->{'query');
        format => $ARGS{'format'} || Jifty->web->session->get('CurrentSearchHash') && Jifty->web->session->get('CurrentSearchHash')->{'format');
        order_by => $ARGS{'order_by'}
            || Jifty->web->session->get('CurrentSearchHash') && Jifty->web->session->get('CurrentSearchHash')->{'order_by');
        order => $ARGS{'order'} || Jifty->web->session->get('CurrentSearchHash') && Jifty->web->session->get('CurrentSearchHash')->{'order');
        page  => $ARGS{'page'}  || Jifty->web->session->get('CurrentSearchHash') && Jifty->web->session->get('CurrentSearchHash')->{'page');
        rows_per_page  => $ARGS{'rows_per_page'}  || Jifty->web->session->get('CurrentSearchHash') && Jifty->web->session->get('CurrentSearchHash')->{'rows_per_page');
    );

    $args = "?" . $m->comp( '/Elements/QueryString', %query_args );

$tabs->{"f"} = {
    url  => "Search/Build.html?NewQuery=1",
    label => _('New Search')
};
$tabs->{"g"} = {
    url  => "Search/Build.html" . (($has_query) ? $args : ''),
    label => _('Edit Search')
};
$tabs->{"h"} = {
    url      => "Search/Edit.html$args",
    label     => _('Advanced'),
    separator => 1
};
if ($has_query) {

    if ( $current_tab =~ m{Search/Results.html} ) {
        $current_tab = "Search/Results.html$args";

        if ( Jifty->web->current_user
            ->has_right( right => 'SuperUser', object => RT->system ) )
        {
            my $shred_args = $m->comp(
                '/Elements/QueryString',
                search          => 1,
                plugin          => 'Tickets',
                'Tickets:query' => $query_args{'query');
                'Tickets:limit' => $query_args{'rows'}
            );

Jifty->web->navigation->child( "shredder" =>
                url  => 'Admin/Tools/Shredder/?' . $shred_args,
                label => _('Shredder')
            };

        }
    }
    if ( $current_tab =~ m{Search/(Bulk|Build|Edit)\.html} ) {
        $current_tab = "Search/$1.html$args";
    }

Jifty->web->navigation->child( "i" =>
        url  => "Search/Results.html$args",
        label => _('Show Results'),
    };

Jifty->web->navigation->child( "j" =>
        url  => "Search/Bulk.html$args",
        label => _('Bulk Update'),
    };

}

foreach my $searchtab ( keys %{$searchtabs} ) {
    ( $searchtab =~ /^_/ )
        ? $tabs->{ "s" . $searchtab } = $searchtabs->{$searchtab}
        : $tabs->{ "z_" . $searchtab } = $searchtabs->{$searchtab};

}

# /Admin/tools
    my $tabs = {
    };

# /Admin/Rules
    my $tabs = {
        Jifty->web->navigation->child( A =>  label => _('Select'),
               url  => "Admin/Rules/", );
        Jifty->web->navigation->child( E =>  label => _('Create'),
               url  => 'Admin/Rules/Modify.html?create=1',
        );
    };

# /Admin/Users tabs
		url => "Admin/Users/Modify.html?id=".$id,
Jifty->web->navigation->child( subtabs =>
	       Jifty->web->navigation->child( Basics =>  label => _('Basics'),
				url => "Admin/Users/Modify.html?id=".$id
			);
	       Jifty->web->navigation->child( Memberships =>  label => _('Memberships'),
			   url => "Admin/Users/Memberships.html?id=".$id
			 );
	       Jifty->web->navigation->child( History =>  label => _('History'),
			   url => "Admin/Users/History.html?id=".$id
			 );
	       Jifty->web->navigation->child( 'MyRT' =>  label => _('RT at a glance'),
			   url => "Admin/Users/MyRT.html?id=".$id
			 );
	}
};
    if ( RT->config->get('gnupg')->{'enable'} ) {
Jifty->web->navigation->child( 'this'}{'subtabs'}{'GnuPG' =>
            label => _('GnuPG'),
            url  => "Admin/Users/GnuPG.html?id=".$id,
        };
    }
}

if (Jifty->web->current_user->has_right( object => RT->system, right => 'AdminUsers')) {
Jifty->web->navigation->child( "A" =>  label => _('Select'),
			url => "Admin/Users/",
			   };
Jifty->web->navigation->child( "B" =>  label => _('Create'),
			url => "Admin/Users/Modify.html?create=1",
		separator => 1,
	};
}

# Admin/Queues
#
my $tabs;
if ($id) {
Jifty->web->navigation->child( 'this' =>
                label => $queue_obj->name,
			url => "Admin/Queues/Modify.html?id=".$id,
                    current_subtab => $current_tab,
                Jifty->web->navigation->child( subtabs =>
		 Jifty->web->navigation->child( C =>  label => _('Basics'),
			url => "Admin/Queues/Modify.html?id=".$id,
			   );
		 Jifty->web->navigation->child( D =>  label => _('Watchers'),
			url => "Admin/Queues/People.html?id=".$id,
		      );
		 Jifty->web->navigation->child( F =>  label => _('Templates'),
				url => "Admin/Queues/Templates.html?id=".$id,
			      );

                 Jifty->web->navigation->child( G1 =>  label => _('Ticket Custom Fields'),
                        url => 'Admin/Queues/CustomFields.html?sub_type=RT::Model::Ticket&id='.$id,
                        );

                 Jifty->web->navigation->child( G2 =>  label => _('Transaction Custom Fields'),
                        url => 'Admin/Queues/CustomFields.html?sub_type=RT::Model::Ticket-RT::Model::Transaction&id='.$id,
                        );

		 Jifty->web->navigation->child( H =>  label => _('Group rights'),
			  url => "Admin/Queues/GroupRights.html?id=".$id,
			);
		 Jifty->web->navigation->child( I =>  label => _('User rights'),
			  url => "Admin/Queues/UserRights.html?id=".$id,
			}
        }
        };
}
if (Jifty->web->current_user->has_right( object => RT->system, right => 'AdminQueue')) {
Jifty->web->navigation->child( "A" =>  label => _('Select'),
			url => "Admin/Queues/",
			   };
Jifty->web->navigation->child( "B" =>  label => _('Create'),
			url => "Admin/Queues/Modify.html?create=1",
		 separator => 1, };
}


# Admin/GlobalCustomFields

my $tabs = {

    Jifty->web->navigation->child( A =>
        label => _('Users'),
        text  => _('Select custom fields for all users'),
        url  => 'Admin/Global/CustomFields/Users.html',
    );

    Jifty->web->navigation->child( B =>
        label => _('Groups'),
        text  => _('Select custom fields for all user groups'),
        url  => 'Admin/Global/CustomFields/Groups.html',
    );

    Jifty->web->navigation->child( C =>
        label => _('Queues'),
        text  => _('Select custom fields for all queues'),
        url  => 'Admin/Global/CustomFields/Queues.html',
    );

    Jifty->web->navigation->child( F =>
        label => _('Tickets'),
        text  => _('Select custom fields for tickets in all queues'),
        url  => 'Admin/Global/CustomFields/Queue-Tickets.html',
    );

    Jifty->web->navigation->child( G =>
        label => _('Ticket Transactions'),
        text  => _('Select custom fields for transactions on tickets in all queues'),
        url  => 'Admin/Global/CustomFields/Queue-Transactions.html',
    );

};

# Admin/Groups

if ( $group_obj and $group_obj->id ) {
$tabs->{"this"} = { class => "currentnav",
                    url  => "Admin/Groups/Modify.html?id=" . $group_obj->id,
                    label => $group_obj->name,
                    current_subtab => $current_subtab,
        Jifty->web->navigation->child( subtabs =>
        Jifty->web->navigation->child( C =>  label => _('Basics'),
               url  => "Admin/Groups/Modify.html?id=" . $group_obj->id );

        Jifty->web->navigation->child( D =>  label => _('Members'),
               url  => "Admin/Groups/Members.html?id=" . $group_obj->id );

        Jifty->web->navigation->child( F =>  label => _('Group rights'),
               url  => "Admin/Groups/GroupRights.html?id=" . $group_obj->id, );
        Jifty->web->navigation->child( G =>  label => _('User rights'),
               url  => "Admin/Groups/UserRights.html?id=" . $group_obj->id, );
        Jifty->web->navigation->child( H =>  label => _('History'),
               url  => "Admin/Groups/History.html?id=" . $group_obj->id );
    }
}
}
$tabs->{"A"} = { label => _('Select'),
                 url  => "Admin/Groups/", };
$tabs->{"B"} = { label     => _('Create'),
                 url      => "Admin/Groups/Modify.html?create=1",
		 separator => 1, };

# Prefs/
my $tabs;
$searches ||= [$m->comp("/Search/Elements/SearchesForObject", object => RT::System->new())];

$tabs->{a} = {
    label => _('Quick search'),
	url => 'Prefs/Quicksearch.html',
};

for my $search (@$searches) {
Jifty->web->navigation->child(  $search->[0]  =>
        label => $search->[0],
        url  => "Prefs/Search.html?"
                 .$m->comp('/Elements/QueryString', name => ref($search->[1]).'-'.$search->[1]->id),
    };
}


# User/
	     };

# User/Groups
if ( $group_obj and $group_obj->id ) {
Jifty->web->navigation->child( "this" =>
        label   => $group_obj->name,
        url    => "User/Groups/Modify.html?id=" . $group_obj->id,
        Jifty->web->navigation->child( subtabs =>
            Jifty->web->navigation->child( Basics =>  label => _('Basics'),
                        url  => "User/Groups/Modify.html?id=" . $group_obj->id
            );

            Jifty->web->navigation->child( Members =>  label => _('Members'),
                         url  => "User/Groups/Members.html?id=" . $group_obj->id
            );

        } };
        $tabs->{'this'}->{'current_subtab'} = $current_subtab;
         $current_subtab = "User/Groups/Modify.html?id=" . $group_obj->id,
}
$tabs->{"A"} = { label => _('Select group'),
                 url  => "User/Groups/index.html" };
$tabs->{"B"} = { label     => _('New group'),
                 url      => "User/Groups/Modify.html?create=1",
                 separator => 1 };




=cut

# Now let callbacks add their extra tabs

# Backward compatibility with old RT URLs

before '/NoAuth/Logout.html' => run { redirect '/logout' };

1;

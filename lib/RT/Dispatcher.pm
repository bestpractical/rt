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





# Navigation

# Top level tabs /Elements/Tabs
my $basetopactions = {
	a => { html => $m->scomp('/Elements/CreateTicket')
		},
	b => { html => $m->scomp('/Elements/SimpleSearch')
		}
	};
my $basetabs = {     a => { title => _('Homepage'),
                           path => '',
                         },
                    ab => { title => _('Simple Search'),
                        path => 'Search/Simple.html'
                         },
                    b => { title => _('Tickets'),
                        path => 'Search/Build.html'
                      },
                    c => { title => _('Tools'),
                           path => 'Tools/index.html'
                         },
                 };

if (Jifty->web->current_user->has_right( right => 'ShowConfigTab',
				       object => RT->system )) {
    $basetabs->{e} = { title => _('Configuration'),
                       path => 'Admin/',
		     };
}

if (Jifty->web->current_user->has_right( right => 'ModifySelf',
				       object => RT->system )) {
    $basetabs->{k} = { title => _('Preferences'),
                       path => 'Prefs/Other.html'
		     };
}

if (Jifty->web->current_user->has_right( right => 'ShowApprovalsTab',
                        object => RT->system )) {
    $basetabs->{p} = { title => _('Approval'),
                        path => 'Approvals/'
            };
}

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
    a => {
        title => _('Dashboards'),
        path  => 'Dashboards/index.html',
    },
    c => {
        title => _('Reports'),
        path  => 'Tools/Reports/index.html',
    },
    d => {
        title => _('My Day'),
        path  => 'Tools/MyDay.html',
    },
};

#/Tools/Reports tabs
my $tabs = {
    a => {
        title => _('Resolved by owner'),
        path  => 'Tools/Reports/ResolvedByOwner.html',
    },
    b => {
        title => _('Resolved in date range'),
        path  => 'Tools/Reports/ResolvedByDates.html',
    },
    c => {
        title => _('Created in a date range'),
        path  => 'Tools/Reports/CreatedByDates.html',
    },
};




# /Tools/Dashboards tabs
my $tabs;
my $real_subtab = $current_subtab;
if ( $dashboard_obj and $dashboard_obj->id ) {

    my $name = $dashboard_obj->name;

    my $modify  = "Dashboards/Modify.html?id=" . $dashboard_obj->id;
    my $queries = "Dashboards/Queries.html?id=" . $dashboard_obj->id;
    my $render  = "Dashboards/" . $dashboard_obj->id . "/$name";

    $tabs->{"this"} = {
        title   => $dashboard_obj->name,
        path    => $modify,
        current_subtab  => $current_subtab,
        subtabs => {
            a_Basics => { title => _('Basics'),
                          path  => $modify,
            },

            b_Queries => { title => _('Queries'),
                           path  => $queries,
            },

            c_Subscription => { title => _('Subscription'),
                                path  =>
                                    "Dashboards/Subscription.html?dashboard_id=" . $dashboard_obj->id
            },


            z_Preview => { title => _('Show'),
                           path  => $render,
            },
        }
    };

    delete $tabs->{"this"}{"subtabs"}{"c_Subscription"}
        unless $dashboard_obj->current_user_can_subscribe;

    $tabs->{"this"}{"subtabs"}{"z_Preview"}{path} = $real_subtab
        if $real_subtab =~ /Render/
        || $real_subtab =~ /Dashboard\/\d+/;

    $current_subtab = $modify;
}

$tabs->{"A"} = { title => _('Select dashboard'),
                 path  => "Dashboards/index.html" };

my $dashboard = RT::Dashboard->new( current_user => Jifty->web->current_user );
my @objects = $dashboard->_privacy_objects(create => 1);

if (@objects) {
    $tabs->{"B"} = { title     => _('New dashboard'),
                     path      => "Dashboards/Modify.html?create=1",
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

if ($title) {
$title = _("RT Self Service") . " / " . $title;
} else {
$title = _("RT Self Service");

}
my ($tab);
my $tabs = { A  => { title => _('Open tickets'),
                        path => 'SelfService/',
                      },
             B => { title => _('Closed tickets'),
                         path => 'SelfService/Closed.html',
                       },
           };

if ($queue_count > 1) {
        $tabs->{C} = { title => _('New ticket'),
                       path => 'SelfService/CreateTicketInQueue.html'
                       };
} else {
        $tabs->{C} = { title => _('New ticket'),
                       path => 'SelfService/Create.html?queue=' . $queue_id
                       };
}

if (Jifty->web->current_user->has_right( right => 'ModifySelf',
				       object => RT->system )) {
	$tabs->{Z} = { title => _('Preferences'),
		       path => 'SelfService/Prefs.html'
		       };
}

my $actions = {
	B => { html => $m->scomp('GotoTicket')
		}
	};




# /Admin/CustomFields tabs

if ($id) {
    my $cf = RT::Model::CustomField->new( current_user => Jifty->web->current_user );
    $cf->load($id);
    $tabs = {
        this => {
            title => $cf->name,
            path  => "Admin/CustomFields/Modify.html?id=" . $id,
            current_subtab => $current_tab,

            subtabs => {

                C => { title => _('Basics'),
                       path  => "Admin/CustomFields/Modify.html?id=" . $id,
                },
                F => { title => _('Group rights'),
                       path  => "Admin/CustomFields/GroupRights.html?id="
                         . $id, },
                G => {
                    title => _('User rights'),
                    path => "Admin/CustomFields/UserRights.html?id=" . $id,
                },

            } }

    };


    if ($cf->lookup_type =~ /^RT::Model::Queue-/io) {
	$tabs->{'this'}->{subtabs}->{D} = {
	title => _('Applies to'),
	    path  => "Admin/CustomFields/Objects.html?id=" . $id,
	};
    }
}

if (Jifty->web->current_user->has_right( object => RT->system, right => 'AdminCustomField')) {
  $tabs->{"A"} = { title => _('Select'),
                        path => "Admin/CustomFields/",
                           };
  $tabs->{"B"} = { title => _('Create'),
                        path => "Admin/CustomFields/Modify.html?create=1",
                        separator => 1,
                           };
}

  # Now let callbacks add their extra tabs
  $m->callback( %ARGS, tabs => $tabs );

foreach my $tab (sort keys %{$tabs->{'this'}->{'subtabs'}}) {
    if ($tabs->{'this'}->{'subtabs'}->{$tab}->{'path'} eq $current_tab) {
	$tabs->{'this'}->{'subtabs'}->{$tab}->{'subtabs'} = $subtabs;
	$tabs->{'this'}->{'subtabs'}->{$tab}->{'current_subtab'} = $current_subtab;
    }
}
if( $id ) { $current_tab = "Admin/CustomFields/Modify.html?id=" . $id }

# /Admin tabs


  my $tabs = { A => { title => _('Users'),
			  path => 'Admin/Users/',
			},
	       B => { title => _('Groups'),
			   path => 'Admin/Groups/',
			 },
	       C => { title => _('Queues'),
			   path => 'Admin/Queues/',
			 },
	       D => { 'title' => _('Custom Fields'),
			   path => 'Admin/CustomFields/',
			 },
	       E => { 'title' => _('Rules'),
			   path => 'admin/rules/',
			 },
	       F => { 'title' => _('Global'),
			   path => 'Admin/Global/',
			 },
	       G => { 'title' => _('Tools'),
			   path => 'Admin/Tools/',
			 },
	     };

# /Admin/Global tabs
  my $tabs = {
               B => { title => _('Templates'),
                        path => 'Admin/Global/Templates.html',
                      },
                C => { title => _('Workflows'),
                        path => 'Admin/Global/Workflows/index.html',
                        },

                F => { title => _('Custom Fields'),
                        path => 'Admin/Global/CustomFields/index.html',
                        },

                G => { title => _('Group rights'),
                                path => 'Admin/Global/GroupRights.html',
                      },
                H => { title => _('User rights'),
                                path => 'Admin/Global/UserRights.html',
                      },
                I => { title => _('RT at a glance'),
                                path => 'Admin/Global/MyRT.html',
                      },
                Y => { title => _('Jifty'),
                                path => 'Admin/Global/Jifty.html',
                      },
                Z => { title => _('System'),
                                path => 'Admin/Global/System.html',
                      },

};


#/Admin/Global/Workflows tabs
#
my $base = "Admin/Global/Workflows";
my $parent_subtab;
my $parent_subtabs = {
    A => {
        title => _('Select') .'/'. _('Create'),
        path => "$base/index.html",
    },
    B => {
        title => _('Localization'),
        path => "$base/Localization.html",
    },
    C => {
        title => _('Mappings'),
        path => "$base/Mappings.html",
    },
};

if ( $schema ) {
    my $qs_name = $m->comp( '/Elements/QueryString', name => $schema->name );
    $current_tab .= "?$qs_name";

    $parent_subtab = "$base/Summary.html?$qs_name";
    $parent_subtabs->{'E'} = {
        title          => $schema->name,
        path           => $parent_subtab,
        separator      => 1,
        current_subtab => $current_tab,
        subtabs => {
            A => {
                title => _("Summary"),
                path  => "$base/Summary.html?$qs_name",
            },
            B => {
                title => _("Statuses"),
                path  => "$base/Statuses.html?$qs_name",
            },
            C => {
                title => _("Transitions"),
                path  => "$base/Transitions.html?$qs_name",
            },
            D => {
                title => _("Interface"),
                path  => "$base/Interface.html?$qs_name",
            },
        },
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
            $searchtabs->{'_a'} = {
                class => "nav",
                path  => "Ticket/Display.html?id=" . $item_map->{first},
                title => '<< ' . _('First')
            };
            $searchtabs->{"_b"} = {
                class => "nav",
                path  => "Ticket/Display.html?id="
                    . $item_map->{ $ticket->id }->{prev},
                title => '< ' . _('Prev')
            };
        }

        # Don't display next links if we're on the last ticket
        if ( $item_map->{ $ticket->id }->{next} ) {
            $searchtabs->{'d'} = {
                class => "nav",
                path  => "Ticket/Display.html?id="
                    . $item_map->{ $ticket->id }->{next},
                title => _('next') . ' >'
            };
            $searchtabs->{'e'} = {
                class => "nav",
                path  => "Ticket/Display.html?id=" . $item_map->{last},
                title => _('Last') . ' >>'
            };
        }
    }

    $tabs->{"this"} = {
        class          => "currentnav",
        path           => "Ticket/Display.html?id=" . $ticket->id,
        title          => "#" . $id,
        current_subtab => $current_subtab
    };

    my $ticket_page_tabs = {
        _A => {
            title => _('Display'),
            path  => "Ticket/Display.html?id=" . $id,
        },

        _Ab => {
            title => _('History'),
            path  => "Ticket/History.html?id=" . $id,
        },
        _B => {
            title => _('Basics'),
            path  => "Ticket/Modify.html?id=" . $id,
        },

        _C => {
            title => _('Dates'),
            path  => "Ticket/ModifyDates.html?id=" . $id,
        },
        _D => {
            title => _('People'),
            path  => "Ticket/ModifyPeople.html?id=" . $id,
        },
        _E => {
            title => _('Links'),
            path  => "Ticket/ModifyLinks.html?id=" . $id,
        },
        _X => {
            title => _('Jumbo'),
            path  => "Ticket/ModifyAll.html?id=" . $id,
        },

    };

    if ( RT->config->get('enable_reminders') ) {
        $ticket_page_tabs->{_F} = {
            title     => _('Reminders'),
            path      => "Ticket/Reminders.html?id=" . $id,
            separator => 1,
        };
    }

    foreach my $tab ( sort keys %{$ticket_page_tabs} ) {
        if ( $ticket_page_tabs->{$tab}->{'path'} eq $current_tab ) {
            $ticket_page_tabs->{$tab}->{"subtabs"} = $subtabs;
            $tabs->{'this'}->{"current_subtab"}
                = $ticket_page_tabs->{$tab}->{"path"};
        }
    }
    $tabs->{'this'}->{"subtabs"} = $ticket_page_tabs;
    $current_tab = "Ticket/Display.html?id=" . $id;

    my %can = ( ModifyTicket => $ticket->current_user_has_right('ModifyTicket'), );

    if ( $can{'ModifyTicket'} or $ticket->current_user_has_right('ReplyToTicket') )
    {
        $actions->{'F'} = {
            title => _('Reply'),
            path  => "Ticket/Update.html?action=respond&id=" . $id,
        };
    }

    if ( $can{'ModifyTicket'} ) {
        my $current = $ticket->status;
        my $schema = $ticket->queue->status_schema;
        my $i = 1;
        foreach my $next ( $schema->transitions( $current ) ) {
            my $action = $schema->transition_action( $current => $next );
            next if $action eq 'hide';

            my $path = 'Ticket/';
            if ( $action ) {
                $path .= "Update.html?". $m->comp(
                    '/Elements/QueryString',
                    action => $action,
                    default_status => $next,
                    id => $id
                );
            } else {
                $path .= "Display.html?". $m->comp(
                    '/Elements/QueryString',
                    Status => $next,
                    id => $id
                );
            }
            $actions->{'G'. $i++} = {
                path => $path,
                title => _( $schema->transition_label( $current => $next ) ),
            };
        }
    }

    if ( $ticket->current_user_has_right('OwnTicket') ) {
        if ( $ticket->owner_obj->id == RT->nobody->id ) {
            $actions->{'B'} = {
                path  => "Ticket/Display.html?action=take&id=" . $id,
                title => _('Take'),
                }
                if $can{'ModifyTicket'}
                    or $ticket->current_user_has_right('TakeTicket');
        } elsif ( $ticket->owner_obj->id != Jifty->web->current_user->id ) {
            $actions->{'C'} = {
                path  => "Ticket/Display.html?action=steal&id=" . $id,
                title => _('Steal'),
                }
                if $can{'ModifyTicket'}
                    or $ticket->current_user_has_right('StealTicket');
        }
    }

    if (   $can{'ModifyTicket'}
        or $ticket->current_user_has_right('CommentOnTicket') )
    {
        $actions->{'E'} = {
            title => _('Comment'),
            path  => "Ticket/Update.html?action=comment&id=" . $id,
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
        query  => $ARGS{'query'}  || Jifty->web->session->get('CurrentSearchHash') && Jifty->web->session->get('CurrentSearchHash')->{'query'},
        format => $ARGS{'format'} || Jifty->web->session->get('CurrentSearchHash') && Jifty->web->session->get('CurrentSearchHash')->{'format'},
        order_by => $ARGS{'order_by'}
            || Jifty->web->session->get('CurrentSearchHash') && Jifty->web->session->get('CurrentSearchHash')->{'order_by'},
        order => $ARGS{'order'} || Jifty->web->session->get('CurrentSearchHash') && Jifty->web->session->get('CurrentSearchHash')->{'order'},
        page  => $ARGS{'page'}  || Jifty->web->session->get('CurrentSearchHash') && Jifty->web->session->get('CurrentSearchHash')->{'page'},
        rows_per_page  => $ARGS{'rows_per_page'}  || Jifty->web->session->get('CurrentSearchHash') && Jifty->web->session->get('CurrentSearchHash')->{'rows_per_page'},
    );

    $args = "?" . $m->comp( '/Elements/QueryString', %query_args );

$tabs->{"f"} = {
    path  => "Search/Build.html?NewQuery=1",
    title => _('New Search')
};
$tabs->{"g"} = {
    path  => "Search/Build.html" . (($has_query) ? $args : ''),
    title => _('Edit Search')
};
$tabs->{"h"} = {
    path      => "Search/Edit.html$args",
    title     => _('Advanced'),
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
                'Tickets:query' => $query_args{'query'},
                'Tickets:limit' => $query_args{'rows'}
            );

            $tabs->{"shredder"} = {
                path  => 'Admin/Tools/Shredder/?' . $shred_args,
                title => _('Shredder')
            };

        }
    }
    if ( $current_tab =~ m{Search/(Bulk|Build|Edit)\.html} ) {
        $current_tab = "Search/$1.html$args";
    }

    $tabs->{"i"} = {
        path  => "Search/Results.html$args",
        title => _('Show Results'),
    };

    $tabs->{"j"} = {
        path  => "Search/Bulk.html$args",
        title => _('Bulk Update'),
    };

}

foreach my $searchtab ( keys %{$searchtabs} ) {
    ( $searchtab =~ /^_/ )
        ? $tabs->{ "s" . $searchtab } = $searchtabs->{$searchtab}
        : $tabs->{ "z_" . $searchtab } = $searchtabs->{$searchtab};

}

# /Admin/tools
    my $tabs = {
        A => { title => _('System Configuration'),
               path => 'Admin/Tools/Configuration.html',
        },
        E => { title => _('Shredder'),
               path  => 'Admin/Tools/Shredder',
        },
    };

# /Admin/Rules
    my $tabs = {
        A => { title => _('Select'),
               path  => "Admin/Rules/", },
        E => { title => _('Create'),
               path  => 'Admin/Rules/Modify.html?create=1',
        },
    };

# /Admin/Users tabs
		path => "Admin/Users/Modify.html?id=".$id,
subtabs => {
	       Basics => { title => _('Basics'),
				path => "Admin/Users/Modify.html?id=".$id
			},
	       Memberships => { title => _('Memberships'),
			   path => "Admin/Users/Memberships.html?id=".$id
			 },
	       History => { title => _('History'),
			   path => "Admin/Users/History.html?id=".$id
			 },
	       'MyRT' => { title => _('RT at a glance'),
			   path => "Admin/Users/MyRT.html?id=".$id
			 },
	}
};
    if ( RT->config->get('gnupg')->{'enable'} ) {
        $tabs->{'this'}{'subtabs'}{'GnuPG'} = {
            title => _('GnuPG'),
            path  => "Admin/Users/GnuPG.html?id=".$id,
        };
    }
}

if (Jifty->web->current_user->has_right( object => RT->system, right => 'AdminUsers')) {
  $tabs->{"A"} = { title => _('Select'),
			path => "Admin/Users/",
			   };
  $tabs->{"B"} = { title => _('Create'),
			path => "Admin/Users/Modify.html?create=1",
		separator => 1,
	};
}

# Admin/Queues
#
my $tabs;
if ($id) {
  $tabs->{'this'}  = {
                title => $queue_obj->name,
			path => "Admin/Queues/Modify.html?id=".$id,
                    current_subtab => $current_tab,
                subtabs => {
		 C => { title => _('Basics'),
			path => "Admin/Queues/Modify.html?id=".$id,
			   },
		 D => { title => _('Watchers'),
			path => "Admin/Queues/People.html?id=".$id,
		      },
		 F => { title => _('Templates'),
				path => "Admin/Queues/Templates.html?id=".$id,
			      },

                 G1 => { title => _('Ticket Custom Fields'),
                        path => 'Admin/Queues/CustomFields.html?sub_type=RT::Model::Ticket&id='.$id,
                        },

                 G2 => { title => _('Transaction Custom Fields'),
                        path => 'Admin/Queues/CustomFields.html?sub_type=RT::Model::Ticket-RT::Model::Transaction&id='.$id,
                        },

		 H => { title => _('Group rights'),
			  path => "Admin/Queues/GroupRights.html?id=".$id,
			},
		 I => { title => _('User rights'),
			  path => "Admin/Queues/UserRights.html?id=".$id,
			}
        }
        };
}
if (Jifty->web->current_user->has_right( object => RT->system, right => 'AdminQueue')) {
  $tabs->{"A"} = { title => _('Select'),
			path => "Admin/Queues/",
			   };
  $tabs->{"B"} = { title => _('Create'),
			path => "Admin/Queues/Modify.html?create=1",
		 separator => 1, };
}


# Admin/GlobalCustomFields

my $tabs = {

    A => {
        title => _('Users'),
        text  => _('Select custom fields for all users'),
        path  => 'Admin/Global/CustomFields/Users.html',
    },

    B => {
        title => _('Groups'),
        text  => _('Select custom fields for all user groups'),
        path  => 'Admin/Global/CustomFields/Groups.html',
    },

    C => {
        title => _('Queues'),
        text  => _('Select custom fields for all queues'),
        path  => 'Admin/Global/CustomFields/Queues.html',
    },

    F => {
        title => _('Tickets'),
        text  => _('Select custom fields for tickets in all queues'),
        path  => 'Admin/Global/CustomFields/Queue-Tickets.html',
    },

    G => {
        title => _('Ticket Transactions'),
        text  => _('Select custom fields for transactions on tickets in all queues'),
        path  => 'Admin/Global/CustomFields/Queue-Transactions.html',
    },

};

# Admin/Groups

if ( $group_obj and $group_obj->id ) {
$tabs->{"this"} = { class => "currentnav",
                    path  => "Admin/Groups/Modify.html?id=" . $group_obj->id,
                    title => $group_obj->name,
                    current_subtab => $current_subtab,
        subtabs => {
        C => { title => _('Basics'),
               path  => "Admin/Groups/Modify.html?id=" . $group_obj->id },

        D => { title => _('Members'),
               path  => "Admin/Groups/Members.html?id=" . $group_obj->id },

        F => { title => _('Group rights'),
               path  => "Admin/Groups/GroupRights.html?id=" . $group_obj->id, },
        G => { title => _('User rights'),
               path  => "Admin/Groups/UserRights.html?id=" . $group_obj->id, },
        H => { title => _('History'),
               path  => "Admin/Groups/History.html?id=" . $group_obj->id },
    }
}
}
$tabs->{"A"} = { title => _('Select'),
                 path  => "Admin/Groups/", };
$tabs->{"B"} = { title     => _('Create'),
                 path      => "Admin/Groups/Modify.html?create=1",
		 separator => 1, };

# Prefs/
my $tabs;
$searches ||= [$m->comp("/Search/Elements/SearchesForObject", object => RT::System->new())];

$tabs->{a} = {
    title => _('Quick search'),
	path => 'Prefs/Quicksearch.html',
};

for my $search (@$searches) {
    $tabs->{ $search->[0] } = {
        title => $search->[0],
        path  => "Prefs/Search.html?"
                 .$m->comp('/Elements/QueryString', name => ref($search->[1]).'-'.$search->[1]->id),
    };
}


# User/

	       a => { title => _('Settings'),
			   path => 'Prefs/Other.html',
			 },

             b => { title => _('About me'),
			  path => 'User/Prefs.html',
			},
	       f => { title => _('Search options'),
			   path => 'Prefs/SearchOptions.html',
			 },
	       r => { title => _('RT at a glance'),
			   path => 'Prefs/MyRT.html',
			 },
	     };

# User/Groups
if ( $group_obj and $group_obj->id ) {
    $tabs->{"this"} = {
        title   => $group_obj->name,
        path    => "User/Groups/Modify.html?id=" . $group_obj->id,
        subtabs => {
            Basics => { title => _('Basics'),
                        path  => "User/Groups/Modify.html?id=" . $group_obj->id
            },

            Members => { title => _('Members'),
                         path  => "User/Groups/Members.html?id=" . $group_obj->id
            },

        } };
        $tabs->{'this'}->{'current_subtab'} = $current_subtab;
         $current_subtab = "User/Groups/Modify.html?id=" . $group_obj->id,
}
$tabs->{"A"} = { title => _('Select group'),
                 path  => "User/Groups/index.html" };
$tabs->{"B"} = { title     => _('New group'),
                 path      => "User/Groups/Modify.html?create=1",
                 separator => 1 };



# Now let callbacks add their extra tabs

# Backward compatibility with old RT URLs

before '/NoAuth/Logout.html' => run { redirect '/logout' };

1;

# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2019 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
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
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
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

=head1 NAME

RT::Interface::Web::MenuBuilder

=cut

use strict;
use warnings;

package RT::Interface::Web::MenuBuilder;

sub loc { HTML::Mason::Commands::loc( @_ ); }

sub QueryString {
    my %args = @_;
    my $u    = URI->new();
    $u->query_form(map { $_ => $args{$_} } sort keys %args);
    return $u->query;
}

sub BuildMainNav {
    my $request_path = shift;
    my $top          = shift;
    my $widgets      = shift;
    my $page         = shift;

    my %args = ( @_ );

    my $query_string = $args{QueryString};
    my $query_args = $args{QueryArgs};

    my $current_user = $HTML::Mason::Commands::session{CurrentUser};

    if ($request_path =~ m{^/Asset/}) {
        $widgets->child( asset_search => raw_html => $HTML::Mason::Commands::m->scomp('/Asset/Elements/Search') );
        $widgets->child( create_asset => raw_html => $HTML::Mason::Commands::m->scomp('/Asset/Elements/CreateAsset') );
    }
    elsif ($request_path =~ m{^/Articles/}) {
        $widgets->child( article_search => raw_html => $HTML::Mason::Commands::m->scomp('/Articles/Elements/GotoArticle') );
        $widgets->child( create_article => raw_html => $HTML::Mason::Commands::m->scomp('/Articles/Elements/CreateArticleButton') );
    } else {
        $widgets->child( simple_search => raw_html => $HTML::Mason::Commands::m->scomp('SimpleSearch', Placeholder => loc('Search Tickets')) );
        $widgets->child( create_ticket => raw_html => $HTML::Mason::Commands::m->scomp('CreateTicket', ButtonOnly => 1) );
    }

    my $home = $top->child( home => title => loc('Homepage'), path => '/' );
    unless ($HTML::Mason::Commands::session{'dashboards_in_menu'}) {
        my $dashboards_in_menu = $current_user->UserObj->Preferences(
            'DashboardsInMenu',
            {},
        );

        unless ($dashboards_in_menu->{dashboards}) {
            my ($default_dashboards) =
                RT::System->new( $current_user )
                    ->Attributes
                    ->Named('DashboardsInMenu');
            if ($default_dashboards) {
                $dashboards_in_menu = $default_dashboards->Content;
            }
        }

        $HTML::Mason::Commands::session{'dashboards_in_menu'} = $dashboards_in_menu->{dashboards} || [];
    }

    my @dashboards;
    for my $id ( @{$HTML::Mason::Commands::session{'dashboards_in_menu'}} ) {
        my $dash = RT::Dashboard->new( $current_user );
        my ( $status, $msg ) = $dash->LoadById($id);
        if ( $status ) {
            push @dashboards, $dash;
        } else {
            $RT::Logger->debug( "Failed to load dashboard $id: $msg, removing from menu" );
            $home->RemoveDashboardMenuItem(
                DashboardId => $id,
                CurrentUser => $HTML::Mason::Commands::session{CurrentUser}->UserObj,
            );
            @{ $HTML::Mason::Commands::session{'dashboards_in_menu'} } =
              grep { $_ != $id } @{ $HTML::Mason::Commands::session{'dashboards_in_menu'} };
        }
    }

    my $dashes = $top->child('home');
    if (@dashboards) {
        for my $dash (@dashboards) {
            $home->child( 'dashboard-' . $dash->id,
                title => $dash->Name,
                path  => '/Dashboards/' . $dash->id . '/' . $dash->Name
            );
        }
    }
    $dashes->child( edit => title => loc('Update This Menu'), path => 'Prefs/DashboardsInMenu.html' );
    $dashes->child( more => title => loc('All Dashboards'),   path => 'Dashboards/index.html' );
    my $dashboard = RT::Dashboard->new( $current_user );
    if ( $dashboard->CurrentUserCanCreateAny ) {
        $dashes->child('dashboard_create' => title => loc('New Dashboard'), path => "/Dashboards/Modify.html?Create=1" );
    }

    my $search = $top->child( search => title => loc('Search'), path => '/Search/Simple.html' );

    my $tickets = $search->child( tickets => title => loc('Tickets'), path => '/Search/Build.html' );
    $tickets->child( simple => title => loc('Simple Search'), path => "/Search/Simple.html" );
    $tickets->child( new    => title => loc('New Search'),    path => "/Search/Build.html?NewQuery=1" );

    my $recents = $tickets->child( recent => title => loc('Recently Viewed'));
    for ($current_user->RecentlyViewedTickets) {
        my ($ticketId, $timestamp) = @$_;
        my $ticket = RT::Ticket->new($current_user);
        $ticket->Load($ticketId);
        if ($ticket->Id) {
            my $title = $ticket->Subject || loc("(No subject)");
            if (length $title > 50) {
                $title = substr($title, 0, 47);
                $title =~ s/\s+$//;
                $title .= "...";
            }
            $title = "#$ticketId: " . $title;
            $recents->child( "$ticketId" => title => $title, path => "/Ticket/Display.html?id=" . $ticket->Id );
        }
    }

    $search->child( articles => title => loc('Articles'),   path => "/Articles/Article/Search.html" )
        if $current_user->HasRight( Right => 'ShowArticlesMenu', Object => RT->System );

    $search->child( users => title => loc('Users'),   path => "/User/Search.html" );

    $search->child( groups      =>
                    title       => loc('Groups'),
                    path        => "/Group/Search.html",
                    description => 'Group search'
    );

    $search->child( assets => title => loc("Assets"), path => "/Asset/Search/" )
        if $current_user->HasRight( Right => 'ShowAssetsMenu', Object => RT->System );

    my $txns = $search->child( transactions => title => loc('Transactions'), path => '/Search/Build.html?Class=RT::Transactions&ObjectType=RT::Ticket' );
    my $txns_tickets = $txns->child( tickets => title => loc('Tickets'), path => "/Search/Build.html?Class=RT::Transactions&ObjectType=RT::Ticket" );
    $txns_tickets->child( new => title => loc('New Search'), path => "/Search/Build.html?Class=RT::Transactions&ObjectType=RT::Ticket&NewQuery=1" );

    my $reports = $top->child( reports =>
        title       => loc('Reports'),
        description => loc('Reports summarizing ticket resolution and status'),
        path        => loc('/Reports'),
    );
    $reports->child( resolvedbyowner =>
        title       => loc('Resolved by owner'),
        path        => '/Reports/ResolvedByOwner.html',
        description => loc('Examine tickets resolved in a queue, grouped by owner'),
    );
    $reports->child( resolvedindaterange =>
        title       => loc('Resolved in date range'),
        path        => '/Reports/ResolvedByDates.html',
        description => loc('Examine tickets resolved in a queue between two dates'),
    );
    $reports->child( createdindaterange =>
        title       => loc('Created in a date range'),
        path        => '/Reports/CreatedByDates.html',
        description => loc('Examine tickets created in a queue between two dates'),
    );

    if ($current_user->HasRight( Right => 'ShowArticlesMenu', Object => RT->System )) {
        my $articles = $top->child( articles => title => loc('Articles'), path => "/Articles/index.html");
        $articles->child( articles => title => loc('Overview'), path => "/Articles/index.html" );
        $articles->child( topics   => title => loc('Topics'),   path => "/Articles/Topics.html" );
        $articles->child( create   => title => loc('Create'),   path => "/Articles/Article/PreCreate.html" );
        $articles->child( search   => title => loc('Search'),   path => "/Articles/Article/Search.html" );
    }

    if ($current_user->HasRight( Right => 'ShowAssetsMenu', Object => RT->System )) {
        my $assets = $top->child( "assets", title => loc("Assets"), path => "/Asset/Search/" );
        $assets->child( "create", title => loc("Create"), path => "/Asset/CreateInCatalog.html" );
        $assets->child( "search", title => loc("Search"), path => "/Asset/Search/" );
    }

    my $tools = $top->child( tools => title => loc('Tools'), path => '/Tools/index.html' );

    $tools->child( my_day =>
        title       => loc('My Day'),
        description => loc('Easy updating of your open tickets'),
        path        => '/Tools/MyDay.html',
    );

    if ( RT->Config->Get('EnableReminders') ) {
        $tools->child( my_reminders =>
            title       => loc('My Reminders'),
            description => loc('Easy viewing of your reminders'),
            path        => '/Tools/MyReminders.html',
        );
    }

    if ( $current_user->HasRight( Right => 'ShowApprovalsTab', Object => RT->System ) ) {
        $tools->child( approval =>
            title       => loc('Approval'),
            description => loc('My Approvals'),
            path        => '/Approvals/',
        );
    }

    if ( $current_user->HasRight( Right => 'ShowConfigTab', Object => RT->System ) )
    {
        _BuildAdminMenu( $request_path, $top, $widgets, $page, %args );
    }

    my $username = '<span class="current-user">'
                 . $HTML::Mason::Commands::m->interp->apply_escapes($current_user->Name, 'h')
                 . '</span>';
    my $about_me = $top->child( 'preferences' =>
        title        => loc('Logged in as [_1]', $username),
        escape_title => 0,
        path         => '/User/Summary.html?id=' . $current_user->id,
        sort_order   => 99,
    );

    $about_me->child( rt_name => title => loc("RT for [_1]", RT->Config->Get('rtname')), path => '/' );

    if ( $current_user->UserObj
         && $current_user->HasRight( Right => 'ModifySelf', Object => RT->System )) {
        my $settings = $about_me->child( settings => title => loc('Settings'), path => '/Prefs/Other.html' );
        $settings->child( options        => title => loc('Preferences'),        path => '/Prefs/Other.html' );
        $settings->child( about_me       => title => loc('About me'),       path => '/Prefs/AboutMe.html' );
        $settings->child( search_options => title => loc('Search options'), path => '/Prefs/SearchOptions.html' );
        $settings->child( myrt           => title => loc('RT at a glance'), path => '/Prefs/MyRT.html' );
        $settings->child( dashboards_in_menu =>
            title => loc('Dashboards in menu'),
            path  => '/Prefs/DashboardsInMenu.html',
        );
        $settings->child( queue_list    => title => loc('Queue list'),   path => '/Prefs/QueueList.html' );

        my $search_menu = $settings->child( 'saved-searches' => title => loc('Saved Searches') );
        my $searches = [ $HTML::Mason::Commands::m->comp( "/Search/Elements/SearchesForObject",
                          Object => RT::System->new( $current_user )) ];
        my $i = 0;

        for my $search (@$searches) {
            $search_menu->child( "search-" . $i++ =>
                title => $search->[1],
                path  => "/Prefs/Search.html?"
                       . QueryString( name => ref( $search->[2] ) . '-' . $search->[2]->Id ),
            );

        }
    }
    my $logout_url = RT->Config->Get('LogoutURL');
    if ( $current_user->Name
         && (   !RT->Config->Get('WebRemoteUserAuth')
              || RT->Config->Get('WebFallbackToRTLogin') )) {
        $about_me->child( logout => title => loc('Logout'), path => $logout_url );
    }
    if ( $request_path =~ m{^/Dashboards/(\d+)?}) {
        if ( my $id = ( $1 || $HTML::Mason::Commands::DECODED_ARGS->{'id'} ) ) {
            my $obj = RT::Dashboard->new( $current_user );
            $obj->LoadById($id);
            if ( $obj and $obj->id ) {
                $page->child( basics       => title => loc('Basics'),       path => "/Dashboards/Modify.html?id=" . $obj->id);
                $page->child( content      => title => loc('Content'),      path => "/Dashboards/Queries.html?id=" . $obj->id);
                $page->child( subscription => title => loc('Subscription'), path => "/Dashboards/Subscription.html?id=" . $obj->id)
                    if $obj->CurrentUserCanSubscribe;
                $page->child( show         => title => loc('Show'),         path => "/Dashboards/" . $obj->id . "/" . $obj->Name)
            }
        }
    }


    if ( $request_path =~ m{^/Ticket/} ) {
        if ( ( $HTML::Mason::Commands::DECODED_ARGS->{'id'} || '' ) =~ /^(\d+)$/ ) {
            my $id  = $1;
            my $obj = RT::Ticket->new( $current_user );
            $obj->Load($id);

            if ( $obj and $obj->id ) {
                my $actions = $page->child( actions => title => loc('Actions'), sort_order  => 95 );

                my %can = %{ $obj->CurrentUser->PrincipalObj->HasRights( Object => $obj ) };
                $can{'_ModifyOwner'} = $obj->CurrentUserCanSetOwner();
                my $can = sub {
                    unless ($_[0] eq 'ExecuteCode') {
                        return $can{$_[0]} || $can{'SuperUser'};
                    } else {
                        return !RT->Config->Get('DisallowExecuteCode')
                            && ( $can{'ExecuteCode'} || $can{'SuperUser'} );
                    }
                };

                $page->child( bookmark => raw_html => $HTML::Mason::Commands::m->scomp( '/Ticket/Elements/Bookmark', id => $id ), sort_order => 98 );

                if ($can->('ModifyTicket')) {
                    $page->child( timer => raw_html => $HTML::Mason::Commands::m->scomp( '/Ticket/Elements/PopupTimerLink', id => $id ), sort_order => 99 );
                }

                $page->child( display => title => loc('Display'), path => "/Ticket/Display.html?id=" . $id );
                $page->child( history => title => loc('History'), path => "/Ticket/History.html?id=" . $id );

                # comment out until we can do it for an individual custom field
                #if ( $can->('ModifyTicket') || $can->('ModifyCustomField') ) {
                $page->child( basics => title => loc('Basics'), path => "/Ticket/Modify.html?id=" . $id );

                #}

                if ( $can->('ModifyTicket') || $can->('_ModifyOwner') || $can->('Watch') || $can->('WatchAsAdminCc') ) {
                    $page->child( people => title => loc('People'), path => "/Ticket/ModifyPeople.html?id=" . $id );
                }

                if ( $can->('ModifyTicket') ) {
                    $page->child( dates => title => loc('Dates'), path => "/Ticket/ModifyDates.html?id=" . $id );
                    $page->child( links => title => loc('Links'), path => "/Ticket/ModifyLinks.html?id=" . $id );
                }

                #if ( $can->('ModifyTicket') || $can->('ModifyCustomField') || $can->('_ModifyOwner') ) {
                $page->child( jumbo => title => loc('Jumbo'), path => "/Ticket/ModifyAll.html?id=" . $id );
                #}

                if ( RT->Config->Get('EnableReminders') ) {
                    $page->child( reminders => title => loc('Reminders'), path => "/Ticket/Reminders.html?id=" . $id );
                }

                if ( $can->('ModifyTicket') or $can->('ReplyToTicket') ) {
                    $actions->child( reply => title => loc('Reply'), path => "/Ticket/Update.html?Action=Respond;id=" . $id );
                }

                if ( $can->('ModifyTicket') or $can->('CommentOnTicket') ) {
                    $actions->child( comment => title => loc('Comment'), path => "/Ticket/Update.html?Action=Comment;id=" . $id );
                }

                if ( $can->('ForwardMessage') ) {
                    $actions->child( forward => title => loc('Forward'), path => "/Ticket/Forward.html?id=" . $id );
                }

                my $hide_resolve_with_deps = RT->Config->Get('HideResolveActionsWithDependencies')
                    && $obj->HasUnresolvedDependencies;

                my $current   = $obj->Status;
                my $lifecycle = $obj->LifecycleObj;
                my $i         = 1;
                foreach my $info ( $lifecycle->Actions($current) ) {
                    my $next = $info->{'to'};
                    next unless $lifecycle->IsTransition( $current => $next );

                    my $check = $lifecycle->CheckRight( $current => $next );
                    next unless $can->($check);

                    next if $hide_resolve_with_deps
                        && $lifecycle->IsInactive($next)
                        && !$lifecycle->IsInactive($current);

                    my $action = $info->{'update'} || '';
                    my $url = '/Ticket/';
                    $url .= "Update.html?". QueryString(
                        $action
                            ? (Action        => $action)
                            : (SubmitTicket  => 1, Status => $next),
                        DefaultStatus => $next,
                        id            => $id,
                    );
                    my $key = $info->{'label'} || ucfirst($next);
                    $actions->child( $key => title => loc( $key ), path => $url);
                }

                my ($can_take, $tmsg) = $obj->CurrentUserCanSetOwner( Type => 'Take' );
                my ($can_steal, $smsg) = $obj->CurrentUserCanSetOwner( Type => 'Steal' );
                my ($can_untake, $umsg) = $obj->CurrentUserCanSetOwner( Type => 'Untake' );
                if ( $can_take ){
                    $actions->child( take => title => loc('Take'), path => "/Ticket/Display.html?Action=Take;id=" . $id );
                }
                elsif ( $can_steal ){
                    $actions->child( steal => title => loc('Steal'), path => "/Ticket/Display.html?Action=Steal;id=" . $id );
                }
                elsif ( $can_untake ){
                    $actions->child( untake => title => loc('Untake'), path => "/Ticket/Display.html?Action=Untake;id=" . $id );
                }

                # TODO needs a "Can extract article into a class applied to this queue" check
                $actions->child( 'extract-article' =>
                    title => loc('Extract Article'),
                    path  => "/Articles/Article/ExtractIntoClass.html?Ticket=".$obj->id,
                ) if $current_user->HasRight( Right => 'ShowArticlesMenu', Object => RT->System );

                if ( defined $HTML::Mason::Commands::session{"tickets"} ) {
                    # we have to update session data if we get new ItemMap
                    my $updatesession = 1 unless ( $HTML::Mason::Commands::session{"tickets"}->{'item_map'} );

                    my $item_map = $HTML::Mason::Commands::session{"tickets"}->ItemMap;

                    if ($updatesession) {
                        $HTML::Mason::Commands::session{"tickets"}->PrepForSerialization();
                    }

                    my $search = $top->child('search')->child('tickets');
                    # Don't display prev links if we're on the first ticket
                    if ( $item_map->{$id}->{prev} ) {
                        $search->child( first =>
                            title => '<< ' . loc('First'), class => "nav", path => "/Ticket/Display.html?id=" . $item_map->{first});
                        $search->child( prev =>
                            title => '< ' . loc('Prev'),   class => "nav", path => "/Ticket/Display.html?id=" . $item_map->{$id}->{prev});
                    }
                    # Don't display next links if we're on the last ticket
                    if ( $item_map->{$id}->{next} ) {
                        $search->child( next =>
                            title => loc('Next') . ' >',  class => "nav", path => "/Ticket/Display.html?id=" . $item_map->{$id}->{next});
                        if ( $item_map->{last} ) {
                            $search->child( last =>
                                title => loc('Last') . ' >>', class => "nav", path => "/Ticket/Display.html?id=" . $item_map->{last});
                        }
                    }
                }
            }
        }
    }

    # Scope here so we can share in the Privileged callback
    my $args      = '';
    my $has_query = '';
    if (
        (
               $request_path =~ m{^/(?:Ticket|Transaction|Search)/}
            && $request_path !~ m{^/Search/Simple\.html}
        )
        || (   $request_path =~ m{^/Search/Simple\.html}
            && $HTML::Mason::Commands::DECODED_ARGS->{'q'} )
      )
    {
        my $class = $HTML::Mason::Commands::DECODED_ARGS->{Class}
            || ( $request_path =~ m{^/Transaction/} ? 'RT::Transactions' : 'RT::Tickets' );

        my ( $search, $hash_name );
        if ( $class eq 'RT::Tickets' ) {
            $search = $top->child('search')->child('tickets');
            $hash_name = 'CurrentSearchHash';
        }
        else {
            $search = $txns_tickets;
            $hash_name = join '-', 'CurrentSearchHash', $class, $HTML::Mason::Commands::DECODED_ARGS->{ObjectType} || 'RT::Ticket';
        }

        my $current_search = $HTML::Mason::Commands::session{$hash_name} || {};
        my $search_id = $HTML::Mason::Commands::DECODED_ARGS->{'SavedSearchLoad'} || $HTML::Mason::Commands::DECODED_ARGS->{'SavedSearchId'} || $current_search->{'SearchId'} || '';
        my $chart_id = $HTML::Mason::Commands::DECODED_ARGS->{'SavedChartSearchId'} || $current_search->{SavedChartSearchId};

        $has_query = 1 if ( $HTML::Mason::Commands::DECODED_ARGS->{'Query'} or $current_search->{'Query'} );

        my %query_args;
        my %fallback_query_args = (
            SavedSearchId => ( $search_id eq 'new' ) ? undef : $search_id,
            SavedChartSearchId => $chart_id,
            (
                map {
                    my $p = $_;
                    $p => $HTML::Mason::Commands::DECODED_ARGS->{$p} || $current_search->{$p}
                } qw(Query Format OrderBy Order Page Class ObjectType)
            ),
            RowsPerPage => (
                defined $HTML::Mason::Commands::DECODED_ARGS->{'RowsPerPage'}
                ? $HTML::Mason::Commands::DECODED_ARGS->{'RowsPerPage'}
                : $current_search->{'RowsPerPage'}
            ),
        );
        $fallback_query_args{Class} ||= $class;
        $fallback_query_args{ObjectType} ||= 'RT::Ticket';

        if ($query_string) {
            $args = '?' . $query_string;
        }
        else {
            my %final_query_args = ();
            # key => callback to avoid unnecessary work

            for my $param (keys %fallback_query_args) {
                $final_query_args{$param} = defined($query_args->{$param})
                                          ? $query_args->{$param}
                                          : $fallback_query_args{$param};
            }

            for my $field (qw(Order OrderBy)) {
                if ( ref( $final_query_args{$field} ) eq 'ARRAY' ) {
                    $final_query_args{$field} = join( "|", @{ $final_query_args{$field} } );
                } elsif (not defined $final_query_args{$field}) {
                    delete $final_query_args{$field};
                }
                else {
                    $final_query_args{$field} ||= '';
                }
            }

            $args = '?' . QueryString(%final_query_args);
        }

        my $current_search_menu;
        if (   $class eq 'RT::Tickets' && $request_path =~ m{^/Ticket}
            || $class eq 'RT::Transactions' && $request_path =~ m{^/Transaction} )
        {
            $current_search_menu = $search->child( current_search => title => loc('Current Search') );
            $current_search_menu->path("/Search/Results.html$args") if $has_query;
        }
        else {
            $current_search_menu = $page;
        }

        $current_search_menu->child( edit_search =>
            title => loc('Edit Search'), path => "/Search/Build.html" . ( ($has_query) ? $args : '' ) );
        $current_search_menu->child( advanced =>
            title => loc('Advanced'),    path => "/Search/Edit.html$args" );
        $current_search_menu->child( custom_date_ranges =>
            title => loc('Custom Date Ranges'), path => "/Search/CustomDateRanges.html" ) if $class eq 'RT::Tickets';
        if ($has_query) {
            $current_search_menu->child( results => title => loc('Show Results'), path => "/Search/Results.html$args" );
        }

        if ( $has_query ) {
            if ( $class eq 'RT::Tickets' ) {
                $current_search_menu->child( bulk  => title => loc('Bulk Update'), path => "/Search/Bulk.html$args" );
                $current_search_menu->child( chart => title => loc('Chart'),       path => "/Search/Chart.html$args" );
            }

            my $more = $current_search_menu->child( more => title => loc('Feeds') );

            $more->child( spreadsheet => title => loc('Spreadsheet'), path => "/Search/Results.tsv$args" );

            if ( $class eq 'RT::Tickets' ) {
                my %rss_data
                    = map { $_ => $query_args->{$_} || $fallback_query_args{$_} || '' } qw(Query Order OrderBy);
                my $RSSQueryString = "?"
                    . QueryString(
                    Query   => $rss_data{Query},
                    Order   => $rss_data{Order},
                    OrderBy => $rss_data{OrderBy}
                    );
                my $RSSPath = join '/', map $HTML::Mason::Commands::m->interp->apply_escapes( $_, 'u' ),
                    $current_user->UserObj->Name,
                    $current_user->UserObj->GenerateAuthString(
                    $rss_data{Query} . $rss_data{Order} . $rss_data{OrderBy} );

                $more->child( rss => title => loc('RSS'), path => "/NoAuth/rss/$RSSPath/$RSSQueryString" );
                my $ical_path = join '/', map $HTML::Mason::Commands::m->interp->apply_escapes( $_, 'u' ),
                    $current_user->UserObj->Name,
                    $current_user->UserObj->GenerateAuthString( $rss_data{Query} ),
                    $rss_data{Query};
                $more->child( ical => title => loc('iCal'), path => '/NoAuth/iCal/' . $ical_path );

                if ($request_path =~ m{^/Search/Results.html}
                    &&    #XXX TODO better abstraction
                    $current_user->HasRight( Right => 'SuperUser', Object => RT->System )
                   )
                {
                    my $shred_args = QueryString(
                        Search          => 1,
                        Plugin          => 'Tickets',
                        'Tickets:query' => $rss_data{'Query'},
                        'Tickets:limit' => $query_args->{'Rows'},
                    );

                    $more->child(
                        shredder => title => loc('Shredder'),
                        path     => '/Admin/Tools/Shredder/?' . $shred_args
                    );
                }
            }
        }
    }

    if ( $request_path =~ m{^/Article/} ) {
        if ( $HTML::Mason::Commands::DECODED_ARGS->{'id'} && $HTML::Mason::Commands::DECODED_ARGS->{'id'} =~ /^\d+$/ ) {
            my $id = $HTML::Mason::Commands::DECODED_ARGS->{'id'};
            $page->child( display => title => loc('Display'), path => "/Articles/Article/Display.html?id=".$id );
            $page->child( history => title => loc('History'), path => "/Articles/Article/History.html?id=".$id );
            $page->child( modify  => title => loc('Modify'),  path => "/Articles/Article/Edit.html?id=".$id );
        }
    }

    if ( $request_path =~ m{^/Articles/} ) {
        $page->child( search => title => loc("Search"),       path => "/Articles/Article/Search.html" );
        if ( $request_path =~ m{^/Articles/Article/} and ( $HTML::Mason::Commands::DECODED_ARGS->{'id'} || '' ) =~ /^(\d+)$/ ) {
            my $id  = $1;
            my $obj = RT::Article->new( $current_user );
            $obj->Load($id);

            if ( $obj and $obj->id ) {
                $page->child( display => title => loc("Display"), path => "/Articles/Article/Display.html?id=" . $id );
                $page->child( history => title => loc('History'), path => '/Articles/Article/History.html?id=' . $id );

                if ( $obj->CurrentUserHasRight('ModifyArticle') ) {
                    $page->child(modify => title => loc('Modify'), path => '/Articles/Article/Edit.html?id=' . $id );
                }
            }
        }

    }

    if ($request_path =~ m{^/Asset/} and $HTML::Mason::Commands::DECODED_ARGS->{id} and $HTML::Mason::Commands::DECODED_ARGS->{id} !~ /\D/) {
        _BuildAssetMenu( $request_path, $top, $widgets, $page, %args );
    } elsif ($request_path =~ m{^/Asset/Search/}) {
        my %search = map @{$_},
            grep defined $_->[1] && length $_->[1],
            map {ref $HTML::Mason::Commands::DECODED_ARGS->{$_} ? [$_, $HTML::Mason::Commands::DECODED_ARGS->{$_}[0]] : [$_, $HTML::Mason::Commands::DECODED_ARGS->{$_}] }
            grep /^(?:q|SearchAssets|!?(Name|Description|Catalog|Status|Role\..+|CF\..+)|Order(?:By)?|Page)$/,
            keys %$HTML::Mason::Commands::DECODED_ARGS;
        if ( $request_path =~ /Bulk/) {
            $page->child('search',
                title => loc('Show Results'),
                path => '/Asset/Search/?' . (keys %search ? QueryString(%search) : ''),
            );
        } else {
            $page->child('bulk',
                title => loc('Bulk Update'),
                path => '/Asset/Search/Bulk.html?' . (keys %search ? QueryString(%search) : ''),
            );
        }
        $page->child('csv',
            title => loc('Download Spreadsheet'),
            path  => '/Asset/Search/Results.tsv?' . (keys %search ? QueryString(%search) : ''),
        );
    } elsif ($request_path =~ m{^/Admin/Global/CustomFields/Catalog-Assets\.html$}) {
        $page->child("create", title => loc("Create New"), path => "/Admin/CustomFields/Modify.html?Create=1;LookupType=" . RT::Asset->CustomFieldLookupType);
    } elsif ($request_path =~ m{^/Admin/CustomFields(/|/index\.html)?$}
            and $HTML::Mason::Commands::DECODED_ARGS->{'Type'} and $HTML::Mason::Commands::DECODED_ARGS->{'Type'} eq RT::Asset->CustomFieldLookupType) {
        $page->child("create")->path( $page->child("create")->path . "&LookupType=" . RT::Asset->CustomFieldLookupType );
    } elsif ($request_path =~ m{^/Admin/Assets/Catalogs/}) {
        my $actions = $request_path =~ m{/((index|Create)\.html)?$}
            ? $page
            : $page->child("catalogs", title => loc("Catalogs"), path => "/Admin/Assets/Catalogs/");

        $actions->child("select", title => loc("Select"), path => "/Admin/Assets/Catalogs/");
        $actions->child("create", title => loc("Create"), path => "/Admin/Assets/Catalogs/Create.html");

        my $catalog = RT::Catalog->new( $current_user );
        $catalog->Load($HTML::Mason::Commands::DECODED_ARGS->{id}) if $HTML::Mason::Commands::DECODED_ARGS->{id};

        if ($catalog->id and $catalog->CurrentUserCanSee) {
            my $query = "id=" . $catalog->id;
            $page->child("modify", title => loc("Basics"), path => "/Admin/Assets/Catalogs/Modify.html?$query");
            $page->child("people", title => loc("Roles"),  path => "/Admin/Assets/Catalogs/Roles.html?$query");

            $page->child("cfs", title => loc("Asset Custom Fields"), path => "/Admin/Assets/Catalogs/CustomFields.html?$query");

            $page->child("group-rights", title => loc("Group Rights"), path => "/Admin/Assets/Catalogs/GroupRights.html?$query");
            $page->child("user-rights",  title => loc("User Rights"),  path => "/Admin/Assets/Catalogs/UserRights.html?$query");

            $page->child("default-values", title => loc('Default Values'), path => "/Admin/Assets/Catalogs/DefaultValues.html?$query");
        }
    }

    if ( $request_path =~ m{^/User/(Summary|History)\.html} ) {
        if ($page->child('summary')) {
            # Already set up from having AdminUser and ShowConfigTab;
            # but rename "Basics" to "Edit" in this context
            $page->child( 'basics' )->title( loc('Edit') );
        } elsif ( $current_user->HasRight( Object => $RT::System, Right => 'ShowUserHistory' ) ) {
            $page->child( display => title => loc('Summary'), path => '/User/Summary.html?id=' . $HTML::Mason::Commands::DECODED_ARGS->{'id'} );
            $page->child( history => title => loc('History'), path => '/User/History.html?id=' . $HTML::Mason::Commands::DECODED_ARGS->{'id'} );
        }
    }

    if ( $request_path =~ /^\/(?:index.html|$)/ ) {
        my $alt = loc('Edit');
        $page->child( edit => raw_html => q[<a id="page-edit" class="menu-item" href="] . RT->Config->Get('WebPath') . qq[/Prefs/MyRT.html"><span class="fas fa-cog" alt="$alt" data-toggle="tooltip" data-placement="top" data-original-title="$alt"></span></a>] );
    }

    # due to historical reasons of always having been in /Elements/Tabs
    $HTML::Mason::Commands::m->callback( CallbackName => 'Privileged', Path => $request_path, Search_Args => $args, Has_Query => $has_query, ARGSRef => \%args, CallbackPage => '/Elements/Tabs' );
}

sub _BuildAssetMenu {
    my $request_path = shift;
    my $top          = shift;
    my $widgets      = shift;
    my $page         = shift;

    my %args = ( @_ );

    my $current_user = $HTML::Mason::Commands::session{CurrentUser};

    my $id    = $HTML::Mason::Commands::DECODED_ARGS->{id};
    my $asset = RT::Asset->new( $current_user );
    $asset->Load($id);

    if ($asset->id) {
        $page->child("display",     title => HTML::Mason::Commands::loc("Display"),        path => "/Asset/Display.html?id=$id");
        $page->child("history",     title => HTML::Mason::Commands::loc("History"),        path => "/Asset/History.html?id=$id");
        $page->child("basics",      title => HTML::Mason::Commands::loc("Basics"),         path => "/Asset/Modify.html?id=$id");
        $page->child("links",       title => HTML::Mason::Commands::loc("Links"),          path => "/Asset/ModifyLinks.html?id=$id");
        $page->child("people",      title => HTML::Mason::Commands::loc("People"),         path => "/Asset/ModifyPeople.html?id=$id");
        $page->child("dates",       title => HTML::Mason::Commands::loc("Dates"),          path => "/Asset/ModifyDates.html?id=$id");

        for my $grouping (RT::CustomField->CustomGroupings($asset)) {
            my $cfs = $asset->CustomFields;
            $cfs->LimitToGrouping( $asset => $grouping );
            next unless $cfs->Count;
            $page->child(
                "cf-grouping-$grouping",
                title   => HTML::Mason::Commands::loc($grouping),
                path    => "/Asset/ModifyCFs.html?id=$id;Grouping=" . $HTML::Mason::Commands::m->interp->apply_escapes($grouping, 'u'),
            );
        }

        _BuildAssetMenuActionSubmenu( $request_path, $top, $widgets, $page, %args, Asset => $asset );
    }
}

sub _BuildAssetMenuActionSubmenu {
    my $request_path = shift;
    my $top          = shift;
    my $widgets      = shift;
    my $page         = shift;

    my %args = (
        Asset => undef,
        @_
    );

    my $asset = $args{Asset};
    my $id    = $asset->id;

    my $actions = $page->child("actions", title => HTML::Mason::Commands::loc("Actions"));
    $actions->child("create-linked-ticket", title => HTML::Mason::Commands::loc("Create linked ticket"), path => "/Asset/CreateLinkedTicket.html?Asset=$id");

    my $status    = $asset->Status;
    my $lifecycle = $asset->LifecycleObj;
    for my $action ( $lifecycle->Actions($status) ) {
        my $next = $action->{'to'};
        next unless $lifecycle->IsTransition( $status => $next );

        my $check = $lifecycle->CheckRight( $status => $next );
        next unless $asset->CurrentUserHasRight($check);

        my $label = $action->{'label'} || ucfirst($next);
        $actions->child(
            $label,
            title   => HTML::Mason::Commands::loc($label),
            path    => "/Asset/Modify.html?id=$id;Update=1;DisplayAfter=1;Status="
                        . $HTML::Mason::Commands::m->interp->apply_escapes($next, 'u'),

            class       => "asset-lifecycle-action",
            attributes  => {
                'data-current-status'   => $status,
                'data-next-status'      => $next,
            },
        );
    }
}

sub _BuildAdminMenu {
    my $request_path = shift;
    my $top          = shift;
    my $widgets      = shift;
    my $page         = shift;

    my %args = ( @_ );

    my $current_user = $HTML::Mason::Commands::session{CurrentUser};

    my $admin = $top->child( admin => title => loc('Admin'), path => '/Admin/' );
    if ( $current_user->HasRight( Object => RT->System, Right => 'AdminUsers' ) ) {
        my $users = $admin->child( users =>
            title       => loc('Users'),
            description => loc('Manage users and passwords'),
            path        => '/Admin/Users/',
        );
        $users->child( select => title => loc('Select'), path => "/Admin/Users/" );
        $users->child( create => title => loc('Create'), path => "/Admin/Users/Modify.html?Create=1" );
    }
    my $groups = $admin->child( groups =>
        title       => loc('Groups'),
        description => loc('Manage groups and group membership'),
        path        => '/Admin/Groups/',
    );
    $groups->child( select => title => loc('Select'), path => "/Admin/Groups/" );
    $groups->child( create => title => loc('Create'), path => "/Admin/Groups/Modify.html?Create=1" );

    my $queues = $admin->child( queues =>
        title       => loc('Queues'),
        description => loc('Manage queues and queue-specific properties'),
        path        => '/Admin/Queues/',
    );
    $queues->child( select => title => loc('Select'), path => "/Admin/Queues/" );
    $queues->child( create => title => loc('Create'), path => "/Admin/Queues/Modify.html?Create=1" );

    if ( $current_user->HasRight( Object => RT->System, Right => 'AdminCustomField' ) ) {
        my $cfs = $admin->child( 'custom-fields' =>
            title       => loc('Custom Fields'),
            description => loc('Manage custom fields and custom field values'),
            path        => '/Admin/CustomFields/',
        );
        $cfs->child( select => title => loc('Select'), path => "/Admin/CustomFields/" );
        $cfs->child( create => title => loc('Create'), path => "/Admin/CustomFields/Modify.html?Create=1" );
    }

    if ( $current_user->HasRight( Object => RT->System, Right => 'AdminCustomRoles' ) ) {
        my $roles = $admin->child( 'custom-roles' =>
            title       => loc('Custom Roles'),
            description => loc('Manage custom roles'),
            path        => '/Admin/CustomRoles/',
        );
        $roles->child( select => title => loc('Select'), path => "/Admin/CustomRoles/" );
        $roles->child( create => title => loc('Create'), path => "/Admin/CustomRoles/Modify.html?Create=1" );
    }

    if ( $current_user->HasRight( Object => RT->System, Right => 'ModifyScrips' ) ) {
        my $scrips = $admin->child( 'scrips' =>
            title       => loc('Scrips'),
            description => loc('Manage scrips'),
            path        => '/Admin/Scrips/',
        );
        $scrips->child( select => title => loc('Select'), path => "/Admin/Scrips/" );
        $scrips->child( create => title => loc('Create'), path => "/Admin/Scrips/Create.html" );
    }

    my $admin_global = $admin->child( global =>
        title       => loc('Global'),
        description => loc('Manage properties and configuration which apply to all queues'),
        path        => '/Admin/Global/',
    );

    my $scrips = $admin_global->child( scrips =>
        title       => loc('Scrips'),
        description => loc('Modify scrips which apply to all queues'),
        path        => '/Admin/Global/Scrips.html',
    );
    $scrips->child( select => title => loc('Select'), path => "/Admin/Global/Scrips.html" );
    $scrips->child( create => title => loc('Create'), path => "/Admin/Scrips/Create.html?Global=1" );

    my $conditions = $admin_global->child( conditions =>
        title => loc('Conditions'),
        description => loc('Edit system conditions'),
        path        => '/Admin/Global/Conditions.html',
    );
    $conditions->child( select => title => loc('Select'), path => "/Admin/Global/Conditions.html" );
    $conditions->child( create => title => loc('Create'), path => "/Admin/Conditions/Create.html" );

    my $actions   = $admin_global->child( actions =>
        title => loc('Actions'),
        description => loc('Edit system actions'),
        path        => '/Admin/Global/Actions.html',
    );
    $actions->child( select => title => loc('Select'), path => "/Admin/Global/Actions.html" );
    $actions->child( create => title => loc('Create'), path => "/Admin/Actions/Create.html" );

    my $templates = $admin_global->child( templates =>
        title       => loc('Templates'),
        description => loc('Edit system templates'),
        path        => '/Admin/Global/Templates.html',
    );
    $templates->child( select => title => loc('Select'), path => "/Admin/Global/Templates.html" );
    $templates->child( create => title => loc('Create'), path => "/Admin/Global/Template.html?Create=1" );

    my $cfadmin = $admin_global->child( 'custom-fields' =>
        title       => loc('Custom Fields'),
        description => loc('Modify global custom fields'),
        path        => '/Admin/Global/CustomFields/index.html',
    );
    $cfadmin->child( users =>
        title       => loc('Users'),
        description => loc('Select custom fields for all users'),
        path        => '/Admin/Global/CustomFields/Users.html',
    );
    $cfadmin->child( groups =>
        title       => loc('Groups'),
        description => loc('Select custom fields for all user groups'),
        path        => '/Admin/Global/CustomFields/Groups.html',
    );
    $cfadmin->child( queues =>
        title       => loc('Queues'),
        description => loc('Select custom fields for all queues'),
        path        => '/Admin/Global/CustomFields/Queues.html',
    );
    $cfadmin->child( tickets =>
        title       => loc('Tickets'),
        description => loc('Select custom fields for tickets in all queues'),
        path        => '/Admin/Global/CustomFields/Queue-Tickets.html',
    );
    $cfadmin->child( transactions =>
        title       => loc('Ticket Transactions'),
        description => loc('Select custom fields for transactions on tickets in all queues'),
        path        => '/Admin/Global/CustomFields/Queue-Transactions.html',
    );
    $cfadmin->child( 'custom-fields' =>
        title       => loc('Articles'),
        description => loc('Select Custom Fields for Articles in all Classes'),
        path        => '/Admin/Global/CustomFields/Class-Article.html',
    );
    $cfadmin->child( 'assets' =>
        title       => loc('Assets'),
        description => loc('Select Custom Fields for Assets in all Catalogs'),
        path        => '/Admin/Global/CustomFields/Catalog-Assets.html',
    );

    my $article_admin = $admin->child( articles => title => loc('Articles'), path => "/Admin/Articles/index.html" );
    my $class_admin = $article_admin->child(classes => title => loc('Classes'), path => '/Admin/Articles/Classes/' );
    $class_admin->child( select =>
        title       => loc('Select'),
        description => loc('Modify and Create Classes'),
        path        => '/Admin/Articles/Classes/',
    );
    $class_admin->child( create =>
        title       => loc('Create'),
        description => loc('Modify and Create Custom Fields for Articles'),
        path        => '/Admin/Articles/Classes/Modify.html?Create=1',
    );


    my $cfs = $article_admin->child( 'custom-fields' =>
        title => loc('Custom Fields'),
        path  => '/Admin/CustomFields/index.html?'.$HTML::Mason::Commands::m->comp('/Elements/QueryString', Type => 'RT::Class-RT::Article'),
    );
    $cfs->child( select =>
        title => loc('Select'),
        path => '/Admin/CustomFields/index.html?'.$HTML::Mason::Commands::m->comp('/Elements/QueryString', Type => 'RT::Class-RT::Article'),
    );
    $cfs->child( create =>
        title => loc('Create'),
        path => '/Admin/CustomFields/Modify.html?'.$HTML::Mason::Commands::m->comp("/Elements/QueryString", Create=>1, LookupType=> "RT::Class-RT::Article" ),
    );

    my $assets_admin = $admin->child( assets => title => loc("Assets"), path => '/Admin/Assets/' );
    my $catalog_admin = $assets_admin->child( catalogs =>
        title       => loc("Catalogs"),
        description => loc("Modify asset catalogs"),
        path        => "/Admin/Assets/Catalogs/"
    );
    $catalog_admin->child( "select", title => loc("Select"), path => $catalog_admin->path );
    $catalog_admin->child( "create", title => loc("Create"), path => "Create.html" );


    my $assets_cfs = $assets_admin->child( "cfs",
        title => loc("Custom Fields"),
        description => loc("Modify asset custom fields"),
        path => "/Admin/CustomFields/?Type=" . RT::Asset->CustomFieldLookupType
    );
    $assets_cfs->child( "select", title => loc("Select"), path => $assets_cfs->path );
    $assets_cfs->child( "create", title => loc("Create"), path => "/Admin/CustomFields/Modify.html?Create=1&LookupType=" . RT::Asset->CustomFieldLookupType);

    $admin_global->child( 'group-rights' =>
        title       => loc('Group Rights'),
        description => loc('Modify global group rights'),
        path        => '/Admin/Global/GroupRights.html',
    );
    $admin_global->child( 'user-rights' =>
        title       => loc('User Rights'),
        description => loc('Modify global user rights'),
        path        => '/Admin/Global/UserRights.html',
    );
    $admin_global->child( 'my-rt' =>
        title       => loc('RT at a glance'),
        description => loc('Modify the default "RT at a glance" view'),
        path        => '/Admin/Global/MyRT.html',
    );
    $admin_global->child( 'dashboards-in-menu' =>
        title       => loc('Dashboards in menu'),
        description => loc('Customize dashboards in menu'),
        path        => '/Admin/Global/DashboardsInMenu.html',
    );
    $admin_global->child( 'topics' =>
        title       => loc('Topics'),
        description => loc('Modify global article topics'),
        path        => '/Admin/Global/Topics.html',
    );

    my $admin_tools = $admin->child( tools =>
        title       => loc('Tools'),
        description => loc('Use other RT administrative tools'),
        path        => '/Admin/Tools/',
    );
    $admin_tools->child( configuration =>
        title       => loc('System Configuration'),
        description => loc('Detailed information about your RT setup'),
        path        => '/Admin/Tools/Configuration.html',
    );
    $admin_tools->child( theme =>
        title       => loc('Theme'),
        description => loc('Customize the look of your RT'),
        path        => '/Admin/Tools/Theme.html',
    );
    if (RT->Config->Get('StatementLog')
        && $current_user->HasRight( Right => 'SuperUser', Object => RT->System )) {
       $admin_tools->child( 'sql-queries' =>
           title       => loc('SQL Queries'),
           description => loc('Browse the SQL queries made in this process'),
           path        => '/Admin/Tools/Queries.html',
       );
    }
    $admin_tools->child( rights_inspector =>
        title => loc('Rights Inspector'),
        description => loc('Search your configured rights'),
        path  => '/Admin/Tools/RightsInspector.html',
    );
    $admin_tools->child( shredder =>
        title       => loc('Shredder'),
        description => loc('Permanently wipeout data from RT'),
        path        => '/Admin/Tools/Shredder',
    );

    if ( $request_path =~ m{^/Admin/(Queues|Users|Groups|CustomFields|CustomRoles)} ) {
        my $type = $1;

        my %labels = (
            Queues       => loc("Queues"),
            Users        => loc("Users"),
            Groups       => loc("Groups"),
            CustomFields => loc("Custom Fields"),
            CustomRoles  => loc("Custom Roles"),
        );

        my $section;
        if ( $request_path =~ m|^/Admin/$type/?(?:index.html)?$|
             || (    $request_path =~ m|^/Admin/$type/(?:Modify.html)$|
                  && $HTML::Mason::Commands::DECODED_ARGS->{'Create'} )
           )
        {
            $section = $page;

        } else {
            $section = $page->child( select => title => $labels{$type},
                                     path => "/Admin/$type/" );
        }

        $section->child( select => title => loc('Select'), path => "/Admin/$type/" );
        $section->child( create => title => loc('Create'), path => "/Admin/$type/Modify.html?Create=1" );
    }

    if ( $request_path =~ m{^/Admin/Queues} ) {
        if ( $HTML::Mason::Commands::DECODED_ARGS->{'id'} && $HTML::Mason::Commands::DECODED_ARGS->{'id'} =~ /^\d+$/
                ||
              $HTML::Mason::Commands::DECODED_ARGS->{'Queue'} && $HTML::Mason::Commands::DECODED_ARGS->{'Queue'} =~ /^\d+$/
                ) {
            my $id = $HTML::Mason::Commands::DECODED_ARGS->{'Queue'} || $HTML::Mason::Commands::DECODED_ARGS->{'id'};
            my $queue_obj = RT::Queue->new( $current_user );
            $queue_obj->Load($id);

            if ( $queue_obj and $queue_obj->id ) {
                my $queue = $page;
                $queue->child( basics => title => loc('Basics'),   path => "/Admin/Queues/Modify.html?id=" . $id );
                $queue->child( people => title => loc('Watchers'), path => "/Admin/Queues/People.html?id=" . $id );

                my $templates = $queue->child(templates => title => loc('Templates'), path => "/Admin/Queues/Templates.html?id=" . $id);
                $templates->child( select => title => loc('Select'), path => "/Admin/Queues/Templates.html?id=".$id);
                $templates->child( create => title => loc('Create'), path => "/Admin/Queues/Template.html?Create=1;Queue=".$id);

                my $scrips = $queue->child( scrips => title => loc('Scrips'), path => "/Admin/Queues/Scrips.html?id=" . $id);
                $scrips->child( select => title => loc('Select'), path => "/Admin/Queues/Scrips.html?id=" . $id );
                $scrips->child( create => title => loc('Create'), path => "/Admin/Scrips/Create.html?Queue=" . $id);

                my $cfs = $queue->child( 'custom-fields' => title => loc('Custom Fields') );
                my $ticket_cfs = $cfs->child( 'tickets' => title => loc('Tickets'),
                    path => '/Admin/Queues/CustomFields.html?SubType=RT::Ticket&id=' . $id );

                my $txn_cfs = $cfs->child( 'transactions' => title => loc('Transactions'),
                    path => '/Admin/Queues/CustomFields.html?SubType=RT::Ticket-RT::Transaction&id='.$id );

                $queue->child( 'group-rights' => title => loc('Group Rights'), path => "/Admin/Queues/GroupRights.html?id=".$id );
                $queue->child( 'user-rights' => title => loc('User Rights'), path => "/Admin/Queues/UserRights.html?id=" . $id );
                $queue->child( 'history' => title => loc('History'), path => "/Admin/Queues/History.html?id=" . $id );
                $queue->child( 'default-values' => title => loc('Default Values'), path => "/Admin/Queues/DefaultValues.html?id=" . $id );

                # due to historical reasons of always having been in /Elements/Tabs
                $HTML::Mason::Commands::m->callback( CallbackName => 'PrivilegedQueue', queue_id => $id, page_menu => $queue, CallbackPage => '/Elements/Tabs' );
            }
        }
    }
    if ( $request_path =~ m{^(/Admin/Users|/User/(Summary|History)\.html)} and $admin->child("users") ) {
        if ( $HTML::Mason::Commands::DECODED_ARGS->{'id'} && $HTML::Mason::Commands::DECODED_ARGS->{'id'} =~ /^\d+$/ ) {
            my $id = $HTML::Mason::Commands::DECODED_ARGS->{'id'};
            my $obj = RT::User->new( $current_user );
            $obj->Load($id);

            if ( $obj and $obj->id ) {
                $page->child( basics      => title => loc('Basics'),         path => "/Admin/Users/Modify.html?id=" . $id );
                $page->child( memberships => title => loc('Memberships'),    path => "/Admin/Users/Memberships.html?id=" . $id );
                $page->child( history     => title => loc('History'),        path => "/Admin/Users/History.html?id=" . $id );
                $page->child( 'my-rt'     => title => loc('RT at a glance'), path => "/Admin/Users/MyRT.html?id=" . $id );
                $page->child( 'dashboards-in-menu' =>
                    title => loc('Dashboards in menu'),
                    path  => '/Admin/Users/DashboardsInMenu.html?id=' . $id,
                );
                if ( RT->Config->Get('Crypt')->{'Enable'} ) {
                    $page->child( keys    => title => loc('Private keys'),   path => "/Admin/Users/Keys.html?id=" . $id );
                }
                $page->child( 'summary'   => title => loc('User Summary'),   path => "/User/Summary.html?id=" . $id );
            }
        }

    }

    if ( $request_path =~ m{^(/Admin/Groups|/Group/(Summary|History)\.html)} ) {
        if ( $HTML::Mason::Commands::DECODED_ARGS->{'id'} && $HTML::Mason::Commands::DECODED_ARGS->{'id'} =~ /^\d+$/ ) {
            my $id = $HTML::Mason::Commands::DECODED_ARGS->{'id'};
            my $obj = RT::Group->new( $current_user );
            $obj->Load($id);

            if ( $obj and $obj->id ) {
                $page->child( basics         => title => loc('Basics'),       path => "/Admin/Groups/Modify.html?id=" . $obj->id );
                $page->child( members        => title => loc('Members'),      path => "/Admin/Groups/Members.html?id=" . $obj->id );
                $page->child( memberships    => title => loc('Memberships'),  path => "/Admin/Groups/Memberships.html?id=" . $obj->id );
                $page->child( 'links'     =>
                              title       => loc("Links"),
                              path        => "/Admin/Groups/ModifyLinks.html?id=" . $obj->id,
                              description => loc("Group links"),
                );
                $page->child( 'group-rights' => title => loc('Group Rights'), path => "/Admin/Groups/GroupRights.html?id=" . $obj->id );
                $page->child( 'user-rights'  => title => loc('User Rights'),  path => "/Admin/Groups/UserRights.html?id=" . $obj->id );
                $page->child( history        => title => loc('History'),      path => "/Admin/Groups/History.html?id=" . $obj->id );
                $page->child( 'summary'   =>
                              title       => loc("Group Summary"),
                              path        => "/Group/Summary.html?id=" . $obj->id,
                              description => loc("Group summary page"),
                );
            }
        }
    }

    if ( $request_path =~ m{^/Admin/CustomFields/} ) {
        if ( $HTML::Mason::Commands::DECODED_ARGS->{'id'} && $HTML::Mason::Commands::DECODED_ARGS->{'id'} =~ /^\d+$/ ) {
            my $id = $HTML::Mason::Commands::DECODED_ARGS->{'id'};
            my $obj = RT::CustomField->new( $current_user );
            $obj->Load($id);

            if ( $obj and $obj->id ) {
                $page->child( basics           => title => loc('Basics'),       path => "/Admin/CustomFields/Modify.html?id=".$id );
                $page->child( 'group-rights'   => title => loc('Group Rights'), path => "/Admin/CustomFields/GroupRights.html?id=" . $id );
                $page->child( 'user-rights'    => title => loc('User Rights'),  path => "/Admin/CustomFields/UserRights.html?id=" . $id );
                unless ( $obj->IsOnlyGlobal ) {
                    $page->child( 'applies-to' => title => loc('Applies to'),   path => "/Admin/CustomFields/Objects.html?id=" . $id );
                }
            }
        }
    }

    if ( $request_path =~ m{^/Admin/CustomRoles} ) {
        if ( $HTML::Mason::Commands::DECODED_ARGS->{'id'} && $HTML::Mason::Commands::DECODED_ARGS->{'id'} =~ /^\d+$/ ) {
            my $id = $HTML::Mason::Commands::DECODED_ARGS->{'id'};
            my $obj = RT::CustomRole->new( $current_user );
            $obj->Load($id);

            if ( $obj and $obj->id ) {
                $page->child( basics       => title => loc('Basics'),       path => "/Admin/CustomRoles/Modify.html?id=".$id );
                $page->child( 'applies-to' => title => loc('Applies to'),   path => "/Admin/CustomRoles/Objects.html?id=" . $id );
            }
        }
    }

    if ( $request_path =~ m{^/Admin/Scrips/} ) {
        if ( $HTML::Mason::Commands::m->request_args->{'id'} && $HTML::Mason::Commands::m->request_args->{'id'} =~ /^\d+$/ ) {
            my $id = $HTML::Mason::Commands::m->request_args->{'id'};
            my $obj = RT::Scrip->new( $current_user );
            $obj->Load($id);

            my ( $admin_cat, $create_path_arg, $from_query_param );
            my $from_arg = $HTML::Mason::Commands::DECODED_ARGS->{'From'} || q{};
            my ($from_queue) = $from_arg =~ /^(\d+)$/;
            if ( $from_queue ) {
                $admin_cat = "Queues/Scrips.html?id=$from_queue";
                $create_path_arg = "?Queue=$from_queue";
                $from_query_param = "&From=$from_queue";
            }
            elsif ( $from_arg eq 'Global' ) {
                $admin_cat = 'Global/Scrips.html';
                $create_path_arg = '?Global=1';
                $from_query_param = '&From=Global';
            }
            else {
                $admin_cat = 'Scrips';
                $from_query_param = $create_path_arg = q{};
            }
            my $scrips = $page->child( scrips => title => loc('Scrips'), path => "/Admin/${admin_cat}" );
            $scrips->child( select => title => loc('Select'), path => "/Admin/${admin_cat}" );
            $scrips->child( create => title => loc('Create'), path => "/Admin/Scrips/Create.html${create_path_arg}" );

            $page->child( basics => title => loc('Basics') => path => "/Admin/Scrips/Modify.html?id=" . $id . $from_query_param );
            $page->child( 'applies-to' => title => loc('Applies to'), path => "/Admin/Scrips/Objects.html?id=" . $id . $from_query_param );
        }
        elsif ( $request_path =~ m{^/Admin/Scrips/(index\.html)?$} ) {
            HTML::Mason::Commands::PageMenu->child( select => title => loc('Select') => path => "/Admin/Scrips/" );
            HTML::Mason::Commands::PageMenu->child( create => title => loc('Create') => path => "/Admin/Scrips/Create.html" );
        }
        elsif ( $request_path =~ m{^/Admin/Scrips/Create\.html$} ) {
            my ($queue) = $HTML::Mason::Commands::DECODED_ARGS->{'Queue'} && $HTML::Mason::Commands::DECODED_ARGS->{'Queue'} =~ /^(\d+)$/;
            my $global_arg = $HTML::Mason::Commands::DECODED_ARGS->{'Global'};
            if ($queue) {
                HTML::Mason::Commands::PageMenu->child( select => title => loc('Select') => path => "/Admin/Queues/Scrips.html?id=$queue" );
                HTML::Mason::Commands::PageMenu->child( create => title => loc('Create') => path => "/Admin/Scrips/Create.html?Queue=$queue" );
            } elsif ($global_arg) {
                HTML::Mason::Commands::PageMenu->child( select => title => loc('Select') => path => "/Admin/Global/Scrips.html" );
                HTML::Mason::Commands::PageMenu->child( create => title => loc('Create') => path => "/Admin/Scrips/Create.html?Global=1" );
            } else {
                HTML::Mason::Commands::PageMenu->child( select => title => loc('Select') => path => "/Admin/Scrips" );
                HTML::Mason::Commands::PageMenu->child( create => title => loc('Create') => path => "/Admin/Scrips/Create.html" );
            }
        }
    }

    if ( $request_path =~ m{^/Admin/Global/Scrips\.html} ) {
        $page->child( select => title => loc('Select'), path => "/Admin/Global/Scrips.html" );
        $page->child( create => title => loc('Create'), path => "/Admin/Scrips/Create.html?Global=1" );
    }

    if ( $request_path =~ m{^/Admin(?:/Global)?/Conditions} ) {
        $page->child( select => title => loc('Select'), path => "/Admin/Global/Conditions.html" );
        $page->child( create => title => loc('Create'), path => "/Admin/Conditions/Create.html" );
    }

    if ( $request_path =~ m{^/Admin(?:/Global)?/Actions} ) {
        $page->child( select => title => loc('Select'), path => "/Admin/Global/Actions.html" );
        $page->child( create => title => loc('Create'), path => "/Admin/Actions/Create.html" );
    }

    if ( $request_path =~ m{^/Admin/Global/Templates?\.html} ) {
        $page->child( select => title => loc('Select'), path => "/Admin/Global/Templates.html" );
        $page->child( create => title => loc('Create'), path => "/Admin/Global/Template.html?Create=1" );
    }

    if ( $request_path =~ m{^/Admin/Articles/Classes/} ) {
        if ( my $id = $HTML::Mason::Commands::DECODED_ARGS->{'id'} ) {
            my $obj = RT::Class->new( $current_user );
            $obj->Load($id);

            if ( $obj and $obj->id ) {
                my $section = $page->child( select => title => loc("Classes"), path => "/Admin/Articles/Classes/" );
                $section->child( select => title => loc('Select'), path => "/Admin/Articles/Classes/" );
                $section->child( create => title => loc('Create'), path => "/Admin/Articles/Classes/Modify.html?Create=1" );

                $page->child( basics          => title => loc('Basics'),        path => "/Admin/Articles/Classes/Modify.html?id=".$id );
                $page->child( topics          => title => loc('Topics'),        path => "/Admin/Articles/Classes/Topics.html?id=".$id );
                $page->child( 'custom-fields' => title => loc('Custom Fields'), path => "/Admin/Articles/Classes/CustomFields.html?id=".$id );
                $page->child( 'group-rights'  => title => loc('Group Rights'),  path => "/Admin/Articles/Classes/GroupRights.html?id=".$id );
                $page->child( 'user-rights'   => title => loc('User Rights'),   path => "/Admin/Articles/Classes/UserRights.html?id=".$id );
                $page->child( 'applies-to'    => title => loc('Applies to'),    path => "/Admin/Articles/Classes/Objects.html?id=$id" );
            }
        } else {
            $page->child( select => title => loc('Select'), path => "/Admin/Articles/Classes/" );
            $page->child( create => title => loc('Create'), path => "/Admin/Articles/Classes/Modify.html?Create=1" );
        }
    }
}

sub BuildSelfServiceNav {
    my $request_path = shift;
    my $top          = shift;
    my $widgets      = shift;
    my $page         = shift;

    my %args = ( @_ );

    my $current_user = $HTML::Mason::Commands::session{CurrentUser};

    my $queues = RT::Queues->new( $current_user );
    $queues->UnLimit;

    my $queue_count = 0;
    my $queue_id;

    while ( my $queue = $queues->Next ) {
        next unless $queue->CurrentUserHasRight('CreateTicket');
        $queue_id = $queue->id;
        $queue_count++;
        last if ( $queue_count > 1 );
    }


    if ( $queue_count > 1 ) {
        $top->child( new => title => loc('New ticket'), path => '/SelfService/CreateTicketInQueue.html' );
    } elsif ( $queue_id ) {
        $top->child( new => title => loc('New ticket'), path => '/SelfService/Create.html?Queue=' . $queue_id );
    }
    my $tickets = $top->child( tickets => title => loc('Tickets'), path => '/SelfService/' );
    $tickets->child( open   => title => loc('Open tickets'),   path => '/SelfService/' );
    $tickets->child( closed => title => loc('Closed tickets'), path => '/SelfService/Closed.html' );

    $top->child( "assets", title => loc("Assets"), path => "/SelfService/Asset/" )
        if $current_user->HasRight( Right => 'ShowAssetsMenu', Object => RT->System );

    my $username = '<span class="current-user">'
                 . $HTML::Mason::Commands::m->interp->apply_escapes($current_user->Name, 'h')
                 . '</span>';
    my $about_me = $top->child( preferences =>
        title        => loc('Logged in as [_1]', $username),
        escape_title => 0,
        sort_order   => 99,
    );

    if ( ( RT->Config->Get('SelfServiceUserPrefs') || '' ) eq 'view-info' ||
        $current_user->HasRight( Right => 'ModifySelf', Object => RT->System ) ) {
        $about_me->child( prefs => title => loc('Preferences'), path => '/SelfService/Prefs.html' );
    }

    my $logout_url = RT->Config->Get('LogoutURL');
    if ( $current_user->Name
         && (   !RT->Config->Get('WebRemoteUserAuth')
              || RT->Config->Get('WebFallbackToRTLogin') )) {
        $about_me->child( logout => title => loc('Logout'), path => $logout_url );
    }

    if ($current_user->HasRight( Right => 'ShowArticle', Object => RT->System )) {
        $widgets->child( 'goto-article' => raw_html => $HTML::Mason::Commands::m->scomp('/SelfService/Elements/SearchArticle') );
    }

    $widgets->child( goto => raw_html => $HTML::Mason::Commands::m->scomp('/SelfService/Elements/GotoTicket') );

    if ($request_path =~ m{^/SelfService/Asset/} and $HTML::Mason::Commands::DECODED_ARGS->{id}) {
        my $id   = $HTML::Mason::Commands::DECODED_ARGS->{id};
        $page->child("display",     title => loc("Display"),        path => "/SelfService/Asset/Display.html?id=$id");
        $page->child("history",     title => loc("History"),        path => "/SelfService/Asset/History.html?id=$id");

        if (Menu->child("new")) {
            my $actions = $page->child("actions", title => loc("Actions"));
            $actions->child("create-linked-ticket", title => loc("Create linked ticket"), path => "/SelfService/Asset/CreateLinkedTicket.html?Asset=$id");
        }
    }

    # due to historical reasons of always having been in /Elements/Tabs
    $HTML::Mason::Commands::m->callback( CallbackName => 'SelfService', Path => $request_path, ARGSRef => \%args, CallbackPage => '/Elements/Tabs' );
}

1;

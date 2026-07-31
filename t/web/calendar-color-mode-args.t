use strict;
use warnings;

# How a calendar's color mode is resolved, in two parts.
#
# 1. A CalendarColorMode request argument overrides the mode the search was
#    saved with, in both directions. Asking for 'date' has to work as well as
#    asking for 'status', which means testing whether an argument was supplied
#    rather than what it resolves to.
#
# 2. A saved search widget's title bar and its body are built by separate
#    requests: share/html/Elements/ShowSearch renders the legend button and the
#    status filter icon, then htmx fetches the calendar from
#    share/html/Search/Elements/Calendar. Both resolve the mode through
#    ResolveCalendarColorMode, and ShowSearch passes any requested mode along in
#    the body URL, so the two halves always describe the same mode.

use RT::Test tests => undef;

my ( $baseurl, $m ) = RT::Test->started_ok;
my $url = $m->rt_base_url;

ok $m->login, 'logged in as root';

my $root = RT::CurrentUser->new;
$root->Load('root');

my $today = RT::Date->new( RT->SystemUser );
$today->SetToNow;

my $ticket = RT::Test->create_ticket(
    Queue   => 'General',
    Subject => 'calendar color mode test',
    Starts  => $today->ISO,
    Due     => $today->ISO,
);
ok $ticket->Id, 'created a ticket with Starts and Due set';

sub create_calendar_search {
    my ( $name, $mode ) = @_;
    my $search = RT::SavedSearch->new($root);
    my ( $ok, $msg ) = $search->Create(
        Name        => $name,
        Type        => 'Ticket',
        PrincipalId => $root->Id,
        Content     => {
            Query             => 'id > 0',
            Format            => q{'__Starts__', '__Due__'},
            SearchType        => 'Ticket',
            SearchDisplayMode => 'Calendar',
            CalendarColorMode => $mode,
        },
    );
    ok $ok, "created saved search '$name': $msg";
    return $search;
}

my %search = (
    status => create_calendar_search( 'Calendar saved as status', 'status' ),
    date   => create_calendar_search( 'Calendar saved as date',   'date' ),
);

my $dashboard = RT::Dashboard->new($root);
my ( $ok, $msg ) = $dashboard->Create(
    Name        => 'Calendar color mode dashboard',
    PrincipalId => $root->Id,
);
ok $ok, "created dashboard: $msg";

( $ok, $msg ) = $dashboard->SetContent(
    {   Elements => [
            {   Layout   => 'col-md-12',
                Elements => [
                    [   {   portlet_type => 'search',
                            id           => $search{status}->Id,
                            description  => 'Saved Search: Calendar saved as status',
                        },
                        {   portlet_type => 'search',
                            id           => $search{date}->Id,
                            description  => 'Saved Search: Calendar saved as date',
                        },
                    ],
                ],
            },
        ],
    }
);
ok $ok, "added both calendars to the dashboard: $msg";

diag "Collect the widget title bar ShowSearch renders on the dashboard page";

# TitleBox only emits the title bar on this request; the body is fetched
# separately from the hx-get URL below, which is where Calendar runs.
$m->get_ok( $url . 'Dashboards/' . $dashboard->Id . '/Calendar color mode dashboard' );

sub calendar_widgets {
    return $m->dom->find('div.titlebox')->grep( sub { $_->at('span.rt-inline-icon[data-bs-toggle="modal"]') } )->map(
        sub {
            {   legend_label => $_->at('span.rt-inline-icon[data-bs-toggle="modal"] a')->attr('aria-label'),
                has_funnel   => $_->at('span.calendar-status-filter-icon') ? 1 : 0,
                body_url     => $_->at('div[hx-get]')->attr('hx-get'),
            };
        }
    )->each;
}

my @widgets = calendar_widgets();
is scalar @widgets, 2, 'found both calendar widgets on the dashboard';

# The dashboard lists the status calendar first, then the date one.
my %titlebar = ( status => $widgets[0], date => $widgets[1] );

is $titlebar{status}{legend_label}, 'Status Colors',
    'status calendar: legend button is labelled for status colors';
is $titlebar{status}{has_funnel}, 1, 'status calendar: title bar has a status filter icon';
is $titlebar{date}{legend_label}, 'Date Type Colors',
    'date calendar: legend button is labelled for date colors';
is $titlebar{date}{has_funnel}, 0, 'date calendar: title bar has no status filter icon';

sub legend_title {
    return $m->dom->at('div.modal[id^="calendar-date-colors-modal"] .modal-title')->text;
}

diag "A CalendarColorMode argument overrides the saved mode in both directions";

# Baselines: with no argument each widget renders the mode it was saved with.
$m->get_ok( $baseurl . $titlebar{status}{body_url} );
is legend_title(), 'Status Colors', 'status calendar body defaults to the saved status mode';

$m->get_ok( $baseurl . $titlebar{date}{body_url} );
is legend_title(), 'Date Type Colors', 'date calendar body defaults to the saved date mode';

# Asking for status when date was saved...
$m->get_ok( $baseurl . $titlebar{date}{body_url} . '&CalendarColorMode=status' );
is legend_title(), 'Status Colors',
    'CalendarColorMode=status overrides a saved date mode';

# ...and asking for date when status was saved, which only works if the caller
# tests whether an argument was supplied rather than what it resolves to.
$m->get_ok( $baseurl . $titlebar{status}{body_url} . '&CalendarColorMode=date' );
is legend_title(), 'Date Type Colors',
    'CalendarColorMode=date overrides a saved status mode';
ok !$m->dom->at('table.rt-calendar .ticket-entry.status-color'),
    'events are not colored by status when date colors were requested';

diag "The title bar and the body of one widget describe the same mode";

# ShowSearch renders the title bar and Calendar renders the body, in two separate
# requests, so ShowSearch has to resolve the mode the same way Calendar does and
# pass the request along in the body URL it builds. Otherwise the button and the
# panel it opens can describe the widget differently.
$m->get_ok( $url . 'Dashboards/' . $dashboard->Id . '/Calendar color mode dashboard?CalendarColorMode=status' );

my @preview = calendar_widgets();
is scalar @preview, 2, 'both calendar widgets still render';

# This is the calendar saved as date, asked to preview status colors.
my $previewed = $preview[1];

is $previewed->{legend_label}, 'Status Colors',
    'title bar follows the requested status mode rather than the saved date mode';
is $previewed->{has_funnel}, 1,
    'title bar offers the status filter when status colors were requested';
like $previewed->{body_url}, qr/CalendarColorMode=status/,
    'body URL carries the requested mode so the body resolves it the same way';

$m->get_ok( $baseurl . $previewed->{body_url} );

is legend_title(), $previewed->{legend_label},
    'legend title matches the label on the button that opens it';
ok $m->dom->at('.calendar-status-filter-container'),
    'status filter dropdown is rendered for the funnel icon to open';

undef $m;
done_testing;

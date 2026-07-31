use strict;
use warnings;

use RT::Test tests => undef;

my ( $baseurl, $m ) = RT::Test->started_ok;
my $url = $m->rt_base_url;

ok $m->login, 'logged in as root';

my $root = RT::CurrentUser->new;
$root->Load('root');

# A ticket with dates in the current month so the calendar renders events. In
# status color mode the legend is built from the lifecycles of the events that
# were actually rendered, so an empty calendar would produce an empty legend.
my $today = RT::Date->new( RT->SystemUser );
$today->SetToNow;

my $ticket = RT::Test->create_ticket(
    Queue   => 'General',
    Subject => 'calendar legend test',
    Starts  => $today->ISO,
    Due     => $today->ISO,
);
ok $ticket->Id, 'created a ticket with Starts and Due set';

diag "Create two calendar saved searches using different color modes";

my %search;
for my $mode (qw(status date)) {
    my $search = RT::SavedSearch->new($root);
    my ( $ok, $msg ) = $search->Create(
        Name        => "Calendar by $mode",
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
    ok $ok, "created saved search 'Calendar by $mode': $msg";
    $search{$mode} = $search;
}

my $dashboard = RT::Dashboard->new($root);
my ( $ok, $msg ) = $dashboard->Create(
    Name        => 'Calendar legend dashboard',
    PrincipalId => $root->Id,
);
ok $ok, "created dashboard: $msg";

# The status calendar is deliberately first: with duplicate modal ids every
# info button resolves to the first legend in the document.
( $ok, $msg ) = $dashboard->SetContent(
    {   Elements => [
            {   Layout   => 'col-md-12',
                Elements => [
                    [   {   portlet_type => 'search',
                            id           => $search{status}->Id,
                            description  => 'Saved Search: Calendar by status',
                        },
                        {   portlet_type => 'search',
                            id           => $search{date}->Id,
                            description  => 'Saved Search: Calendar by date',
                        },
                    ],
                ],
            },
        ],
    }
);
ok $ok, "added both calendars to the dashboard: $msg";

diag "Each calendar widget must point its legend button at its own modal";

$m->get_ok( $url . 'Dashboards/' . $dashboard->Id . '/Calendar legend dashboard' );

my @widgets = $m->dom->find('div.titlebox')
    ->grep( sub { $_->at('span.rt-inline-icon[data-bs-toggle="modal"]') } )->each;
is scalar @widgets, 2, 'found both calendar widgets on the dashboard';

my @targets;
my @htmx_urls;
for my $widget (@widgets) {
    my $target = $widget->at('span.rt-inline-icon[data-bs-toggle="modal"]')->attr('data-bs-target');
    like $target, qr/^#calendar-date-colors-modal/, 'legend button targets a calendar color modal';
    push @targets, $target;

    my $loader = $widget->at('div[hx-get]');
    ok $loader, 'widget has an htmx loader';
    push @htmx_urls, $loader->attr('hx-get');
}

isnt $targets[0], $targets[1],
    'the two calendar widgets target different legend modals';

diag "Each widget renders a legend whose id matches its own button, and whose contents match its own color mode";

my @expected = (
    { title => 'Status Colors',    entry => 'new' },
    { title => 'Date Type Colors', entry => 'Starts' },
);

my @modal_ids;
for my $i ( 0, 1 ) {
    $m->get_ok( $baseurl . $htmx_urls[$i] );

    my $modal = $m->dom->at('div.modal[id^="calendar-date-colors-modal"]');
    ok $modal, "widget $i rendered a color legend";

    is '#' . $modal->attr('id'), $targets[$i],
        "widget $i legend id matches the modal its own info button opens";
    push @modal_ids, $modal->attr('id');

    is $modal->at('.modal-title')->text, $expected[$i]{title},
        "widget $i legend is titled '$expected[$i]{title}'";
    is $modal->at('.modal-body .ticket-entry span')->text, $expected[$i]{entry},
        "widget $i legend lists '$expected[$i]{entry}' first";
}

isnt $modal_ids[0], $modal_ids[1], 'the two rendered legends have different ids';

undef $m;
done_testing;

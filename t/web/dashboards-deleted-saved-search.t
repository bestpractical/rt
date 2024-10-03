use strict;
use warnings;

use RT::Test tests => undef;
use JSON;
my ( $url, $m ) = RT::Test->started_ok;
ok( $m->login, 'logged in' );

# create a saved search
$m->get_ok( $url . "/Search/Build.html?Query=" . 'id=1' );

$m->submit_form(
    form_name => 'BuildQuery',
    fields    => { SavedSearchName => 'foo', },
    button    => 'SavedSearchSave',
);

my $search_id = ($m->form_number(3)->find_input('SavedSearchLoad')->possible_values)[1];
$m->submit_form(
    form_name => 'BuildQuery',
    fields    => { SavedSearchLoad => $search_id },
    button    => 'SavedSearchSave',
);

$m->content_like(
    qr/name="SavedSearchName"\s+value="foo"/,
    'found Description input with the value filled'
);

# create a dashboard with the created search

$m->get_ok( $url . "/Dashboards/Modify.html?Create=1" );
$m->submit_form(
    form_name => 'ModifyDashboard',
    fields    => { Name => 'bar' },
);

$m->content_contains('Dashboard created', 'dashboard saved' );
my $dashboard_queries_link = $m->find_link( text_regex => qr/Content/ );
my ( $dashboard_id ) = $dashboard_queries_link->url =~ /id=(\d+)/;

$m->get_ok( $url . "/Dashboards/Queries.html?id=$dashboard_id" );

$m->content_lacks( 'value="Update"', 'no update button' );

# add foo saved search to the dashboard

my $content = [
    {
        Layout   => 'col-md-8, col-md-4',
        Elements => [
            [
                {
                    portlet_type => 'search',
                    id           => $search_id,
                    description  => "Ticket: foo",
                }
            ],
            [],
        ],
    }
];

$m->submit_form_ok(
    {
        form_id => 'pagelayout-form-modify',
        fields => {
            id => $dashboard_id,
            Content => JSON::encode_json($content),
        },
        button  => 'Update',
    },
    "removed search foo from dashboard"
);
$m->content_contains( 'Dashboard updated' );

$m->get_ok( $url . "/Dashboards/Queries.html?id=$dashboard_id" );
# delete the created search

$m->get_ok( $url ); # Get rid of CSRF page
$m->get_ok( $url . "/Search/Build.html?Query=" . 'id=1' );
$m->submit_form(
    form_name => 'BuildQuery',
    fields    => { SavedSearchLoad => $search_id },
);

$m->form_name('BuildQuery');
$m->untick( 'SavedSearchEnabled', 1 );
$m->submit_form(
    form_name => 'BuildQuery',
    button  => 'SavedSearchSave',
);

$m->content_contains( 'Updated saved search', 'disabled search foo' );

# here is what we really want to test

$m->get_ok( $url . "/Dashboards/Queries.html?id=$dashboard_id" );
$m->content_contains('Unable to find search Ticket: foo', 'found deleted message' );

# Only the message contains Ticket: foo.
$m->text_unlike( qr/Ticket: foo.*Ticket: foo/s, 'no disabled search on page' );

delete $content->[0]{Elements}[0][0];
$m->submit_form_ok(
    {
        form_id => 'pagelayout-form-modify',
        fields => {
            id => $dashboard_id,
            Content => JSON::encode_json($content),
        },
        button  => 'Update',
    },
    "removed search foo from dashboard"
);

like( $m->uri, qr/results=[A-Za-z0-9]{32}/, 'URL redirected for results' );
$m->content_contains( 'Dashboard updated' );

$m->get_ok( $url . "/Dashboards/Queries.html?id=$dashboard_id" );
$m->content_lacks('Unable to find search Ticket: foo', 'deleted message is gone' );

done_testing;

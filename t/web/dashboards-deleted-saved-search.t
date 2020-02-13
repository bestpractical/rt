use strict;
use warnings;

use RT::Test tests => undef;
my ( $url, $m ) = RT::Test->started_ok;
ok( $m->login, 'logged in' );

# create a saved search
$m->get_ok( $url . "/Search/Build.html?Query=" . 'id=1' );

$m->submit_form(
    form_name => 'BuildQuery',
    fields    => { SavedSearchDescription => 'foo', },
    button    => 'SavedSearchSave',
);

my ( $search_uri, $user_id, $search_id ) =
  $m->content =~ /value="(RT::User-(\d+)-SavedSearch-(\d+))"/;
$m->submit_form(
    form_name => 'BuildQuery',
    fields    => { SavedSearchLoad => $search_uri },
    button    => 'SavedSearchSave',
);

$m->content_like( qr/name="SavedSearchDelete"\s+value="Delete"/,
    'found Delete button' );
$m->content_like(
    qr/name="SavedSearchDescription"\s+value="foo"/,
    'found Description input with the value filled'
);

# create a dashboard with the created search

$m->get_ok( $url . "/Dashboards/Modify.html?Create=1" );
$m->submit_form(
    form_name => 'ModifyDashboard',
    fields    => { Name => 'bar' },
);

$m->content_contains('Saved dashboard bar', 'dashboard saved' );
my $dashboard_queries_link = $m->find_link( text_regex => qr/Content/ );
my ( $dashboard_id ) = $dashboard_queries_link->url =~ /id=(\d+)/;

$m->get_ok( $url . "/Dashboards/Queries.html?id=$dashboard_id" );

$m->content_lacks( 'value="Update"', 'no update button' );

# add foo saved search to the dashboard

my $payload = {
    "dashboard_id" => $dashboard_id,
    "panes"        => {
        "body"    => [
            {
              "description" => "foo",
              "name" => "RT::User-" . $user_id . "-SavedSearch-" . $search_id,
              "searchId" => "",
              "searchType" => "Ticket",
              "type" => "saved"
            },
        ],
        "sidebar" => [
        ]
    }
};

my $json = JSON::to_json( $payload );
my $res  = $m->post(
    $url . '/Helpers/UpdateDashboard',
    [ content => $json ],
);
is( $res->code, 200, "added search foo to dashboard bar" );

# delete the created search

$m->get_ok( $url . "/Search/Build.html?Query=" . 'id=1' );
$m->submit_form(
    form_name => 'BuildQuery',
    fields    => { SavedSearchLoad => $search_uri },
);
$m->submit_form(
    form_name => 'BuildQuery',
    button    => 'SavedSearchDelete',
);

$m->content_lacks( $search_uri, 'deleted search foo' );

# here is what we really want to test

$m->get_ok( $url . "/Dashboards/Queries.html?id=$dashboard_id" );
$m->content_contains('Unable to find search Saved Search: foo', 'found deleted message' );

$payload = {
    "dashboard_id" => $dashboard_id,
    "panes"        => {
        "body"    => [
        ],
        "sidebar" => [
        ]
    }
};

$json = JSON::to_json( $payload );
$res  = $m->post(
    $url . '/Helpers/UpdateDashboard',
    [ content => $json ],
);
is( $res->code, 200, "added search foo to dashboard" );

$m->content_lacks('Unable to find search Saved Search: foo', 'deleted message is gone' );

done_testing;

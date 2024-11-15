use strict;
use warnings;

use RT::Test tests => undef;

my $root = RT::Test->load_or_create_user( Name => 'root' );
my ($baseurl, $m) = RT::Test->started_ok;

my $url = $m->rt_base_url;

ok($m->login, 'logged in');

# create a search
$m->follow_link_ok({text => 'Tickets'}, 'to query builder');
$m->form_name('BuildQuery');

$m->field(ValueOfid => 10 );
$m->click('AddClause');
$m->text_contains( 'id < 10', 'added new clause');

$m->form_name('BuildQuery');
$m->field(SavedSearchName => 'Original Name');
$m->click('SavedSearchSave');

# get the saved search name from the content
my $search_id = ($m->form_number(3)->find_input('SavedSearchLoad')->possible_values)[1];
my $search_widget = {
    portlet_type => 'search',
    id           => $search_id,
    description  => "Ticket: Original Name",
};

# create the inner dashboard
$m->get_ok("$url/Dashboards/Modify.html?Create=1");
$m->form_name('ModifyDashboard');
$m->field('Name' => 'inner dashboard');
$m->click_button(value => 'Create');
$m->text_contains('Dashboard created');

my ($inner_id) = $m->content =~ /name="id" value="(\d+)"/;
ok($inner_id, "got an ID, $inner_id");

my $dashboard_widget = {
    portlet_type => 'dashboard',
    id           => $inner_id,
    description  => "Dashboard: inner dashboard",
};

# create a dashboard
$m->get_ok("$url/Dashboards/Modify.html?Create=1");
$m->form_name('ModifyDashboard');
$m->field('Name' => 'cachey dashboard');
$m->click_button(value => 'Create');
$m->text_contains('Dashboard created');

my ($dashboard_id) = $m->content =~ /name="id" value="(\d+)"/;
ok($dashboard_id, "got an ID, $dashboard_id");

# add the search to the dashboard
$m->follow_link_ok({text => 'Content'});

my $content = [
    {
        Layout   => 'col-md-8, col-md-4',
        Elements => [
            [
                $search_widget,
                $dashboard_widget,

            ],
            [],
        ],
    }
];

my $res = $m->post(
    $url . 'Dashboards/Queries.html?id=' . $dashboard_id,
    { Update => 1, Content => JSON::encode_json($content) },
);

is( $res->code, 200, "add 'Original Name' and 'inner dashboard' portlets to body" );
like( $m->uri, qr/results=[A-Za-z0-9]{32}/, 'URL redirected for results' );
$m->content_contains( 'Dashboard updated' );

# subscribe to the dashboard
$m->follow_link_ok({text => 'Subscription'});
$m->text_contains('Ticket: Original Name');
$m->text_contains('Dashboard: inner dashboard');
$m->form_name('SubscribeDashboard');
$m->click_button(name => 'Save');
$m->text_contains('Subscribed to dashboard cachey dashboard');

# rename the search
$m->follow_link_ok({text => 'Tickets'}, 'to query builder');
my $form = $m->form_name('BuildQuery');
my @input = $form->find_input('SavedSearchLoad');
$form->value('SavedSearchLoad' => $search_id );
$m->click_button(value => 'Load');
$m->text_contains('Loaded saved search "Original Name"');

$m->form_name('BuildQuery');
$m->field('SavedSearchName' => 'New Name');
$m->field('SavedSearchDescription' => 'New Name');
$m->click_button(value => 'Update');
$m->text_contains('Updated saved search "New Name"');

# rename the dashboard
$m->get_ok("/Dashboards/Modify.html?id=$inner_id");
$m->form_name('ModifyDashboard');
$m->field('Name' => 'recursive dashboard');
$m->click_button(value => 'Save Changes');
$m->text_contains('Name changed from "inner dashboard" to "recursive dashboard"');

# check subscription page again
$m->get_ok("/Dashboards/Subscription.html?id=$dashboard_id");
TODO: {
    local $TODO = 'we cache search names too aggressively';
    $m->text_contains('Ticket: New Name');
    $m->text_unlike(qr/Ticket: Original Name/); # t-w-m lacks text_lacks

    $m->text_contains('Dashboard: recursive dashboard');
    $m->text_unlike(qr/Dashboard: inner dashboard/); # t-w-m lacks text_lacks
}

$m->get_ok("/Dashboards/Render.html?id=$dashboard_id");
$m->text_contains('New Name');
$m->text_unlike(qr/Original Name/); # t-w-m lacks text_lacks

done_testing;

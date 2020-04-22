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
$m->field(SavedSearchDescription => 'Original Name');
$m->click('SavedSearchSave');

# create the inner dashboard
$m->get_ok($url . "Dashboards/Modify.html?Create=1");
$m->form_name('ModifyDashboard');
$m->field('Name' => 'inner dashboard');
$m->click_button(value => 'Create');
$m->text_contains('Saved dashboard inner dashboard');

my ($inner_id) = $m->content =~ /name="id" value="(\d+)"/;
ok($inner_id, "got an ID for inner dashboard, $inner_id");

# create a dashboard
$m->get_ok($url . "Dashboards/Modify.html?Create=1");
$m->form_name('ModifyDashboard');
$m->field('Name' => 'cachey dashboard');
$m->click_button(value => 'Create');
$m->text_contains('Saved dashboard cachey dashboard');

my ($dashboard_id) = $m->content =~ /name="id" value="(\d+)"/;
ok($dashboard_id, "got an ID for cachey dashboard, $dashboard_id");

# add the search to the dashboard
$m->follow_link_ok({text => 'Content'});

# we need to get the saved search id from the content before submitting the args.
my $regex = 'data-type="saved" data-name="RT::User-' . $root->id . '-SavedSearch-(\d+)"';
my ($saved_search_id) = $m->content =~ /$regex/;
ok($saved_search_id, "got an ID for the saved search, $saved_search_id");

my $args = {
    UpdateSearches => "Save",
    dashboard_id   => $dashboard_id,
    body           => [],
    sidebar        => [],
};

# add 'Original Name' and 'inner dashboard' portlets to body
push(
    @{$args->{body}},
    (
      "saved-" . "RT::User-" . $root->id . "-SavedSearch-" . $saved_search_id,
      "dashboard-dashboard-" . $inner_id . "-RT::User-" . $root->id,
    )
);

my $res = $m->post(
    $url . 'Dashboards/Queries.html?id=' . $dashboard_id,
    $args,
);

is( $res->code, 200, "add 'Original Name' and 'inner dashboard' portlets to body" );
like( $m->uri, qr/results=[A-Za-z0-9]{32}/, 'URL redirected for results' );
$m->content_contains( 'Dashboard updated' );

# subscribe to the dashboard
$m->get_ok($url . "Dashboards/" . $dashboard_id . "/cachey%20dashboard");
$m->follow_link_ok({text => 'Subscription'});
$m->text_contains('Saved Search: Original Name');
$m->text_contains('Dashboard: inner dashboard');
$m->form_name('SubscribeDashboard');
$m->click_button(name => 'Save');
$m->text_contains('Subscribed to dashboard cachey dashboard');

# rename the search
$m->follow_link_ok({text => 'Tickets'}, 'to query builder');
my $form = $m->form_name('BuildQuery');
my @input = $form->find_input('SavedSearchLoad');
my ($search_value) =
  map { ( $_->possible_values )[1] }
  grep { ( $_->value_names )[1] =~ /Original Name/ } @input;
$form->value('SavedSearchLoad' => $search_value );
$m->click_button(value => 'Load');
$m->text_contains('Loaded saved search "Original Name"');

$m->form_name('BuildQuery');
$m->field('SavedSearchDescription' => 'New Name');
$m->click_button(value => 'Update');
$m->text_contains('Updated saved search "New Name"');

# rename the dashboard
$m->get_ok($url . "Dashboards/Modify.html?id=$inner_id");
$m->form_name('ModifyDashboard');
$m->field('Name' => 'recursive dashboard');
$m->click_button(value => 'Save Changes');
$m->text_contains('Dashboard recursive dashboard updated');

# check subscription page again
TODO: {
    local $TODO = 'we cache search names too aggressively';
    $m->get_ok($url . "Dashboards/Subscription.html?id=$dashboard_id");
    $m->text_contains('Saved Search: New Name');
    $m->text_unlike(qr/Saved Search: Original Name/); # t-w-m lacks text_lacks

    $m->text_contains('Dashboard: recursive dashboard');
    $m->text_unlike(qr/Dashboard: inner dashboard/); # t-w-m lacks text_lacks
}

$m->get_ok($url . "Dashboards/Render.html?id=$dashboard_id");
$m->text_contains('New Name');
$m->text_unlike(qr/Original Name/); # t-w-m lacks text_lacks

done_testing;

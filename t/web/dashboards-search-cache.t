use strict;
use warnings;

use RT::Test tests => 33;
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
$m->get_ok("$url/Dashboards/Modify.html?Create=1");
$m->form_name('ModifyDashboard');
$m->field('Name' => 'inner dashboard');
$m->click_button(value => 'Create');
$m->text_contains('Saved dashboard inner dashboard');

my ($inner_id) = $m->content =~ /name="id" value="(\d+)"/;
ok($inner_id, "got an ID, $inner_id");

# create a dashboard
$m->get_ok("$url/Dashboards/Modify.html?Create=1");
$m->form_name('ModifyDashboard');
$m->field('Name' => 'cachey dashboard');
$m->click_button(value => 'Create');
$m->text_contains('Saved dashboard cachey dashboard');

my ($dashboard_id) = $m->content =~ /name="id" value="(\d+)"/;
ok($dashboard_id, "got an ID, $dashboard_id");

# add the search to the dashboard
$m->follow_link_ok({text => 'Content'});
my $form = $m->form_name('Dashboard-Searches-body');
my @input = $form->find_input('Searches-body-Available');
my ($search_value) =
  map { ( $_->possible_values )[1] }
  grep { ( $_->value_names )[1] =~ /Saved Search: Original Name/ } @input;
$form->value('Searches-body-Available' => $search_value );
$m->click_button(name => 'add');
$m->text_contains('Dashboard updated');

# add the dashboard to the dashboard
$m->follow_link_ok({text => 'Content'});
$form = $m->form_name('Dashboard-Searches-body');
@input = $form->find_input('Searches-body-Available');
my ($dashboard_value) =
  map { ( $_->possible_values )[1] }
  grep { ( $_->value_names )[1] =~ /Dashboard: inner dashboard/ } @input;
$form->value('Searches-body-Available' => $dashboard_value );
$m->click_button(name => 'add');
$m->text_contains('Dashboard updated');

# subscribe to the dashboard
$m->follow_link_ok({text => 'Subscription'});
$m->text_contains('Saved Search: Original Name');
$m->text_contains('Dashboard: inner dashboard');
$m->form_name('SubscribeDashboard');
$m->click_button(name => 'Save');
$m->text_contains('Subscribed to dashboard cachey dashboard');

# rename the search
$m->follow_link_ok({text => 'Tickets'}, 'to query builder');
$form = $m->form_name('BuildQuery');
@input = $form->find_input('SavedSearchLoad');
($search_value) =
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
$m->get_ok("/Dashboards/Modify.html?id=$inner_id");
$m->form_name('ModifyDashboard');
$m->field('Name' => 'recursive dashboard');
$m->click_button(value => 'Save Changes');
$m->text_contains('Dashboard recursive dashboard updated');

# check subscription page again
$m->get_ok("/Dashboards/Subscription.html?id=$dashboard_id");
TODO: {
    local $TODO = 'we cache search names too aggressively';
    $m->text_contains('Saved Search: New Name');
    $m->text_unlike(qr/Saved Search: Original Name/); # t-w-m lacks text_lacks

    $m->text_contains('Dashboard: recursive dashboard');
    $m->text_unlike(qr/Dashboard: inner dashboard/); # t-w-m lacks text_lacks
}

$m->get_ok("/Dashboards/Render.html?id=$dashboard_id");
$m->text_contains('New Name');
$m->text_unlike(qr/Original Name/); # t-w-m lacks text_lacks

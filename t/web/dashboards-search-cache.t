#!/usr/bin/perl -w
use strict;

use RT::Test tests => 20;
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
my ($search) =
  map { ( $_->possible_values )[1] }
  grep { ( $_->value_names )[1] =~ /Saved Search: Original Name/ } @input;
$form->value('Searches-body-Available' => $search );
$m->click_button(name => 'add');
$m->text_contains('Dashboard updated');

# subscribe to the dashboard
$m->follow_link_ok({text => 'Subscription'});
$m->text_contains('Saved Search: Original Name');
$m->form_name('SubscribeDashboard');
$m->click_button(name => 'Save');
$m->text_contains('Subscribed to dashboard cachey dashboard');

# rename the search
$m->follow_link_ok({text => 'Tickets'}, 'to query builder');
$form = $m->form_name('BuildQuery');
@input = $form->find_input('SavedSearchLoad');
($search) =
  map { ( $_->possible_values )[1] }
  grep { ( $_->value_names )[1] =~ /Original Name/ } @input;
$form->value('SavedSearchLoad' => $search );
$m->click_button(value => 'Load');
$m->text_contains('Loaded saved search "Original Name"');

$m->form_name('BuildQuery');
$m->field('SavedSearchDescription' => 'New Name');
$m->click_button(value => 'Update');
$m->text_contains('Updated saved search "New Name"');

# check subscription page again
$m->get_ok("/Dashboards/Subscription.html?id=$dashboard_id");
TODO: {
    local $TODO = 'we cache search names too aggressively';
    $m->text_contains('Saved Search: New Name');
    $m->text_unlike(qr/Saved Search: Original Name/); # t-w-m lacks text_lacks
}

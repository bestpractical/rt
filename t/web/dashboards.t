#!/usr/bin/perl -w
use strict;

use RT::Test strict => 1, l10n => 1;
plan tests => 98;
use RT::Dashboard;
my ($baseurl, $m) = RT::Test->started_ok;

my $url = $m->rt_base_url;

my $user_obj = RT::Model::User->new(current_user => RT->system_user);
my ($ret, $msg) = $user_obj->load_or_create_by_email('customer@example.com');
ok($ret, 'ACL test user creation');
$user_obj->set_name('customer');
$user_obj->set_privileged(1);
($ret, $msg) = $user_obj->set_password('customer');
$user_obj->principal->grant_right(right => 'ModifySelf');
my $currentuser = RT::CurrentUser->new( id => $user_obj->id );

my $onlooker = RT::Model::User->new(current_user => RT->system_user);
($ret, $msg) = $onlooker->load_or_create_by_email('onlooker@example.com');
ok($ret, 'ACL test user creation');
$onlooker->set_name('onlooker');
$onlooker->set_privileged(1);
($ret, $msg) = $onlooker->set_password('onlooker');

my $queue = RT::Model::Queue->new(current_user => RT->system_user);
$queue->create(name => 'SearchQueue'.$$);

for my $user ($user_obj, $onlooker) {
    $user->principal->grant_right(right => 'ModifySelf');
    for my $right (qw/SeeQueue ShowTicket OwnTicket/) {
        $user->principal->grant_right(right => $right, object => $queue);
    }
}

ok $m->login(customer => 'customer'), "logged in";

$m->get_ok($url."/Dashboards/index.html");
$m->content_lacks(">Create<", "No 'new dashboard' link because we have no CreateOwnDashboard");

$m->no_warnings_ok;

$user_obj->principal->grant_right(
    right  => 'ModifyOwnDashboard',
    object => RT->system
);

# Modify itself is no longer good enough, you need Create
$m->get_ok($url."/Dashboards/Modify.html?create=1");

# permission denied is not error in RT
$m->no_warnings_ok;

$user_obj->principal->grant_right(
    right  => 'CreateOwnDashboard',
    object => RT->system
);

$m->get_ok($url."/Dashboards/Modify.html?create=1");
$m->content_lacks("Permission denied");
$m->content_contains("Save Changes");

$m->get_ok($url."/Dashboards/index.html");
$m->content_contains("Create", "'Create' link because we now have ModifyOwnDashboard");
$m->follow_link_ok({text => "Create"});
$m->form_name( 'modify_dashboard' );
$m->field("name" => 'different dashboard');
$m->content_lacks('Delete', "Delete button hidden because we are creating");
$m->click_button(value => 'Save Changes');
$m->content_lacks("No permission to create dashboards");
$m->content_contains("Saved dashboard different dashboard");
$m->get_ok($url."/Dashboards/index.html");
$m->content_lacks("different dashboard", "we lack SeeOwnDashboard");

$user_obj->principal->grant_right(right => 'SeeOwnDashboard', object => RT->system );

$m->get_ok($url."/Dashboards/index.html");
$m->content_contains("different dashboard", "we now have SeeOwnDashboard");
$m->content_lacks("Permission denied");


$m->content_lacks('Delete', "Delete button hidden because we lack DeleteOwnDashboard");


$m->follow_link_ok({text => "different dashboard"});
$m->content_contains("Basics");
$m->content_contains("Queries");
$m->content_lacks("Subscription", "we don't have the SubscribeDashboard right");
$m->content_contains("Show");

$m->follow_link_ok({text => "Basics"});
$m->content_contains("Modify the dashboard different dashboard");
$m->follow_link_ok({text => "Queries"});

$m->content_contains("Modify the queries of dashboard different dashboard");
$m->form_name( 'Dashboard-Searches-body' );
$m->field('Searches-body-Available' => ["search-2-RT::System-1"]);
$m->click_button(name => 'add');
$m->content_contains("Dashboard updated");

my $dashboard = RT::Dashboard->new( current_user => $currentuser);
my ($id) = $m->content =~ /name="id" value="(\d+)"/;
ok($id, "got an ID, $id");
$dashboard->load_by_id($id);
is($dashboard->name, "different dashboard");

is($dashboard->privacy, 'RT::Model::User-' . $user_obj->id, "correct privacy");
is($dashboard->possible_hidden_searches, 0, "all searches are visible");

my @searches = $dashboard->searches;
is(@searches, 1, "one saved search in the dashboard");
like($searches[0]->name, qr/newest unowned tickets/, "correct search name");

$m->form_name('Dashboard-Searches-body');
$m->field('Searches-body-Available' => ["search-1-RT::System-1"]);

$m->click_button(name => 'add');
$m->content_contains("Dashboard updated");

Jifty::DBI::Record::Cachable->flush_cache;
$dashboard = RT::Dashboard->new( current_user => $currentuser);
$dashboard->load_by_id($id);

@searches = $dashboard->searches;
is(@searches, 2, "two saved searches in the dashboard");
like($searches[0]->name, qr/newest unowned tickets/, "correct existing search name");
like($searches[1]->name, qr/highest priority tickets I own/, "correct new search name");

my $ticket = RT::Model::Ticket->new(current_user => RT->system_user);
$ticket->create(
    queue     => $queue->id,
	requestor => [ $user_obj->name ],
	owner     => $user_obj,
	subject   => 'dashboard test',
);

$m->follow_link_ok({text => "Show"});
$m->content_contains("20 highest priority tickets I own");
$m->content_contains("20 newest unowned tickets");
$m->content_lacks("Bookmarked Tickets");
$m->content_contains("dashboard test", "ticket subject");

$m->get_ok("/Dashboards/$id/This fragment left intentionally blank");
$m->content_contains("20 highest priority tickets I own");
$m->content_contains("20 newest unowned tickets");
$m->content_lacks("Bookmarked Tickets");
$m->content_contains("dashboard test", "ticket subject");

$m->get_ok("/Dashboards/Subscription.html?dashboard_id=$id");
$m->form_name( 'subscribe_dashboard' );
$m->click_button(name => 'save');
$m->content_contains("Permission denied");
$m->no_warnings_ok;

Jifty::DBI::Record::Cachable->flush_cache;
is($user_obj->attributes->named('Subscription'), 0, "no subscriptions");

$user_obj->principal->grant_right(right => 'SubscribeDashboard', object => RT->system );

$m->get_ok("/Dashboards/Modify.html?id=$id");
$m->follow_link_ok({text => "Subscription"});
$m->content_contains("Subscribe to dashboard different dashboard");
$m->content_contains("Unowned Tickets");
$m->content_contains("My Tickets");
$m->content_lacks("Bookmarked Tickets", "only dashboard queries show up");

$m->form_name( 'subscribe_dashboard' );
$m->click_button(name => 'save');
$m->content_lacks("Permission denied");
$m->content_contains("Subscribed to dashboard different dashboard");

Jifty::DBI::Record::Cachable->flush_cache;
TODO: {
    local $TODO = "some kind of caching is still happening (it works if I remove the check above)";
    is($user_obj->attributes->named('Subscription'), 1, "we have a subscription");
};

$m->get_ok("/Dashboards/Modify.html?id=$id");
$m->follow_link_ok({text => "Subscription"});
$m->content_contains("Modify the subscription to dashboard different dashboard");

$m->get_ok("/Dashboards/Modify.html?id=$id&delete=1");
$m->content_contains("Permission denied", "unable to delete dashboard because we lack DeleteOwnDashboard");
$m->no_warnings_ok;

$user_obj->principal->grant_right(right => 'DeleteOwnDashboard', object => RT->system );
$m->get_ok("/Dashboards/Modify.html?id=$id");
$m->content_contains('Delete', "Delete button shows because we have DeleteOwnDashboard");

$m->form_name( 'modify_dashboard' );
$m->click_button(name => 'delete');
$m->content_contains("Deleted dashboard $id");

$m->get_ok("/Dashboards/Modify.html?id=$id");
$m->content_lacks("different dashboard", "dashboard was deleted");
$m->content_contains("Failed to load dashboard $id");
$m->no_warnings_ok;

$user_obj->principal->grant_right(right => "SuperUser", object => RT->system);

# now test that we warn about searches others can't see
# first create a personal saved search...
$m->get_ok($url."/Search/Build.html");
$m->follow_link_ok({text => 'Advanced'});
$m->form_with_fields('query');
$m->field(query => "id > 0");
$m->submit;

$m->form_with_fields('saved_search_description');
$m->field(saved_search_description => "personal search");
$m->click_button(name => "saved_search_save");

# then the system-wide dashboard
$m->get_ok($url."/Dashboards/Modify.html?create=1");

$m->form_name('modify_dashboard');
$m->field("name" => 'system dashboard');
$m->field("privacy" => 'RT::System-1');
$m->content_lacks('Delete', "Delete button hidden because we are creating");
$m->click_button(value => 'Save Changes');
$m->content_lacks("No permission to create dashboards");
$m->content_contains("Saved dashboard system dashboard");
$m->follow_link_ok({text => 'Queries'});
$m->form_name('Dashboard-Searches-body');
my ( $personal_search_option ) = $m->content =~ /(search-\d+-RT::Model::User-\d+)/;
$m->field('Searches-body-Available' => [$personal_search_option]);
$m->click_button(name => 'add');
$m->content_contains("Dashboard updated");

$m->content_contains("The following queries may not be visible to all users who can see this dashboard.");

$m->follow_link_ok({text => 'Show'});
$m->content_contains("personal search", "saved search shows up");
$m->content_contains("dashboard test", "matched ticket shows up");

# make sure the onlooker can't see the search...
$onlooker->principal->grant_right(right => 'SeeDashboard', object => RT->system);

my $omech = RT::Test::Web->new;
ok $omech->login(onlooker => 'onlooker'), "logged in";
$omech->get_ok("/Dashboards");

$omech->follow_link_ok({text => 'system dashboard'});
$omech->content_lacks("personal search", "saved search doesn't show up");
$omech->content_lacks("dashboard test", "matched ticket doesn't show up");

$m->warnings_like(qr/User .* tried to load container user /, "can't see other users' personal searches");

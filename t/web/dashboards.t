#!/usr/bin/perl -w
use strict;

use RT::Test tests => 109;
my ($baseurl, $m) = RT::Test->started_ok;

my $url = $m->rt_base_url;

my $user_obj = RT::User->new($RT::SystemUser);
my ($ret, $msg) = $user_obj->LoadOrCreateByEmail('customer@example.com');
ok($ret, 'ACL test user creation');
$user_obj->SetName('customer');
$user_obj->SetPrivileged(1);
($ret, $msg) = $user_obj->SetPassword('customer');
$user_obj->PrincipalObj->GrantRight(Right => 'ModifySelf');
my $currentuser = RT::CurrentUser->new($user_obj);

my $onlooker = RT::User->new($RT::SystemUser);
($ret, $msg) = $onlooker->LoadOrCreateByEmail('onlooker@example.com');
ok($ret, 'ACL test user creation');
$onlooker->SetName('onlooker');
$onlooker->SetPrivileged(1);
($ret, $msg) = $onlooker->SetPassword('onlooker');

my $queue = RT::Queue->new($RT::SystemUser);
$queue->Create(Name => 'SearchQueue'.$$);

for my $user ($user_obj, $onlooker) {
    $user->PrincipalObj->GrantRight(Right => 'ModifySelf');
    for my $right (qw/SeeQueue ShowTicket OwnTicket/) {
        $user->PrincipalObj->GrantRight(Right => $right, Object => $queue);
    }
}

ok $m->login(customer => 'customer'), "logged in";

$m->get_ok($url."Dashboards/index.html");
$m->content_lacks('<a href="/Dashboards/Modify.html?Create=1">New</a>', 
                  "No 'new dashboard' link because we have no CreateOwnDashboard");

$m->no_warnings_ok;

$m->get_ok($url."Dashboards/Modify.html?Create=1");
$m->content_contains("Permission denied");
$m->content_lacks("Save Changes");

$m->warning_like(qr/Permission denied/, "got a permission denied warning");

$user_obj->PrincipalObj->GrantRight(Right => 'ModifyOwnDashboard', Object => $RT::System);

# Modify itself is no longer good enough, you need Create
$m->get_ok($url."Dashboards/Modify.html?Create=1");
$m->content_contains("Permission denied");
$m->content_lacks("Save Changes");

$m->warning_like(qr/Permission denied/, "got a permission denied warning");

$user_obj->PrincipalObj->GrantRight(Right => 'CreateOwnDashboard', Object => $RT::System);

$m->get_ok($url."Dashboards/Modify.html?Create=1");
$m->content_lacks("Permission denied");
$m->content_contains("Create");

$m->get_ok($url."Dashboards/index.html");
$m->content_contains("New", "'New' link because we now have ModifyOwnDashboard");

$m->follow_link_ok({text => "New"});
$m->form_name('ModifyDashboard');
$m->field("Name" => 'different dashboard');
$m->content_lacks('Delete', "Delete button hidden because we are creating");
$m->click_button(value => 'Create');
$m->content_lacks("No permission to create dashboards");
$m->content_contains("Saved dashboard different dashboard");
$m->content_lacks('Delete', "Delete button hidden because we lack DeleteOwnDashboard");

$m->get_ok($url."Dashboards/index.html");
$m->content_lacks("different dashboard", "we lack SeeOwnDashboard");

$user_obj->PrincipalObj->GrantRight(Right => 'SeeOwnDashboard', Object => $RT::System);

$m->get_ok($url."Dashboards/index.html");
$m->content_contains("different dashboard", "we now have SeeOwnDashboard");
$m->content_lacks("Permission denied");

$m->follow_link_ok({text => "different dashboard"});
$m->content_contains("Basics");
$m->content_contains("Queries");
$m->content_lacks("Subscription", "we don't have the SubscribeDashboard right");

$m->follow_link_ok({text => "Basics"});
$m->content_contains("Modify the dashboard different dashboard");

$m->follow_link_ok({text => "Queries"});
$m->content_contains("Modify the queries of dashboard different dashboard");
$m->form_name('Dashboard-Searches-body');
$m->field('Searches-body-Available' => ["search-2-RT::System-1"]);
$m->click_button(name => 'add');
$m->content_contains("Dashboard updated");

my $dashboard = RT::Dashboard->new($currentuser);
my ($id) = $m->content =~ /name="id" value="(\d+)"/;
ok($id, "got an ID, $id");
$dashboard->LoadById($id);
is($dashboard->Name, "different dashboard");

is($dashboard->Privacy, 'RT::User-' . $user_obj->Id, "correct privacy");
is($dashboard->PossibleHiddenSearches, 0, "all searches are visible");

my @searches = $dashboard->Searches;
is(@searches, 1, "one saved search in the dashboard");
like($searches[0]->Name, qr/newest unowned tickets/, "correct search name");

$m->form_name('Dashboard-Searches-body');
$m->field('Searches-body-Available' => ["search-1-RT::System-1"]);
$m->click_button(name => 'add');
$m->content_contains("Dashboard updated");

RT::Record->FlushCache if RT::Record->can('FlushCache');
$dashboard = RT::Dashboard->new($currentuser);
$dashboard->LoadById($id);

@searches = $dashboard->Searches;
is(@searches, 2, "two saved searches in the dashboard");
like($searches[0]->Name, qr/newest unowned tickets/, "correct existing search name");
like($searches[1]->Name, qr/highest priority tickets I own/, "correct new search name");

my $ticket = RT::Ticket->new($RT::SystemUser);
$ticket->Create(
    Queue     => $queue->Id,
	Requestor => [ $user_obj->Name ],
	Owner     => $user_obj,
	Subject   => 'dashboard test',
);

$m->follow_link_ok({text => 'different dashboard'});
$m->content_contains("20 highest priority tickets I own");
$m->content_contains("20 newest unowned tickets");
$m->content_lacks("Bookmarked Tickets");
$m->content_contains("dashboard test", "ticket subject");

$m->get_ok("/Dashboards/$id/This fragment left intentionally blank");
$m->content_contains("20 highest priority tickets I own");
$m->content_contains("20 newest unowned tickets");
$m->content_lacks("Bookmarked Tickets");
$m->content_contains("dashboard test", "ticket subject");

$m->get_ok("/Dashboards/Subscription.html?DashboardId=$id");
$m->form_name('SubscribeDashboard');
$m->click_button(name => 'Save');
$m->content_contains("Permission denied");
$m->warning_like(qr/Unable to subscribe to dashboard.*Permission denied/, "got a permission denied warning when trying to subscribe to a dashboard");

RT::Record->FlushCache if RT::Record->can('FlushCache');
is($user_obj->Attributes->Named('Subscription'), 0, "no subscriptions");

$user_obj->PrincipalObj->GrantRight(Right => 'SubscribeDashboard', Object => $RT::System);

$m->get_ok("/Dashboards/Modify.html?id=$id");
$m->follow_link_ok({text => "Subscription"});
$m->content_contains("Subscribe to dashboard different dashboard");
$m->content_contains("Unowned Tickets");
$m->content_contains("My Tickets");
$m->content_lacks("Bookmarked Tickets", "only dashboard queries show up");

$m->form_name('SubscribeDashboard');
$m->click_button(name => 'Save');
$m->content_lacks("Permission denied");
$m->content_contains("Subscribed to dashboard different dashboard");

RT::Record->FlushCache if RT::Record->can('FlushCache');
TODO: {
    local $TODO = "some kind of caching is still happening (it works if I remove the check above)";
    is($user_obj->Attributes->Named('Subscription'), 1, "we have a subscription");
};

$m->get_ok("/Dashboards/Modify.html?id=$id");
$m->follow_link_ok({text => "Subscription"});
$m->content_contains("Modify the subscription to dashboard different dashboard");

$m->get_ok("/Dashboards/Modify.html?id=$id&Delete=1");
$m->content_contains("Permission denied", "unable to delete dashboard because we lack DeleteOwnDashboard");

$m->warning_like(qr/Couldn't delete dashboard.*Permission denied/, "got a permission denied warning when trying to delete the dashboard");

$user_obj->PrincipalObj->GrantRight(Right => 'DeleteOwnDashboard', Object => $RT::System);

$m->get_ok("/Dashboards/Modify.html?id=$id");
$m->content_contains('Delete', "Delete button shows because we have DeleteOwnDashboard");

$m->form_name('ModifyDashboard');
$m->click_button(name => 'Delete');
$m->content_contains("Deleted dashboard $id");

$m->get("/Dashboards/Modify.html?id=$id");
$m->content_lacks("different dashboard", "dashboard was deleted");
$m->content_contains("Failed to load dashboard $id");

$m->warning_like(qr/Failed to load dashboard.*Couldn't find row/, "the dashboard was deleted");

$user_obj->PrincipalObj->GrantRight(Right => "SuperUser", Object => $RT::System);

# now test that we warn about searches others can't see
# first create a personal saved search...
$m->get_ok($url."Search/Build.html");
$m->follow_link_ok({text => 'Advanced'});
$m->form_with_fields('Query');
$m->field(Query => "id > 0");
$m->submit;

$m->form_with_fields('SavedSearchDescription');
$m->field(SavedSearchDescription => "personal search");
$m->click_button(name => "SavedSearchSave");

# then the system-wide dashboard
$m->get_ok($url."Dashboards/Modify.html?Create=1");

$m->form_name('ModifyDashboard');
$m->field("Name" => 'system dashboard');
$m->field("Privacy" => 'RT::System-1');
$m->content_lacks('Delete', "Delete button hidden because we are creating");
$m->click_button(value => 'Create');
$m->content_lacks("No permission to create dashboards");
$m->content_contains("Saved dashboard system dashboard");

$m->follow_link_ok({text => 'Queries'});

$m->form_name('Dashboard-Searches-body');
$m->field('Searches-body-Available' => ['search-7-RT::User-22']); # XXX: :( :(
$m->click_button(name => 'add');
$m->content_contains("Dashboard updated");

$m->content_contains("The following queries may not be visible to all users who can see this dashboard.");

$m->follow_link_ok({text => 'system dashboard'});
$m->content_contains("personal search", "saved search shows up");
$m->content_contains("dashboard test", "matched ticket shows up");

# make sure the onlooker can't see the search...
$onlooker->PrincipalObj->GrantRight(Right => 'SeeDashboard', Object => $RT::System);

my $omech = RT::Test::Web->new;
ok $omech->login(onlooker => 'onlooker'), "logged in";
$omech->get_ok("/Dashboards");

$omech->follow_link_ok({text => 'system dashboard'});
$omech->content_lacks("personal search", "saved search doesn't show up");
$omech->content_lacks("dashboard test", "matched ticket doesn't show up");

$m->warning_like(qr/User .* tried to load container user /, "can't see other users' personal searches");


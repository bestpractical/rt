#!/usr/bin/perl -w
use strict;

use Test::More tests => 78;
use RT::Test;
my ($baseurl, $m) = RT::Test->started_ok;

my $url = $m->rt_base_url;

my $user_obj = RT::Model::User->new(current_user => RT->system_user);
my ($ret, $msg) = $user_obj->LoadOrCreateByEmail('customer@example.com');
ok($ret, 'ACL test user creation');
$user_obj->SetName('customer');
$user_obj->SetPrivileged(1);
($ret, $msg) = $user_obj->SetPassword('customer');
$user_obj->PrincipalObj->GrantRight(Right => 'ModifySelf');
my $currentuser = RT::CurrentUser->new($user_obj);

my $queue = RT::Queue->new($RT::SystemUser);
$queue->create(Name => 'SearchQueue'.$$);
$user_obj->PrincipalObj->GrantRight(Right => 'SeeQueue',   Object => $queue);
$user_obj->PrincipalObj->GrantRight(Right => 'ShowTicket', Object => $queue);
$user_obj->PrincipalObj->GrantRight(Right => 'OwnTicket',  Object => $queue);

ok $m->login(customer => 'customer'), "logged in";

$m->get_ok($url."Dashboards/index.html");
$m->content_lacks("New dashboard", "No 'new dashboard' link because we have no CreateOwnDashboard");

$m->get_ok($url."Dashboards/Modify.html?Create=1");
$m->content_contains("Permission denied");
$m->content_lacks("Save Changes");

$user_obj->PrincipalObj->GrantRight(Right => 'ModifyOwnDashboard', Object => $RT::System);

# Modify itself is no longer good enough, you need Create
$m->get_ok($url."Dashboards/Modify.html?Create=1");
$m->content_contains("Permission denied");
$m->content_lacks("Save Changes");

$user_obj->PrincipalObj->GrantRight(Right => 'CreateOwnDashboard', Object => $RT::System);

$m->get_ok($url."Dashboards/Modify.html?Create=1");
$m->content_lacks("Permission denied");
$m->content_contains("Save Changes");

$m->get_ok($url."Dashboards/index.html");
$m->content_contains("New dashboard", "'New dashboard' link because we now have ModifyOwnDashboard");

$m->follow_link_ok({text => "New dashboard"});
$m->form_name('ModifyDashboard');
$m->field("Name" => 'different dashboard');
$m->content_lacks('Delete', "Delete button hidden because we are creating");
$m->click_button(value => 'Save Changes');
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
$m->content_contains("Show");

$m->follow_link_ok({text => "Basics"});
$m->content_contains("Modify the dashboard different dashboard");

$m->follow_link_ok({text => "Queries"});
$m->content_contains("Modify the queries of dashboard different dashboard");
$m->form_name('DashboardQueries');
$m->field('Searches-Available' => ["2-RT::System-1"]);
$m->click_button(name => 'add');
$m->content_contains("Dashboard updated");

my $dashboard = RT::Dashboard->new($currentuser);
my ($id) = $m->content =~ /name="id" value="(\d+)"/;
ok($id, "got an ID, $id");
$dashboard->LoadById($id);
is($dashboard->Name, "different dashboard");

is($dashboard->Privacy, 'RT::Model::User-' . $user_obj->Id, "correct privacy");
is($dashboard->PossibleHiddenSearches, 0, "all searches are visible");

my @searches = $dashboard->Searches;
is(@searches, 1, "one saved search in the dashboard");
like($searches[0]->Name, qr/newest unowned tickets/, "correct search name");

$m->form_name('DashboardQueries');
$m->field('Searches-Available' => ["1-RT::System-1"]);
$m->click_button(name => 'add');
$m->content_contains("Dashboard updated");

RT::Record->FlushCache if RT::Record->can('FlushCache');
$dashboard = RT::Dashboard->new($currentuser);
$dashboard->LoadById($id);

@searches = $dashboard->Searches;
is(@searches, 2, "two saved searches in the dashboard");
like($searches[0]->Name, qr/newest unowned tickets/, "correct existing search name");
like($searches[1]->Name, qr/highest priority tickets I own/, "correct new search name");

my $ticket = RT::Model::Ticket->new(current_user => RT->system_user);
$ticket->create(
    Queue     => $queue->Id,
	Requestor => [ $user_obj->Name ],
	Owner     => $user_obj,
	Subject   => 'dashboard test',
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

$m->get_ok("/Dashboards/Subscription.html?DashboardId=$id");
$m->form_name('SubscribeDashboard');
$m->click_button(name => 'Save');
$m->content_contains("Permission denied");

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

$user_obj->PrincipalObj->GrantRight(Right => 'DeleteOwnDashboard', Object => $RT::System);

$m->get_ok("/Dashboards/Modify.html?id=$id");
$m->content_contains('Delete', "Delete button shows because we have DeleteOwnDashboard");

$m->form_name('ModifyDashboard');
$m->click_button(name => 'Delete');
$m->content_contains("Deleted dashboard $id");

$m->get("/Dashboards/Modify.html?id=$id");
$m->content_lacks("different dashboard", "dashboard was deleted");
$m->content_contains("Failed to load dashboard $id");


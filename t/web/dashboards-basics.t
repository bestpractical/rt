use strict;
use warnings;

use HTTP::Status qw();
use RT::Test tests => 105;
my ($baseurl, $m) = RT::Test->started_ok;

my $url = $m->rt_base_url;

my $user_obj = RT::User->new(RT->SystemUser);
my ($ret, $msg) = $user_obj->LoadOrCreateByEmail('customer@example.com');
ok($ret, 'ACL test user creation');
$user_obj->SetName('customer');
$user_obj->SetPrivileged(1);
($ret, $msg) = $user_obj->SetPassword('customer');
$user_obj->PrincipalObj->GrantRight(Right => 'ModifySelf');
my $currentuser = RT::CurrentUser->new($user_obj);

my $onlooker = RT::User->new(RT->SystemUser);
($ret, $msg) = $onlooker->LoadOrCreateByEmail('onlooker@example.com');
ok($ret, 'ACL test user creation');
$onlooker->SetName('onlooker');
$onlooker->SetPrivileged(1);
($ret, $msg) = $onlooker->SetPassword('onlooker');

my $queue = RT::Queue->new(RT->SystemUser);
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

$m->get($url."Dashboards/Modify.html?Create=1");
is($m->status, HTTP::Status::HTTP_FORBIDDEN);
$m->content_contains("Permission Denied");
$m->content_lacks("Save Changes");

$m->warning_like(qr/Permission Denied/, "got a permission denied warning");

$user_obj->PrincipalObj->GrantRight(Right => 'ModifyOwnDashboard', Object => $RT::System);

# Modify itself is no longer good enough, you need Create
$m->get($url."Dashboards/Modify.html?Create=1");
is($m->status, HTTP::Status::HTTP_FORBIDDEN);
$m->content_contains("Permission Denied");
$m->content_lacks("Save Changes");

$m->warning_like(qr/Permission Denied/, "got a permission denied warning");

$user_obj->PrincipalObj->GrantRight(Right => 'CreateOwnDashboard', Object => $RT::System);

$m->get_ok($url."Dashboards/Modify.html?Create=1");
$m->content_lacks("Permission Denied");
$m->content_contains("Create");

$m->get_ok($url."Dashboards/index.html");
$m->content_contains("New", "'New' link because we now have ModifyOwnDashboard");
$m->follow_link_ok({ id => 'home-dashboard_create'});
$m->form_name('ModifyDashboard');
$m->field("Name" => 'different dashboard');
$m->content_lacks('Delete', "Delete button hidden because we are creating");
$m->click_button(value => 'Create');
$m->content_contains("Saved dashboard different dashboard");
$user_obj->PrincipalObj->GrantRight(Right => 'SeeOwnDashboard', Object => $RT::System);
$m->get($url."Dashboards/index.html");
$m->follow_link_ok({ text => 'different dashboard'});
$m->content_lacks("Permission Denied", "we now have SeeOwnDashboard");
$m->content_lacks('Delete', "Delete button hidden because we lack DeleteOwnDashboard");

$m->get_ok($url."Dashboards/index.html");
$m->content_contains("different dashboard", "we now have SeeOwnDashboard");
$m->content_lacks("Permission Denied");

$m->follow_link_ok({text => "different dashboard"});
$m->content_contains("Basics");
$m->content_contains("Content");
$m->content_lacks("Subscription", "we don't have the SubscribeDashboard right");

$m->follow_link_ok({text => "Basics"});
$m->content_contains("Modify the dashboard different dashboard");

$m->follow_link_ok({text => "Content"});
$m->content_contains("Modify the content of dashboard different dashboard");
my $form = $m->form_name('Dashboard-Searches-body');
my @input = $form->find_input('Searches-body-Available');
my ($unowned) =
  map { ( $_->possible_values )[1] }
  grep { ( $_->value_names )[1] =~ /Saved Search: Unowned Tickets/ } @input;
$form->value('Searches-body-Available' => $unowned );
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

$form = $m->form_name('Dashboard-Searches-body');
@input = $form->find_input('Searches-body-Available');
my ($my_tickets) =
  map { ( $_->possible_values )[1] }
  grep { ( $_->value_names )[1] =~ /Saved Search: My Tickets/ } @input;
$form->value('Searches-body-Available' => $my_tickets );
$m->click_button(name => 'add');
$m->content_contains("Dashboard updated");

$dashboard = RT::Dashboard->new($currentuser);
$dashboard->LoadById($id);

@searches = $dashboard->Searches;
is(@searches, 2, "two saved searches in the dashboard");
like($searches[0]->Name, qr/newest unowned tickets/, "correct existing search name");
like($searches[1]->Name, qr/highest priority tickets I own/, "correct new search name");

my $ticket = RT::Ticket->new(RT->SystemUser);
$ticket->Create(
    Queue     => $queue->Id,
    Requestor => [ $user_obj->Name ],
    Owner     => $user_obj,
    Subject   => 'dashboard test',
);

$m->follow_link_ok({id => 'page-show'});
$m->content_contains("50 highest priority tickets I own");
$m->content_contains("50 newest unowned tickets");
$m->content_unlike( qr/Bookmarked Tickets.*Bookmarked Tickets/s,
    'only dashboard queries show up' );
$m->content_contains("dashboard test", "ticket subject");

$m->get_ok("/Dashboards/$id/This fragment left intentionally blank");
$m->content_contains("50 highest priority tickets I own");
$m->content_contains("50 newest unowned tickets");
$m->content_unlike( qr/Bookmarked Tickets.*Bookmarked Tickets/s,
    'only dashboard queries show up' );
$m->content_contains("dashboard test", "ticket subject");

$m->get("/Dashboards/Modify.html?id=$id&Delete=1");
is($m->status, HTTP::Status::HTTP_FORBIDDEN);
$m->content_contains("Permission Denied", "unable to delete dashboard because we lack DeleteOwnDashboard");

$m->warning_like(qr/Couldn't delete dashboard.*Permission Denied/, "got a permission denied warning when trying to delete the dashboard");

$user_obj->PrincipalObj->GrantRight(Right => 'DeleteOwnDashboard', Object => $RT::System);

$m->get_ok("/Dashboards/Modify.html?id=$id");
$m->content_contains('Delete', "Delete button shows because we have DeleteOwnDashboard");

$m->form_name('ModifyDashboard');
$m->click_button(name => 'Delete');
$m->content_contains("Deleted dashboard");

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

$m->follow_link_ok({id => 'page-content'});

$form = $m->form_name('Dashboard-Searches-body');
@input = $form->find_input('Searches-body-Available');
my ($personal) =
  map { ( $_->possible_values )[1] }
  grep { ( $_->value_names )[1] =~ /Saved Search: personal search/ } @input;
$form->value('Searches-body-Available' => $personal );
$m->click_button(name => 'add');
$m->content_contains("Dashboard updated");

$m->content_contains("The following queries may not be visible to all users who can see this dashboard.");

$m->follow_link_ok({id => 'page-show'});
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

$omech->warning_like(qr/User .* tried to load container user /, "can't see other users' personal searches");

# make sure that navigating to dashboard pages with bad IDs throws an error
my ($bad_id) = $personal =~ /^search-(\d+)/;

for my $page (qw/Modify Queries Render Subscription/) {
    $m->get("/Dashboards/$page.html?id=$bad_id");
    $m->content_like(qr/Couldn.+t load dashboard $bad_id: Invalid object type/);
    $m->warning_like(qr/Couldn't load dashboard $bad_id: Invalid object type/);
}


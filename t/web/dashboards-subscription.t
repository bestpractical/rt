use strict;
use warnings;

use RT::Test tests => undef;
my ($baseurl, $m) = RT::Test->started_ok;

my $url = $m->rt_base_url;

# Create User
my $user = RT::User->new(RT->SystemUser);
my ($ret, $msg) = $user->LoadOrCreateByEmail('customer@example.com');
ok($ret, 'ACL test user creation');
$user->SetName('customer');
$user->SetPrivileged(1);
($ret, $msg) = $user->SetPassword('customer');
$user->PrincipalObj->GrantRight(Right => 'ModifySelf');
$user->PrincipalObj->GrantRight(Right => 'ModifyOwnDashboard', Object => $RT::System);
$user->PrincipalObj->GrantRight(Right => 'CreateOwnDashboard', Object => $RT::System);
$user->PrincipalObj->GrantRight(Right => 'SeeOwnDashboard', Object => $RT::System);
$user->PrincipalObj->GrantRight(Right => 'SeeGroup', Object => $RT::System);
my $currentuser = RT::CurrentUser->new($user);

ok $m->login(customer => 'customer'), "logged in";

$m->get_ok($url."Dashboards/Modify.html?Create=1");

# Create Dashboard
$m->follow_link_ok({ id => 'home-dashboard_create' });
$m->form_name('ModifyDashboard');
$m->field("Name" => 'test dashboard');
$m->click_button(value => 'Create');
$m->content_contains("Saved dashboard test dashboard");

# Make sure dashboard exists
my $dashboard = RT::Dashboard->new($currentuser);
my ($id) = $m->content =~ /name="id" value="(\d+)"/;
ok($id, "got an ID, $id");
$dashboard->LoadById($id);
is($dashboard->Name, "test dashboard");

# Attempt subscription without right
$m->get_ok("/Dashboards/Subscription.html?id=$id");
$m->content_lacks('id="page-subscription"', "shouldn't have Subscription link since we don't have the SubscribeDashboard right");
$m->form_name('SubscribeDashboard');
$m->click_button(name => 'Save');
$m->content_contains("Permission Denied");
$m->warning_like(qr/Unable to subscribe to dashboard.*Permission Denied/, "got a permission denied warning when trying to subscribe to a dashboard");

# Make sure subscription doesn't exist
$user->Attributes->RedoSearch;
is($user->Attributes->Named('Subscription'), 0, "no subscriptions");

# Attempt subscription with right
$user->PrincipalObj->GrantRight(Right => 'SubscribeDashboard', Object => $RT::System);
$m->get_ok("/Dashboards/Subscription.html?id=$id");
$m->content_contains('id="page-subscription"', "subscription link should be visible");
$m->form_name('SubscribeDashboard');
$m->click_button(name => 'Save');
$m->content_lacks("Permission Denied");
$m->content_contains("Subscribed to dashboard test dashboard");

# Verify subscription exists
$user->Attributes->RedoSearch;
is($user->Attributes->Named('Subscription'), 1, "we have a subscription");

# Test recipients missing warning
$m->follow_link_ok({ id => 'page-subscription' });
$m->form_name('SubscribeDashboard');
$m->untick("Dashboard-Subscription-Users-".$user->id,1);
$m->click_button(name => 'Save');
$m->content_contains('customer removed from dashboard subscription recipients');
$m->content_contains("Warning: This dashboard has no recipients");

# Create new user to search for
my $search_user = RT::User->new(RT->SystemUser);
($ret, $msg) = $search_user->LoadOrCreateByEmail('customer2@example.com');
ok($ret, 'ACL test user creation');
$search_user->SetName('customer2');

# Search for customer2 user and subscribe
$m->form_name('SubscribeDashboard');
$m->field(UserString => 'customer');
$m->click_button(name => 'OnlySearchForPeople');
$m->content_contains('customer2@example.com');

# Subscribe customer2
$m->form_name('SubscribeDashboard');
$m->tick("Dashboard-Subscription-Users-".$search_user->id, 1);
$m->click_button(name => 'Save');
$m->content_contains('customer2 added to dashboard subscription recipients');

# Make sure customer2 is listed as a recipient
$m->follow_link_ok({ id => 'page-subscription' });
$m->content_contains('customer2@example.com');

# Create new group to search for
my $search_group = RT::Group->new(RT->SystemUser);
($ret, $msg) = $search_group->CreateUserDefinedGroup(Name => 'customers test group');
ok($ret, 'Test customers group creation');

# Search for group
$m->form_name('SubscribeDashboard');
$m->field(GroupString => 'customers');
$m->click_button(name => 'OnlySearchForGroup');

$m->content_contains('customers test group');

# Subscribe group
$m->form_name('SubscribeDashboard');
$m->tick("Dashboard-Subscription-Groups-".$search_group->id, 1);
$m->click_button(name => 'Save');
$m->content_contains('customers test group added to dashboard subscription recipients');

# Make sure customers group is listed as a recipient
$m->follow_link_ok({ id => 'page-subscription' });
$m->content_contains('customers test group');

# Unsubscribe group
$m->form_name('SubscribeDashboard');
$m->untick("Dashboard-Subscription-Groups-".$search_group->id, 1);
$m->click_button(name => 'Save');
$m->content_contains('customers test group removed from dashboard subscription recipients');

# Make sure customers group is no longer listed as a recipient
$m->follow_link_ok({ id => 'page-subscription' });
$m->content_lacks('customers test group');

done_testing;

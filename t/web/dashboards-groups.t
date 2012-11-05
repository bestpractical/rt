use strict;
use warnings;

use RT::Test nodata => 1, tests => 64;
my ($baseurl, $m) = RT::Test->started_ok;

my $url = $m->rt_base_url;

# create user and queue
my $user_obj = RT::User->new(RT->SystemUser);
my ($ok, $msg) = $user_obj->LoadOrCreateByEmail('customer@example.com');
ok($ok, 'ACL test user creation');
$user_obj->SetName('customer');
$user_obj->SetPrivileged(1);
($ok, $msg) = $user_obj->SetPassword('customer');
$user_obj->PrincipalObj->GrantRight(Right => 'ModifySelf');
my $currentuser = RT::CurrentUser->new($user_obj);

my $queue = RT::Queue->new(RT->SystemUser);
$queue->Create(Name => 'SearchQueue'.$$);

$user_obj->PrincipalObj->GrantRight(Right => $_, Object => $queue)
    for qw/SeeQueue ShowTicket OwnTicket/;

# grant the user all these rights so we can make sure that the group rights
# are checked and not these as well
$user_obj->PrincipalObj->GrantRight(Right => $_, Object => $RT::System)
    for qw/SubscribeDashboard CreateOwnDashboard SeeOwnDashboard ModifyOwnDashboard DeleteOwnDashboard/;
# create and test groups (outer < inner < user)
my $inner_group = RT::Group->new(RT->SystemUser);
($ok, $msg) = $inner_group->CreateUserDefinedGroup(Name => "inner", Description => "inner group");
ok($ok, "created inner group: $msg");

my $outer_group = RT::Group->new(RT->SystemUser);
($ok, $msg) = $outer_group->CreateUserDefinedGroup(Name => "outer", Description => "outer group");
ok($ok, "created outer group: $msg");

($ok, $msg) = $outer_group->AddMember($inner_group->PrincipalId);
ok($ok, "added inner as a member of outer: $msg");

($ok, $msg) = $inner_group->AddMember($user_obj->PrincipalId);
ok($ok, "added user as a member of member: $msg");

ok($outer_group->HasMember($inner_group->PrincipalId), "outer has inner");
ok(!$outer_group->HasMember($user_obj->PrincipalId), "outer doesn't have user directly");
ok($outer_group->HasMemberRecursively($inner_group->PrincipalId), "outer has inner recursively");
ok($outer_group->HasMemberRecursively($user_obj->PrincipalId), "outer has user recursively");

ok(!$inner_group->HasMember($outer_group->PrincipalId), "inner doesn't have outer");
ok($inner_group->HasMember($user_obj->PrincipalId), "inner has user");
ok(!$inner_group->HasMemberRecursively($outer_group->PrincipalId), "inner doesn't have outer, even recursively");
ok($inner_group->HasMemberRecursively($user_obj->PrincipalId), "inner has user recursively");

ok $m->login(customer => 'customer'), "logged in";


$m->follow_link_ok({ id => 'home-dashboard_create'});
$m->form_name('ModifyDashboard');
is_deeply([$m->current_form->find_input('Privacy')->possible_values], ["RT::User-" . $user_obj->Id], "the only selectable privacy is user");
$m->content_lacks('Delete', "Delete button hidden because we are creating");

$user_obj->PrincipalObj->GrantRight(Right => 'CreateGroupDashboard', Object => $inner_group);

$m->follow_link_ok({ id => 'home-dashboard_create'});
$m->form_name('ModifyDashboard');
is_deeply([$m->current_form->find_input('Privacy')->possible_values], ["RT::User-" . $user_obj->Id, "RT::Group-" . $inner_group->Id], "the only selectable privacies are user and inner group (not outer group)");
$m->field("Name" => 'broken dashboard');
$m->field("Privacy" => "RT::Group-" . $inner_group->Id);
$m->content_lacks('Delete', "Delete button hidden because we are creating");
$m->click_button(value => 'Create');
$m->content_contains("saved", "we lack SeeGroupDashboard, so we end up back at the index.");

$user_obj->PrincipalObj->GrantRight(
    Right  => 'SeeGroupDashboard',
    Object => $inner_group,
);
$m->follow_link_ok({ id => 'home-dashboard_create'});
$m->form_name('ModifyDashboard');
$m->field("Name" => 'inner dashboard');
$m->field("Privacy" => "RT::Group-" . $inner_group->Id);
$m->click_button(value => 'Create');
$m->content_lacks("Permission Denied", "we now have SeeGroupDashboard");
$m->content_contains("Saved dashboard inner dashboard");
$m->content_lacks('Delete', "Delete button hidden because we lack DeleteDashboard");

my $dashboard = RT::Dashboard->new($currentuser);
my ($id) = $m->content =~ /name="id" value="(\d+)"/;
ok($id, "got an ID, $id");
$dashboard->LoadById($id);
is($dashboard->Name, "inner dashboard");

is($dashboard->Privacy, 'RT::Group-' . $inner_group->Id, "correct privacy");
is($dashboard->PossibleHiddenSearches, 0, "all searches are visible");


$m->get_ok("/Dashboards/Modify.html?id=$id");
$m->content_contains("inner dashboard", "we now have SeeGroupDashboard right");
$m->content_lacks("Permission Denied");
$m->content_contains('Subscription', "Subscription link not hidden because we have SubscribeDashboard");


$m->get_ok("/Dashboards/index.html");
$m->content_contains("inner dashboard", "We can see the inner dashboard from the UI");

$m->get_ok("/Prefs/DashboardsInMenu.html");
$m->content_contains("inner dashboard", "Can also see it in the menu options");

my ($group) = grep {$_->isa("RT::Group") and $_->Id == $inner_group->Id}
    RT::Dashboard->new($currentuser)->_PrivacyObjects;
ok($group, "Found the group in  the privacy objects list");

my @loading = map {ref($_)."-".$_->Id} RT::Dashboard->new($currentuser)->ObjectsForLoading;
is_deeply(
    \@loading,
    ["RT::User-".$user_obj->Id, "RT::Group-".$inner_group->Id],
    "We can load from ourselves (SeeOwnDashboard) and a group we are with SeeGroupDashboard"
);

# If you are granted SeeGroupDashboard globally, you can only see
# dashboards in groups you are in.
$user_obj->PrincipalObj->RevokeRight(
    Right  => 'SeeGroupDashboard',
    Object => $inner_group,
);
$user_obj->PrincipalObj->GrantRight(
    Right  => 'SeeGroupDashboard',
    Object => RT->System,
);
$m->get_ok("/Dashboards/index.html");
$m->content_contains("inner dashboard", "Having SeeGroupDashboard gobally is fine for groups you are in");
@loading = map {ref($_)."-".$_->Id} RT::Dashboard->new($currentuser)->ObjectsForLoading;
is_deeply(
    \@loading,
    ["RT::User-".$user_obj->Id, "RT::Group-".$inner_group->Id],
    "SeeGroupDashboard globally still works for groups you are in"
);

$inner_group->DeleteMember($user_obj->PrincipalObj->Id);
ok(!$outer_group->HasMemberRecursively($user_obj->PrincipalId), "outer no longer has user recursively");
ok(!$inner_group->HasMemberRecursively($user_obj->PrincipalId), "inner no longer has user recursively");
$m->get_ok("/Dashboards/index.html");
$m->content_lacks("inner dashboard", "But global SeeGroupDashboard isn't enough for other groups");
$m->no_warnings_ok;
@loading = map {ref($_)."-".$_->Id} RT::Dashboard->new($currentuser)->ObjectsForLoading;
is_deeply(
    \@loading,
    ["RT::User-".$user_obj->Id],
    "We only have our SeeOwnDashboard right, as we are no longer in inner"
);

# Similarly, if you're a SuperUser, you still only see dashboards for
# groups you belong to
$user_obj->PrincipalObj->RevokeRight(
    Right  => 'SeeGroupDashboard',
    Object => RT->System,
);
$user_obj->PrincipalObj->GrantRight(
    Right  => 'SuperUser',
    Object => RT->System,
);
$m->get_ok("/Dashboards/index.html");
$m->content_lacks("inner dashboard", "Superuser can't see dashboards in groups they're not in");
@loading = map {ref($_)."-".$_->Id} RT::Dashboard->new($currentuser)->ObjectsForLoading;
is_deeply(
    \@loading,
    ["RT::User-".$user_obj->Id, "RT::System-1"],
    "We pick up the system-level SeeDashboard right from superuser"
);
@loading = map {ref($_)."-".$_->Id} RT::Dashboard->new($currentuser)->ObjectsForLoading(IncludeSuperuserGroups => 0);
is_deeply(
    \@loading,
    ["RT::User-".$user_obj->Id, "RT::System-1"],
    "IncludeSuperusers only cuts out _group_ dashboard objects for loading, not user and system ones"
);

$inner_group->AddMember($user_obj->PrincipalId);
$m->get_ok("/Dashboards/index.html");
$m->content_contains("inner dashboard", "Superuser can see dashboards in groups they are in");
@loading = map {ref($_)."-".$_->Id} RT::Dashboard->new($currentuser)->ObjectsForLoading;
is_deeply(
    \@loading,
    ["RT::User-".$user_obj->Id, "RT::Group-".$inner_group->Id, "RT::System-1"],
    "Becoming a member of the group makes it a possibility"
);
@loading = map {ref($_)."-".$_->Id} RT::Dashboard->new($currentuser)->ObjectsForLoading(IncludeSuperuserGroups => 0);
is_deeply(
    \@loading,
    ["RT::User-".$user_obj->Id, "RT::System-1"],
    "But only via superuser"
);

$m->get_ok("/Dashboards/index.html");
$m->content_contains("inner dashboard", "The dashboards list includes superuser rights");
$m->get_ok("/Prefs/DashboardsInMenu.html");
$m->content_lacks("inner dashboard", "But the menu skips them");

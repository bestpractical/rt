#!/usr/bin/perl -w
use strict;

use RT::Test tests => 40;
my ($baseurl, $m) = RT::Test->started_ok;

my $url = $m->rt_base_url;

# create user and queue {{{
my $user_obj = RT::User->new($RT::SystemUser);
my ($ok, $msg) = $user_obj->LoadOrCreateByEmail('customer@example.com');
ok($ok, 'ACL test user creation');
$user_obj->SetName('customer');
$user_obj->SetPrivileged(1);
($ok, $msg) = $user_obj->SetPassword('customer');
$user_obj->PrincipalObj->GrantRight(Right => 'ModifySelf');
my $currentuser = RT::CurrentUser->new($user_obj);

my $queue = RT::Queue->new($RT::SystemUser);
$queue->Create(Name => 'SearchQueue'.$$);

$user_obj->PrincipalObj->GrantRight(Right => $_, Object => $queue)
    for qw/SeeQueue ShowTicket OwnTicket/;

# grant the user all these rights so we can make sure that the group rights
# are checked and not these as well
$user_obj->PrincipalObj->GrantRight(Right => $_, Object => $RT::System)
    for qw/SubscribeDashboard CreateOwnDashboard SeeOwnDashboard ModifyOwnDashboard DeleteOwnDashboard/;
# }}}
# create and test groups (outer < inner < user) {{{
my $inner_group = RT::Group->new($RT::SystemUser);
($ok, $msg) = $inner_group->CreateUserDefinedGroup(Name => "inner", Description => "inner group");
ok($ok, "created inner group: $msg");

my $outer_group = RT::Group->new($RT::SystemUser);
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
# }}}

ok $m->login(customer => 'customer'), "logged in";

$m->get_ok("$url/Dashboards");

$m->follow_link_ok({text => "New"});
$m->form_name('ModifyDashboard');
is_deeply([$m->current_form->find_input('Privacy')->possible_values], ["RT::User-" . $user_obj->Id], "the only selectable privacy is user");
$m->content_lacks('Delete', "Delete button hidden because we are creating");

$user_obj->PrincipalObj->GrantRight(Right => 'CreateGroupDashboard', Object => $inner_group);

$m->follow_link_ok({text => "New"});
$m->form_name('ModifyDashboard');
is_deeply([$m->current_form->find_input('Privacy')->possible_values], ["RT::User-" . $user_obj->Id, "RT::Group-" . $inner_group->Id], "the only selectable privacies are user and inner group (not outer group)");
$m->field("Name" => 'inner dashboard');
$m->field("Privacy" => "RT::Group-" . $inner_group->Id);
$m->content_lacks('Delete', "Delete button hidden because we are creating");

$m->click_button(value => 'Create');
$m->content_lacks("No permission to create dashboards");
$m->content_contains("Saved dashboard inner dashboard");
$m->content_lacks('Delete', "Delete button hidden because we lack DeleteDashboard");

my $dashboard = RT::Dashboard->new($currentuser);
my ($id) = $m->content =~ /name="id" value="(\d+)"/;
ok($id, "got an ID, $id");
$dashboard->LoadById($id);
is($dashboard->Name, "inner dashboard");

is($dashboard->Privacy, 'RT::Group-' . $inner_group->Id, "correct privacy");
is($dashboard->PossibleHiddenSearches, 0, "all searches are visible");

$m->no_warnings_ok;

$m->get_ok("/Dashboards/Modify.html?id=$id");
$m->content_lacks("inner dashboard", "no SeeGroupDashboard right");
$m->content_contains("Permission denied");

$m->warning_like(qr/Permission denied/, "got a permission denied warning");

$user_obj->PrincipalObj->GrantRight(Right => 'SeeGroupDashboard', Object => $inner_group);
$m->get_ok("/Dashboards/Modify.html?id=$id");
$m->content_contains("inner dashboard", "we now have SeeGroupDashboard right");
$m->content_lacks("Permission denied");

$m->content_contains('Subscription', "Subscription link not hidden because we have SubscribeDashboard");


#!/usr/bin/perl -w
use strict;

use Test::More tests => 38;
use RT::Test;
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
$user_obj->PrincipalObj->GrantRight(Right => 'SeeQueue',   Object => $queue);
$user_obj->PrincipalObj->GrantRight(Right => 'ShowTicket', Object => $queue);
$user_obj->PrincipalObj->GrantRight(Right => 'OwnTicket',  Object => $queue);
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
$m->content_lacks("New dashboard", "new dashboard link hidden because we have no ModifyDashboard right");

$user_obj->PrincipalObj->GrantRight(Right => 'ModifyDashboard', Object => $inner_group);

$m->get_ok("$url/Dashboards");
$m->content_contains("New dashboard", "new dashboard link shows because we have the ModifyDashboard right on inner group");

$m->follow_link_ok({text => "New dashboard"});
$m->form_name('ModifyDashboard');
is_deeply([$m->current_form->param('Privacy')], ["RT::Group-" . $inner_group->Id], "the only selectable privacy is inner group");
$m->field("Name" => 'inner dashboard');
$m->content_lacks('Delete', "Delete button hidden because we are creating");

$m->click_button(value => 'Save Changes');
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

$m->get_ok("/Dashboards/Modify.html?id=$id");
$m->content_lacks("inner dashboard", "no SeeDashboard right");
$m->content_contains("Permission denied");

$user_obj->PrincipalObj->GrantRight(Right => 'SeeDashboard', Object => $inner_group);
$m->get_ok("/Dashboards/Modify.html?id=$id");
$m->content_contains("inner dashboard", "we now have SeeDashboard right");
$m->content_lacks("Permission denied");

$m->content_lacks('Subscription', "Subscription link still hidden because we lack SubscribeDashboard on this dashboard's privacy");

$user_obj->PrincipalObj->GrantRight(Right => 'SubscribeDashboard', Object => $inner_group);

$m->get_ok("/Dashboards/Modify.html?id=$id");
$m->content_contains('Subscription', "We now have SubscribeDashboard on inner group");


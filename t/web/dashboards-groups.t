#!/usr/bin/perl -w
use strict;

use Test::More tests => 19;
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

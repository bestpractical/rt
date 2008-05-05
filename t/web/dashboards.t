#!/usr/bin/perl -w
use strict;

use Test::More tests => 9;
use RT::Test;
my ($baseurl, $m) = RT::Test->started_ok;

my $url = $m->rt_base_url;

my $user_obj = RT::User->new($RT::SystemUser);
my ($ret, $msg) = $user_obj->LoadOrCreateByEmail('customer@example.com');
ok($ret, 'ACL test user creation');
$user_obj->SetName('customer');
$user_obj->SetPrivileged(1);
($ret, $msg) = $user_obj->SetPassword('customer');
$user_obj->PrincipalObj->GrantRight(Right => 'ModifySelf');

ok $m->login(customer => 'customer'), "logged in";

$m->get_ok($url."Dashboards/index.html");
$m->content_lacks("New dashboard", "No 'new dashboard' link because we have no ModifyDashboard");

$m->get_ok($url."Dashboards/Modify.html?Create=1");
$m->form_name('ModifyDashboard');
$m->field("Name" => 'test dashboard');
$m->click_button(value => 'Save Changes');
$m->content_contains("No permission to create dashboards");

$user_obj->PrincipalObj->GrantRight(Right => 'ModifyDashboard');

$m->get_ok($url."Dashboards/index.html");
$m->content_contains("New dashboard", "'New dashboard' link because we now have ModifyDashboard");

$m->follow_link_ok({text => "New dashboard"});
$m->form_name('ModifyDashboard');
$m->field("Name" => 'different dashboard');
$m->click_button(value => 'Save Changes');
$m->content_lacks("No permission to create dashboards");
$m->content_contains("Saved dashboard different dashboard");



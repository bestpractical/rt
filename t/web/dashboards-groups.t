#!/usr/bin/perl -w
use strict;

use Test::More tests => 36;
use RT::Test;
my ($baseurl, $m) = RT::Test->started_ok;

my $url = $m->rt_base_url;

# create user and queue {{{
my $user_obj = RT::Model::User->new(current_user => RT->system_user);
my ($ok, $msg) = $user_obj->load_or_create_by_email('customer@example.com');
ok($ok, 'ACL test user creation');
$user_obj->set_name('customer');
$user_obj->set_privileged(1);
($ok, $msg) = $user_obj->set_password('customer');
$user_obj->principal_object->grant_right(right => 'ModifySelf');
my $currentuser = RT::CurrentUser->new( id => $user_obj->id );

my $queue = RT::Model::Queue->new(current_user => RT->system_user);
$queue->create(name => 'SearchQueue'.$$);

$user_obj->principal_object->grant_right(right => $_, object => $queue)
    for qw/SeeQueue ShowTicket OwnTicket/;

# grant the user all these rights so we can make sure that the group rights
# are checked and not these as well
$user_obj->principal_object->grant_right(right => $_, object => $RT::System)
    for qw/SubscribeDashboard CreateOwnDashboard SeeOwnDashboard ModifyOwnDashboard DeleteOwnDashboard/;
# }}}
# create and test groups (outer < inner < user) {{{
my $inner_group = RT::Model::Group->new(current_user => RT->system_user);
($ok, $msg) = $inner_group->create_user_defined_group(name => "inner", description =>  "inner group");
ok($ok, "created inner group: $msg");

my $outer_group = RT::Model::Group->new(current_user => RT->system_user);
($ok, $msg) = $outer_group->create_user_defined_group(name => "outer", description =>  "outer group");
ok($ok, "created outer group: $msg");

($ok, $msg) = $outer_group->add_member($inner_group->principal_id);
ok($ok, "added inner as a member of outer: $msg");

($ok, $msg) = $inner_group->add_member($user_obj->principal_id);
ok($ok, "added user as a member of member: $msg");

ok($outer_group->has_member($inner_group->principal_id), "outer has inner");
ok(!$outer_group->has_member($user_obj->principal_id), "outer doesn't have user directly");
ok($outer_group->has_member_recursively($inner_group->principal_id), "outer has inner recursively");
ok($outer_group->has_member_recursively($user_obj->principal_id), "outer has user recursively");

ok(!$inner_group->has_member($outer_group->principal_id), "inner doesn't have outer");
ok($inner_group->has_member($user_obj->principal_id), "inner has user");
ok(!$inner_group->has_member_recursively($outer_group->principal_id), "inner doesn't have outer, even recursively");
ok($inner_group->has_member_recursively($user_obj->principal_id), "inner has user recursively");
# }}}

ok $m->login(customer => 'customer'), "logged in";

$m->get_ok("$url/Dashboards");

$m->follow_link_ok({text => "New dashboard"});
$m->form_name( 'modify_dashboard' );
is_deeply([$m->current_form->find_input('Privacy')->possible_values], ["RT::Model::User-" . $user_obj->id], "the only selectable privacy is user");
$m->content_lacks('Delete', "Delete button hidden because we are creating");

$user_obj->principal_object->grant_right(right => 'CreateGroupDashboard', object => $inner_group);

$m->follow_link_ok({text => "New dashboard"});
$m->form_name( 'modify_dashboard' );
is_deeply([$m->current_form->find_input('Privacy')->possible_values], ["RT::Model::User-" . $user_obj->id, "RT::Group-" . $inner_group->id], "the only selectable privacies are user and inner group (not outer group)");
$m->field("Name" => 'inner dashboard');
$m->field("Privacy" => "RT::Group-" . $inner_group->id);
$m->content_lacks('Delete', "Delete button hidden because we are creating");

$m->click_button(value => 'Save Changes');
$m->content_lacks("No permission to create dashboards");
$m->content_contains("Saved dashboard inner dashboard");
$m->content_lacks('Delete', "Delete button hidden because we lack DeleteDashboard");

my $dashboard = RT::Dashboard->new($currentuser);
my ($id) = $m->content =~ /name="id" value="(\d+)"/;
ok($id, "got an ID, $id");
$dashboard->load_by_id($id);
is($dashboard->name, "inner dashboard");

is($dashboard->privacy, 'RT::Group-' . $inner_group->id, "correct privacy");
is($dashboard->possible_hidden_searches, 0, "all searches are visible");

$m->get_ok("/Dashboards/Modify.html?id=$id");
$m->content_lacks("inner dashboard", "no SeeGroupDashboard right");
$m->content_contains("Permission denied");

$user_obj->principal_object->grant_right(right => 'SeeGroupDashboard', object => $inner_group);
$m->get_ok("/Dashboards/Modify.html?id=$id");
$m->content_contains("inner dashboard", "we now have SeeGroupDashboard right");
$m->content_lacks("Permission denied");

$m->content_contains('Subscription', "Subscription link not hidden because we have SubscribeDashboard");


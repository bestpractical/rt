#!/usr/bin/perl -w
use strict;

use RT::Test; use Test::More tests => 7;

my ($baseurl, $m) = RT::Test->started_ok;

my $url = $m->rt_base_url;

my $user_obj = RT::Model::User->new(current_user => RT->system_user);
my ($ret, $msg) = $user_obj->load_or_create_by_email('customer@example.com');
ok($ret, 'ACL test user creation');
$user_obj->set_name('customer');
$user_obj->set_privileged(1);
($ret, $msg) = $user_obj->set_password('customer');
$user_obj->principal_object->grant_right(Right => 'LoadSavedSearch');
$user_obj->principal_object->grant_right(Right => 'EditSavedSearch');
$user_obj->principal_object->grant_right(Right => 'CreateSavedSearch');
$user_obj->principal_object->grant_right(Right => 'ModifySelf');

ok $m->login( 'customer' => 'customer' ), "logged in";

$m->get ( $url."Search/Build.html");

#create a saved search
$m->form_name ('BuildQuery');

$m->field ( "ValueOfAttachment" => 'stupid');
$m->field ( "SavedSearchDescription" => 'stupid tickets');
$m->click_button (name => 'SavedSearchSave');

$m->get ( $url.'Prefs/MyRT.html' );
$m->content_like (qr/stupid tickets/, 'saved search listed in rt at a glance items');

ok $m->login, 'we did log in as root';

$m->get ( $url.'Prefs/MyRT.html' );
$m->form_name ('SelectionBox-body');
# can't use submit form for mutli-valued select as it uses set_fields
$m->field ('body-Selected' => ['component-QuickCreate', 'system-Unowned Tickets', 'system-My Tickets']);
$m->click_button (name => 'remove');
$m->form_name ('SelectionBox-body');
#$m->click_button (name => 'body-Save');
$m->get ( $url );
$m->content_lacks ('highest priority tickets', 'remove everything from body pane');

$m->get ( $url.'Prefs/MyRT.html' );
$m->form_name ('SelectionBox-body');
$m->field ('body-Available' => ['component-QuickCreate', 'system-Unowned Tickets', 'system-My Tickets']);
$m->click_button (name => 'add');

$m->form_name ('SelectionBox-body');
$m->field ('body-Selected' => ['component-QuickCreate']);
$m->click_button (name => 'movedown');

$m->form_name ('SelectionBox-body');
$m->click_button (name => 'movedown');

$m->form_name ('SelectionBox-body');
#$m->click_button (name => 'body-Save');
$m->get ( $url );
$m->content_like (qr'highest priority tickets', 'adds them back');

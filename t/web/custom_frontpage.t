#!/usr/bin/perl -w
use strict;

use RT::Test; use Test::More tests => 7;

my ($baseurl, $m) = RT::Test->started_ok;

my $url = $m->rt_base_url;

my $user_object = RT::Model::User->new(current_user => RT->system_user);
my ($ret, $msg) = $user_object->load_or_create_by_email('customer@example.com');
ok($ret, 'ACL test user creation');
$user_object->set_name('customer');
$user_object->set_privileged(1);
($ret, $msg) = $user_object->set_password('customer');
$user_object->principal_object->grant_right(right => 'LoadSavedSearch');
$user_object->principal_object->grant_right(right => 'EditSavedSearch');
$user_object->principal_object->grant_right(right => 'CreateSavedSearch');
$user_object->principal_object->grant_right(right => 'ModifySelf');

ok $m->login( 'customer' => 'customer' ), "logged in";

$m->get ( $url."Search/Build.html");

#create a saved search
$m->form_name('build_query');

$m->field ( "value_of_attachment" => 'stupid');
$m->field ( "saved_search_description" => 'stupid tickets');
$m->click_button (name => 'saved_search_save');

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

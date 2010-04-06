#!/usr/bin/perl -w
use strict;

use RT::Test strict  => 1;
use Test::More tests => 15;

my ( $baseurl, $m ) = RT::Test->started_ok;

my $url = $m->rt_base_url;

my $user_object = RT::Model::User->new( current_user => RT->system_user );
my ( $ret, $msg ) =
  $user_object->load_or_create_by_email('customer@example.com');
ok( $ret, 'ACL test user creation' );
$user_object->set_name('customer');
$user_object->set_privileged(1);
( $ret, $msg ) = $user_object->set_password('customer');
$user_object->principal->grant_right( right => 'LoadSavedSearch' );
$user_object->principal->grant_right( right => 'EditSavedSearches' );
$user_object->principal->grant_right( right => 'CreateSavedSearch' );
$user_object->principal->grant_right( right => 'ModifySelf' );

ok $m->login( 'customer' => 'customer' ), "logged in";

$m->get_ok( $url . "/Search/Build.html" );

#create a saved search
$m->form_name('build_query');

$m->field( "value_of_attachment"      => 'stupid' );
$m->field( "saved_search_description" => 'stupid tickets' );
$m->click_button( name => 'saved_search_save' );

$m->get_ok( $url . '/prefs/my_rt' );
$m->content_like( qr/stupid tickets/,
    'saved search listed in rt at a glance items' );

ok $m->login, 'we did log in as root';

my $moniker = 'prefs_config_my_rt';

$m->get_ok( $url . '/prefs/my_rt' );
# remove system-My Tickets
$m->fill_in_action_ok( $moniker, body => 'system-QuickCreate' );
$m->submit;
$m->get_ok($url);
$m->content_lacks( 'highest priority tickets',
    'remove everything from body pane' );

$m->get_ok( $url . '/prefs/my_rt' );
$m->fill_in_action_ok( $moniker, body => 'system-My Tickets', );
$m->submit;
$m->get_ok($url);
$m->content_like( qr'highest priority tickets', 'adds them back' );


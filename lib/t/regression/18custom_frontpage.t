#!/usr/bin/perl -w
use strict;

use Test::More tests => 7;
BEGIN {
    use RT;
    RT::LoadConfig;
    RT::Init;
}
use Test::WWW::Mechanize;

use constant BaseURL => $RT::WebURL;


my $user_obj = RT::User->new($RT::SystemUser);
my ($ret, $msg) = $user_obj->LoadOrCreateByEmail('customer@example.com');
ok($ret, 'ACL test user creation');
$user_obj->SetName('customer');
$user_obj->SetPrivileged(1);
($ret, $msg) = $user_obj->SetPassword('customer');
$user_obj->PrincipalObj->GrantRight(Right => 'LoadSavedSearch');
$user_obj->PrincipalObj->GrantRight(Right => 'EditSavedSearch');
$user_obj->PrincipalObj->GrantRight(Right => 'CreateSavedSearch');
$user_obj->PrincipalObj->GrantRight(Right => 'ModifySelf');

my $m = Test::WWW::Mechanize->new ( autocheck => 1 );
isa_ok($m, 'Test::WWW::Mechanize');

$m->get( BaseURL."?user=customer;pass=customer" );

$m->content_like(qr/Logout/, 'we did log in');

$m->get ( BaseURL."Search/Build.html");

#create a saved search
$m->form_name ('BuildQuery');

$m->field ( "ValueOfAttachment" => 'stupid');
$m->field ( "Description" => 'stupid tickets');
$m->click_button (name => 'Save');

$m->get ( BaseURL.'Prefs/MyRT.html' );
$m->content_like (qr/stupid tickets/, 'saved search listed in rt at a glance items');

$m->follow_link (text => 'Logout');

$m->get( BaseURL."?user=root;pass=password" );
$m->content_like(qr/Logout/, 'we did log in');

$m->get ( BaseURL.'Prefs/MyRT.html' );
$m->form_name ('SelectionBox-body');
# can't use submit form for mutli-valued select as it uses set_fields
$m->field ('body-Selected' => ['component-QuickCreate', 'system-Unowned Tickets', 'system-My Tickets']);
$m->click_button (name => 'remove');
$m->form_name ('SelectionBox-body');
#$m->click_button (name => 'body-Save');
$m->get ( BaseURL );
$m->content_lacks ('highest priority tickets', 'remove everything from body pane');

$m->get ( BaseURL.'Prefs/MyRT.html' );
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
$m->get ( BaseURL );
$m->content_like (qr'highest priority tickets', 'adds them back');

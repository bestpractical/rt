#!/usr/bin/perl -w
use strict;

use Test::More tests => 4;
BEGIN {
    use RT;
    RT::LoadConfig;
    RT::Init;
}
use Test::WWW::Mechanize;

$RT::WebPath ||= ''; # Shut up a warning
use constant BaseURL => "http://localhost:".$RT::WebPort.$RT::WebPath."/";

# reset preferences for easier test?

my $m = Test::WWW::Mechanize->new ( autocheck => 1 );
isa_ok($m, 'Test::WWW::Mechanize');

$m->get( BaseURL."?user=root;pass=password" );
$m->content_like(qr/Logout/, 'we did log in');

$m->get ( BaseURL.'Prefs/MyRT.html' );
$m->form_name ('SelectionBox-body');
# can't use submit form for mutli-valued select as it uses set_fields
$m->field ('body-Selected' => ['component-QuickCreate', 'system-My Requests', 'system-My Tickets']);
$m->click_button (name => 'remove');
$m->form_name ('SelectionBox-body');
$m->click_button (name => 'body-Save');
$m->get ( BaseURL );
$m->content_lacks ('highest priority tickets', 'remove everything from body pane');

$m->get ( BaseURL.'Prefs/MyRT.html' );
$m->form_name ('SelectionBox-body');
$m->field ('body-Available' => ['component-QuickCreate', 'system-My Requests', 'system-My Tickets']);
$m->click_button (name => 'add');

$m->form_name ('SelectionBox-body');
$m->field ('body-Selected' => ['component-QuickCreate']);
$m->click_button (name => 'movedown');

$m->form_name ('SelectionBox-body');
$m->click_button (name => 'movedown');

$m->form_name ('SelectionBox-body');
$m->click_button (name => 'body-Save');
$m->get ( BaseURL );
$m->content_like (qr'highest priority tickets', 'adds them back');

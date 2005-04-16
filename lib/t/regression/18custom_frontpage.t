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
$m->form_name ('SelectionBox-main');
# can't use submit form for mutli-valued select as it uses set_fields
$m->field ('main-Selected' => ['component-QuickCreate', 'system-My Requests', 'system-My Tickets']);
$m->click_button (name => 'remove');
$m->form_name ('SelectionBox-main');
$m->click_button (name => 'submit');
$m->get ( BaseURL );
$m->content_lacks ('highest priority tickets');

$m->get ( BaseURL.'Prefs/MyRT.html' );
$m->form_name ('SelectionBox-main');
$m->field ('main-Available' => ['component-QuickCreate', 'system-My Requests', 'system-My Tickets']);
$m->click_button (name => 'add');
$m->form_name ('SelectionBox-main');
$m->click_button (name => 'submit');
$m->get ( BaseURL );
$m->content_like (qr'highest priority tickets');

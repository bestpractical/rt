use strict;
use warnings;

use RT::Test tests => undef;
my ($baseurl, $m) = RT::Test->started_ok;

my $system_foo = RT::Dashboard->new($RT::SystemUser);
$system_foo->Save(
    Name    => 'system foo',
    Privacy => 'RT::System-' . $RT::System->id,
);

my $system_bar = RT::Dashboard->new($RT::SystemUser);
$system_bar->Save(
    Name    => 'system bar',
    Privacy => 'RT::System-' . $RT::System->id,
);

ok( $m->login(), "logged in" );

diag "global setting";
# in case "RT at a glance" contains dashboards stuff.
$m->get_ok( $baseurl . "/Search/Simple.html" );
ok( !$m->find_link( text => 'system foo' ), 'no system foo link' );
$m->get_ok( $baseurl."/Admin/Global/DashboardsInMenu.html");

my $form_name = 'SelectionBox-dashboards_in_menu';
$m->form_name($form_name);

$m->field('dashboards_in_menu-Available' => [$system_foo->id],);
$m->click_button(name => 'add');
$m->content_contains('Global dashboards in menu saved.', 'saved');

$m->logout;
ok( $m->login(), "relogged in" );

$m->get_ok( $baseurl . "/Search/Simple.html" );
$m->follow_link_ok( { text => 'system foo' }, 'follow system foo link' );
$m->title_is( 'system foo Dashboard', 'got system foo dashboard page' );

diag "setting in admin users";
my $root = RT::CurrentUser->new( $RT::SystemUser );
ok( $root->Load('root') );
my $self_foo = RT::Dashboard->new($root);
$self_foo->Save( Name => 'self foo', Privacy => 'RT::User-' . $root->id );
my $self_bar = RT::Dashboard->new($root);
$self_bar->Save( Name => 'self bar', Privacy => 'RT::User-' . $root->id );

ok( !$m->find_link( text => 'self foo' ), 'no self foo link' );
$m->get_ok( $baseurl."/Admin/Users/DashboardsInMenu.html?id=" . $root->id);
$m->form_name($form_name);
$m->field('dashboards_in_menu-Available' => [$self_foo->id]);
$m->click_button(name => 'add');
$m->content_contains( 'Preferences saved for dashboards in menu.',
    'prefs saved' );
$m->form_name($form_name);
$m->field('dashboards_in_menu-Selected' => [$system_foo->id]);
$m->content_contains( 'Preferences saved for dashboards in menu.',
    'prefs saved' );
$m->click_button(name => 'remove');

$m->logout;
ok( $m->login(), "relogged in" );
$m->get_ok( $baseurl . "/Search/Simple.html" );
ok( !$m->find_link( text => 'system foo' ), 'no system foo link' );
$m->follow_link_ok( { text => 'self foo' }, 'follow self foo link' );
$m->title_is( 'self foo Dashboard', 'got self foo dashboard page' );

diag "setting in prefs";
$m->get_ok( $baseurl."/Prefs/DashboardsInMenu.html");
$m->form_name($form_name);
$m->field('dashboards_in_menu-Available' => [$self_bar->id]);
$m->click_button(name => 'add');
$m->content_contains( 'Preferences saved for dashboards in menu.',
    'prefs saved' );
$m->follow_link_ok( { text => 'self bar' }, 'follow self bar link' );
$m->title_is( 'self bar Dashboard', 'got self bar dashboard page' );

diag "Test deleting dashboard";
$m->follow_link_ok( { text => 'self foo' }, 'follow self foo link' );
$m->follow_link_ok( { text => 'Basics' }, 'Click dashboard Basics' );
$m->form_name('ModifyDashboard');
$m->click_button(name => 'Delete');

diag "Reset dashboard menu";
$m->get_ok( $baseurl."/Prefs/DashboardsInMenu.html");
$m->form_with_fields('Reset');
$m->click;
$m->content_contains( 'Preferences saved', 'prefs saved' );
ok( $m->find_link( text => 'system foo' ), 'got system foo link' );
ok( !$m->find_link( text => 'self bar' ), 'no self bar link' );

diag "Delete system dashboard";
$m->get_ok( $baseurl . "/Dashboards/index.html" );
$m->follow_link_ok( { text => 'system foo' }, 'follow self foo link' );
$m->follow_link_ok( { text => 'Basics' }, 'Click dashboard Basics' );
$m->form_name('ModifyDashboard');
$m->click_button(name => 'Delete');
$m->get_ok( $baseurl . "/Dashboards/index.html" );
$m->content_lacks('system foo', 'Dashboard is deleted');

done_testing;

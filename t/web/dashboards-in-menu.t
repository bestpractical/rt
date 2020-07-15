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

my $root = RT::CurrentUser->new( $RT::SystemUser );
ok( $root->Load('root') );

diag "global setting";
# in case "RT at a glance" contains dashboards stuff.
$m->get_ok( $baseurl . "/Search/Simple.html" );
ok( !$m->find_link( text => 'system foo' ), 'no system foo link' );
$m->get_ok( $baseurl."/Admin/Global/DashboardsInMenu.html");

my $args = {
    UpdateSearches => "Save",
    dashboard_id   => "DashboardsInMenu",
    dashboard      => ( "dashboard-".$system_foo->Name )
};

my $res = $m->post(
    $baseurl . '/Admin/Global/DashboardsInMenu.html',
    $args,
);

my ($dashboard_attr) = RT->System->Attributes->Named('DashboardsInMenu');
is_deeply( $dashboard_attr->Content, { dashboards => [ $system_foo->Id ] }, "DashboardsInMenu attribute correctly updated" );

is( $res->code, 200, "remove all dashboards from dashboards menu except 'system foo'" );
$m->content_contains( 'Global dashboards in menu saved.' );

$args = {
    UpdateSearches => "Save",
    dashboard_id   => "ReportsInMenu",
    report         => 'report-Created in a date range'
};

$res = $m->post(
    $baseurl . '/Admin/Global/DashboardsInMenu.html',
    $args,
);
my ($report_attr) = RT::System->new( RT->SystemUser )->Attributes->Named('ReportsInMenu');

is_deeply( @{$report_attr->Content}, {
    id     =>  "createdindaterange",
    path   =>  "/Reports/CreatedByDates.html",
    title  =>  "Created in a date range",
    type   => 'report',
    name   => 'Created in a date range',
    label  => 'Created in a date range',
  }, "ReportsInMenu attribute correctly updated"
);

is( $res->code, 200, "remove all reports from reports menu except 'Created in a date range'" );
$m->content_contains( 'Preferences saved for reports in menu.' );

$m->logout;
ok( $m->login(), "relogged in" );

$m->get_ok( $baseurl . "/Search/Simple.html" );
$m->follow_link_ok( { text => 'system foo' }, 'follow system foo link' );
$m->title_is( 'system foo Dashboard', 'got system foo dashboard page' );

diag "setting in admin users";
my $self_foo = RT::Dashboard->new($root);
$self_foo->Save( Name => 'self foo', Privacy => 'RT::User-' . $root->id );
my $self_bar = RT::Dashboard->new($root);
$self_bar->Save( Name => 'self bar', Privacy => 'RT::User-' . $root->id );

ok( !$m->find_link( text => 'self foo' ), 'no self foo link' );
$m->get_ok( $baseurl."/Admin/Users/DashboardsInMenu.html?id=" . $root->id);

$args = {
    UpdateSearches => "Save",
    dashboard_id   => "DashboardsInMenu",
    dashboard      => [ "dashboard-".$self_foo->Name ]
};

$res = $m->post(
    $baseurl . '/Admin/Users/DashboardsInMenu.html?id='.$root->Id,
    $args,
);

my $dashboard_prefs = $root->Preferences('DashboardsInMenu');
is_deeply( $dashboard_prefs, { dashboards => [ $self_foo->Id ] }, "DashboardsInMenu attribute correctly updated for user" );

is( $res->code, 200, "Add dashboard ".$self_foo->Name." to user DashboardsInMenu prefs" );
$m->content_contains( 'Preferences saved for dashboards in menu.' );

diag "setting in prefs";
$m->get_ok( $baseurl."/Prefs/DashboardsInMenu.html");

$args = {
    UpdateSearches => "Save",
    dashboard_id   => "DashboardsInMenu",
    dashboard      => "dashboard-".$self_bar->Name
};

$res = $m->post(
    $baseurl . '/Prefs/DashboardsInMenu.html',
    $args,
);

$root = RT::CurrentUser->new( $RT::SystemUser );
ok( $root->Load('root') );
$dashboard_prefs = $root->Preferences('DashboardsInMenu');
is_deeply( $dashboard_prefs, { dashboards => [ $self_bar->Id ] }, "DashboardsInMenu user pref correctly updated" );

is( $res->code, 200, "Add dashboard ".$self_bar->Name." to user DashboardsInMenu prefs" );
$m->content_contains( 'Preferences saved for dashboards in menu.' );

diag "Reset dashboard menu";
$m->get_ok( $baseurl."/Prefs/DashboardsInMenu.html");
$m->form_with_fields('ResetDashboards');
$m->click;
$m->content_contains( 'Preferences saved', 'prefs saved' );
ok( $m->find_link( text => 'system foo' ), 'got system foo link' );
ok( !$m->find_link( text => 'self bar' ), 'no self bar link' );

foreach my $test_path ( '/Prefs/DashboardsInMenu.html', '/Admin/Global/DashboardsInMenu.html', '/Admin/Users/DashboardsInMenu.html' ) {
    diag "Testing $test_path";
    {
        my @tests = (
          {
              args => {
                UpdateSearches => "Save",
                dashboard_id   => "DashboardsInMenu",
                dashboard      => [  ],
              },
              ret => { dashboards => [  ] }
          },
          {
              args => {
                UpdateSearches => "Save",
                dashboard_id   => "DashboardsInMenu",
                dashboard      => [ "dashboard-".$system_foo->Name ],
              },
              ret => { dashboards => [ $system_foo->Id ] }
          },
          {
              args => {
                UpdateSearches => "Save",
                dashboard_id   => "DashboardsInMenu",
                dashboard      => [ "dashboard-".$system_foo->Name, "dashboard-".$system_bar->Name ],
              },
              ret => { dashboards => [ $system_foo->Id, $system_bar->Id ] }
          }
        );

        foreach my $test ( @tests ) {
            $m->get_ok( $baseurl."$test_path?id=".$root->Id );

            my $res = $m->post(
                $baseurl."$test_path?id=".$root->Id,
                $test->{'args'},
            );

            my $msg;
            if ( $test_path eq '/Admin/Global/DashboardsInMenu.html' ) {
                $msg = 'Global dashboards in menu saved.';
            }
            else {
                $msg = 'Preferences saved for dashboards in menu.';
            }

            is( $res->code, 200, "Update dashboards" );
            $m->content_contains( $msg );

            my $dashboard_attr;
            if ( $test_path eq '/Admin/Global/DashboardsInMenu.html' ) {
                my $sys = RT::System->new( $root );
                ($dashboard_attr) = $sys->Attributes->Named('DashboardsInMenu');
                $dashboard_attr = $dashboard_attr->Content;
            }
            else {
                $root = RT::CurrentUser->new( $RT::SystemUser );
                ok( $root->Load('root') );
                $dashboard_attr = $root->Preferences( 'DashboardsInMenu' );
            }
            is_deeply( $dashboard_attr, $test->{'ret'}, "DashboardsInMenu attribute correctly updated" );
        }

        @tests = (
          {
              args => {
                UpdateSearches => "Save",
                dashboard_id   => "ReportsInMenu",
                report         => [ "report-Created in a date range" ],
              },
              ret => [{
                  id     =>  "createdindaterange",
                  path   =>  "/Reports/CreatedByDates.html",
                  title  =>  "Created in a date range",
                  type   => 'report',
                  name   => 'Created in a date range',
                  label  => 'Created in a date range',
              }]
          },
        );

        foreach my $test ( @tests ) {
            $m->get_ok( $baseurl."$test_path?id=".$root->Id );
            my $res = $m->post(
                $baseurl."$test_path?id=".$root->Id,
                $test->{'args'},
            );

            my $report_attr;
            if ( $test_path eq '/Admin/Global/DashboardsInMenu.html' ) {
                my $sys = RT::System->new( $root );
                ($report_attr) = $sys->Attributes->Named('ReportsInMenu');
                $report_attr = $report_attr->Content;
            }
            else {
                $root = RT::CurrentUser->new( $RT::SystemUser );
                ok( $root->Load('root') );
                $report_attr = $root->Preferences( 'ReportsInMenu' );
            }
            is_deeply( $report_attr, $test->{'ret'} );
        }
    }
}

diag "Delete system dashboard";
$m->get_ok( $baseurl . "/Dashboards/index.html" );
$m->follow_link_ok( { text => 'system foo' }, 'follow self foo link' );
$m->follow_link_ok( { text => 'Basics' }, 'Click dashboard Basics' );
$m->form_name('ModifyDashboard');
$m->click_button(name => 'Delete');
$m->get_ok( $baseurl . "/Dashboards/index.html" );
$m->content_lacks('system foo', 'Dashboard is deleted');

done_testing;

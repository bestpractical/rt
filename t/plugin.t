#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 5;
BEGIN {
    use RT;
    use lib $RT::LocalLibPath; # plugin need this path in @INC
    RT->load_config;
    $RT::LocalPluginPath = $RT::BASE_PATH . "/t/plugins";
    RT->config->set( 'Plugins', 'RT::Extension::Test' );
    ok( RT->plugins->[0]->name, 'RT-Extension-Test' );
}

use RT::Test;
my ($baseurl, $agent) = RT::Test->started_ok;
$agent->get_ok($baseurl);
$agent->get_ok($baseurl . '/NoAuth/test.html');
like( $agent->content, qr/testtest/ );
